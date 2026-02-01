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
        let totalSectors = tracks * sectorsPerTrack * sides
        let totalBytes = totalSectors * sectorSize

        var diskData = Data(count: totalBytes)

        // Initialize catalog on side 0
        initializeCatalog(in: &diskData, volumeName: volumeName, tracks: tracks)

        // If double-sided, initialize catalog on side 1 as well
        if format == .dsd && sides == 2 {
            let side1Offset = tracks * sectorsPerTrack * sectorSize
            initializeCatalogAtOffset(in: &diskData, offset: side1Offset, volumeName: volumeName, tracks: tracks)
        }

        // Write files
        var nextSector = 2  // First data sector (sectors 0-1 are catalog)
        var fileIndex = 0

        for file in files {
            guard let fileData = try? Data(contentsOf: file.url) else {
                print("BBCDiskWriter: Could not read file \(file.name)")
                continue
            }

            if fileIndex >= maxFiles {
                print("BBCDiskWriter: Maximum file count reached")
                break
            }

            // Use provided name
            let (directory, fileName) = splitBBCFileName(file.name)
            let startSector = nextSector
            let sectorCount = (fileData.count + sectorSize - 1) / sectorSize

            // Check if file fits
            if nextSector + sectorCount > totalSectors {
                print("BBCDiskWriter: Disk full")
                break
            }

            // Write file data
            var offset = startSector * sectorSize
            for byte in fileData {
                if offset < totalBytes {
                    diskData[offset] = byte
                    offset += 1
                }
            }

            // Add catalog entry
            addCatalogEntry(
                in: &diskData,
                fileIndex: fileIndex,
                directory: directory,
                fileName: fileName,
                loadAddress: 0xFFFF0E00,  // Default load address for screen data
                execAddress: 0xFFFF0E00,
                length: fileData.count,
                startSector: startSector
            )

            fileIndex += 1
            nextSector += sectorCount
        }

        // Update file count in catalog
        diskData[catalogSector1 * sectorSize + 5] = UInt8(fileIndex * 8)

        // Write to file
        do {
            try diskData.write(to: url)
            print("BBCDiskWriter: Created \(format == .dsd ? "DSD" : "SSD") at \(url.path)")
            return true
        } catch {
            print("BBCDiskWriter: Failed to write disk: \(error)")
            return false
        }
    }

    // MARK: - Catalog Initialization

    private func initializeCatalog(in data: inout Data, volumeName: String, tracks: Int) {
        initializeCatalogAtOffset(in: &data, offset: 0, volumeName: volumeName, tracks: tracks)
    }

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
        data[sector1Offset + 6] = UInt8((tracks * sectorsPerTrack >> 8) & 0x03)

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

        // High bits: exec[17:16], length[17:16], load[17:16], start[9:8]
        let execBits = UInt8((execAddress >> 14) & 0xC0)
        let lengthBits = UInt8((length >> 12) & 0x30)
        let loadBits = UInt8((loadAddress >> 10) & 0x0C)
        let startBits = UInt8((startSector >> 8) & 0x03)
        data[attrOffset + 6] = execBits | lengthBits | loadBits | startBits

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
