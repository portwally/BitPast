import Foundation

// MARK: - BBC Micro Disk Writer
// BBC Micro disk image writer supporting SSD and DSD formats (Acorn DFS)

class BBCDiskWriter {
    static let shared = BBCDiskWriter()
    private init() {}

    // MARK: - DFS Format Constants

    private let sectorSize = 256
    private let sectorsPerTrack = 10
    private let catalogSector0 = 0  // First catalog sector
    private let catalogSector1 = 1  // Second catalog sector
    private let maxFiles = 31       // Maximum files in DFS catalog

    // MARK: - Public Interface

    func createDiskImage(at url: URL, volumeName: String, format: DiskFormat, size: DiskSize, files: [(url: URL, name: String)]) -> Bool {
        let (tracks, sides) = diskGeometry(for: size, format: format)
        let sectorsPerSide = tracks * sectorsPerTrack
        let totalBytes = sectorsPerSide * sides * sectorSize

        var diskData = Data(count: totalBytes)

        // Catalogue for side 0, and for side 1 on a double-sided disk
        initializeCatalogAtOffset(in: &diskData, offset: imageOffset(sector: 0, side: 0, sides: sides),
                                  volumeName: volumeName, tracks: tracks)
        if sides == 2 {
            initializeCatalogAtOffset(in: &diskData, offset: imageOffset(sector: 0, side: 1, sides: sides),
                                      volumeName: volumeName, tracks: tracks)
        }

        // Write files to side 0
        var nextSector = 2  // First data sector (sectors 0-1 are catalog)
        var entries: [(directory: Character, name: String, length: Int, startSector: Int)] = []

        for file in files {
            guard let fileData = try? Data(contentsOf: file.url) else {
                Log.error("BBCDiskWriter: Could not read file \(file.name)")
                continue
            }

            if entries.count >= maxFiles {
                Log.error("BBCDiskWriter: Maximum file count reached")
                break
            }

            let (directory, fileName) = splitBBCFileName(file.name)
            let startSector = nextSector
            let sectorCount = (fileData.count + sectorSize - 1) / sectorSize

            if nextSector + sectorCount > sectorsPerSide {
                Log.error("BBCDiskWriter: Disk full")
                break
            }

            // Write sector by sector, so double-sided images get the interleaved layout
            for s in 0..<sectorCount {
                let chunk = fileData.dropFirst(s * sectorSize).prefix(sectorSize)
                let offset = imageOffset(sector: startSector + s, side: 0, sides: sides)
                diskData.replaceSubrange(offset..<(offset + chunk.count), with: chunk)
            }

            entries.append((directory, fileName, fileData.count, startSector))
            nextSector += sectorCount
        }

        // DFS keeps the catalogue sorted by start sector, highest first
        for (index, entry) in entries.reversed().enumerated() {
            addCatalogEntry(
                in: &diskData,
                fileIndex: index,
                directory: entry.directory,
                fileName: entry.name,
                loadAddress: 0xFFFF0E00,  // Default load address for screen data
                execAddress: 0xFFFF0E00,
                length: entry.length,
                startSector: entry.startSector
            )
        }

        // Update file count in catalog
        diskData[catalogSector1 * sectorSize + 5] = UInt8(entries.count * 8)

        // Write to file
        do {
            try diskData.write(to: url)
            Log.debug("BBCDiskWriter: Created \(format == .dsd ? "DSD" : "SSD") at \(url.path)")
            return true
        } catch {
            Log.error("BBCDiskWriter: Failed to write disk: \(error)")
            return false
        }
    }

    /// Byte offset of a logical sector on one side. DSD images interleave the
    /// sides track by track: side 0 track 0, side 1 track 0, side 0 track 1, ...
    private func imageOffset(sector: Int, side: Int, sides: Int) -> Int {
        let track = sector / sectorsPerTrack
        let physicalTrack = track * sides + side
        return (physicalTrack * sectorsPerTrack + sector % sectorsPerTrack) * sectorSize
    }

    // MARK: - Catalog Initialization

    private func initializeCatalogAtOffset(in data: inout Data, offset: Int, volumeName: String, tracks: Int) {
        // Sector 0: File names (8 bytes each, up to 31 files)
        // First 8 bytes: volume title (part 1)
        let title = volumeName.prefix(8).padding(toLength: 8, withPad: " ", startingAt: 0)
        for (i, char) in title.enumerated() {
            data[offset + i] = char.asciiValue ?? 0x20
        }

        // Sector 1: File attributes
        let sector1Offset = offset + sectorSize

        // Volume title continuation (4 bytes)
        let title2 = volumeName.dropFirst(8).prefix(4).padding(toLength: 4, withPad: " ", startingAt: 0)
        for (i, char) in title2.enumerated() {
            data[sector1Offset + i] = char.asciiValue ?? 0x20
        }

        // Cycle number (BCD)
        data[sector1Offset + 4] = 0x00

        // Number of files * 8
        data[sector1Offset + 5] = 0x00

        // Boot option and sector count high bits
        data[sector1Offset + 6] = UInt8(((tracks * sectorsPerTrack) >> 8) & 0x03)

        // Sector count low byte
        data[sector1Offset + 7] = UInt8((tracks * sectorsPerTrack) & 0xFF)
    }

    // MARK: - Catalog Entry

    private func addCatalogEntry(in data: inout Data, fileIndex: Int, directory: Character,
                                 fileName: String, loadAddress: UInt32, execAddress: UInt32,
                                 length: Int, startSector: Int) {
        // Sector 0: filename entry (8 bytes per file)
        let nameOffset = (fileIndex + 1) * 8  // First 8 bytes are volume title

        // Directory character + filename (7 chars)
        let paddedName = fileName.prefix(7).padding(toLength: 7, withPad: " ", startingAt: 0)
        data[nameOffset] = paddedName.first?.asciiValue ?? 0x20
        for (i, char) in paddedName.dropFirst().prefix(6).enumerated() {
            data[nameOffset + 1 + i] = char.asciiValue ?? 0x20
        }

        // Directory character in high bit + last char of filename
        let dirChar = directory.asciiValue ?? 0x24  // Default '$'
        data[nameOffset + 7] = dirChar

        // Sector 1: attribute entry (8 bytes per file)
        let attrOffset = sectorSize + (fileIndex + 1) * 8

        // Load address (low 16 bits)
        data[attrOffset + 0] = UInt8(loadAddress & 0xFF)
        data[attrOffset + 1] = UInt8((loadAddress >> 8) & 0xFF)

        // Exec address (low 16 bits)
        data[attrOffset + 2] = UInt8(execAddress & 0xFF)
        data[attrOffset + 3] = UInt8((execAddress >> 8) & 0xFF)

        // Length (low 16 bits)
        data[attrOffset + 4] = UInt8(length & 0xFF)
        data[attrOffset + 5] = UInt8((length >> 8) & 0xFF)

        // High bits byte format (Acorn DFS):
        // Bits 0-1: Start sector bits 8-9
        // Bits 2-3: Load address bits 16-17
        // Bits 4-5: Length bits 16-17
        // Bits 6-7: Exec address bits 16-17
        let startBits = UInt8((startSector >> 8) & 0x03)             // bits 0-1
        let loadBits = UInt8(((loadAddress >> 16) & 0x03) << 2)      // bits 2-3
        let lengthBits = UInt8(((length >> 16) & 0x03) << 4)         // bits 4-5
        let execBits = UInt8(((execAddress >> 16) & 0x03) << 6)      // bits 6-7
        data[attrOffset + 6] = startBits | loadBits | lengthBits | execBits

        // Start sector (low 8 bits)
        data[attrOffset + 7] = UInt8(startSector & 0xFF)
    }

    // MARK: - Helpers

    private func diskGeometry(for size: DiskSize, format: DiskFormat) -> (tracks: Int, sides: Int) {
        switch (format, size) {
        case (.ssd, .kb100): return (40, 1)
        case (.ssd, .kb200): return (80, 1)
        case (.dsd, .kb200): return (40, 2)
        case (.dsd, .kb400): return (80, 2)
        default: return (40, 1)
        }
    }

    private func splitBBCFileName(_ name: String) -> (Character, String) {
        var clean = name.uppercased()

        // Remove extension
        if let dotIndex = clean.lastIndex(of: ".") {
            clean = String(clean[..<dotIndex])
        }

        // Check for directory prefix (e.g., "$.FILENAME" or "A.FILENAME")
        var directory: Character = "$"  // Default directory
        if clean.count > 2 && clean[clean.index(clean.startIndex, offsetBy: 1)] == "." {
            directory = clean.first ?? "$"
            clean = String(clean.dropFirst(2))
        }

        // Clean filename (A-Z, 0-9 only)
        clean = clean.filter { char in
            let ascii = char.asciiValue ?? 0
            return (ascii >= 0x41 && ascii <= 0x5A) || (ascii >= 0x30 && ascii <= 0x39)
        }

        return (directory, String(clean.prefix(7)))
    }
}
