import Foundation

// MARK: - TRD Disk Writer
// ZX Spectrum disk image writer supporting TRD format (TR-DOS)

class TRDWriter {
    static let shared = TRDWriter()
    private init() {}

    // MARK: - TR-DOS Format Constants

    private let sectorSize = 256
    private let sectorsPerTrack = 16
    private let tracks = 80
    private let sides = 2

    // TR-DOS disk layout
    private let totalSectors = 2560  // 80 tracks * 2 sides * 16 sectors
    private let directorySector = 0  // Track 0, sector 0
    private let systemSector = 8     // Track 0, sector 8 (disk info)

    private let maxFiles = 128  // Maximum directory entries

    // MARK: - Public Interface

    func createDiskImage(at url: URL, volumeName: String, format: DiskFormat, size: DiskSize, files: [(url: URL, name: String)]) -> Bool {
        // TR-DOS uses 640KB (2560 sectors * 256 bytes)
        var diskData = Data(count: totalSectors * sectorSize)

        // Initialize disk
        initializeDisk(in: &diskData, volumeName: volumeName)

        // Write files
        var nextSector = 16  // First user data sector (after directory)
        var fileIndex = 0

        for file in files {
            guard let fileData = try? Data(contentsOf: file.url) else {
                print("TRDWriter: Could not read file \(file.name)")
                continue
            }

            if fileIndex >= maxFiles {
                print("TRDWriter: Maximum file count reached")
                break
            }

            // Use provided name with extension from URL
            let ext = file.url.pathExtension
            let (fileName, fileExt) = splitTRDFileName("\(file.name).\(ext)")
            let startSector = nextSector
            let sectorCount = (fileData.count + sectorSize - 1) / sectorSize

            // Check if file fits
            if nextSector + sectorCount > totalSectors {
                print("TRDWriter: Disk full")
                break
            }

            // Write file data
            var remaining = fileData
            var currentSector = startSector

            while !remaining.isEmpty {
                let chunk = remaining.prefix(sectorSize)
                remaining = remaining.dropFirst(sectorSize)

                let offset = currentSector * sectorSize
                for (i, byte) in chunk.enumerated() {
                    diskData[offset + i] = byte
                }

                currentSector += 1
            }

            // Add directory entry
            addDirectoryEntry(
                in: &diskData,
                fileIndex: fileIndex,
                fileName: fileName,
                fileExt: fileExt,
                startSector: startSector,
                sectorCount: sectorCount,
                fileLength: fileData.count
            )

            fileIndex += 1
            nextSector = currentSector
        }

        // Update disk info
        updateDiskInfo(in: &diskData, fileCount: fileIndex, freeSectors: totalSectors - nextSector,
                       firstFreeSector: nextSector)

        // Write to file
        do {
            try diskData.write(to: url)
            print("TRDWriter: Created TRD at \(url.path)")
            return true
        } catch {
            print("TRDWriter: Failed to write TRD: \(error)")
            return false
        }
    }

    // MARK: - Disk Initialization

    private func initializeDisk(in data: inout Data, volumeName: String) {
        // Fill disk with zeros
        for i in 0..<data.count {
            data[i] = 0x00
        }

        // Initialize system sector (track 0, sector 8)
        let sysOffset = systemSector * sectorSize

        // End of directory marker
        data[sysOffset + 0xE1] = 0x00

        // Disk label (8 bytes at offset 0xF5)
        let label = volumeName.uppercased().prefix(8).padding(toLength: 8, withPad: " ", startingAt: 0)
        for (i, char) in label.enumerated() {
            data[sysOffset + 0xF5 + i] = char.asciiValue ?? 0x20
        }

        // Free sector count (little-endian at offset 0xE5)
        let freeSectors = totalSectors - 16  // Minus directory/system sectors
        data[sysOffset + 0xE5] = UInt8(freeSectors & 0xFF)
        data[sysOffset + 0xE6] = UInt8((freeSectors >> 8) & 0xFF)

        // First free sector (track and sector at offset 0xE1)
        data[sysOffset + 0xE1] = 16  // First free sector
        data[sysOffset + 0xE2] = 0   // First free track

        // Disk type (0x16 = 80 tracks, double-sided)
        data[sysOffset + 0xE3] = 0x16

        // File count
        data[sysOffset + 0xE4] = 0

        // TR-DOS signature
        data[sysOffset + 0xE7] = 0x10  // TR-DOS 5.03
    }

    // MARK: - Directory Entry

    private func addDirectoryEntry(in data: inout Data, fileIndex: Int, fileName: String,
                                   fileExt: String, startSector: Int, sectorCount: Int, fileLength: Int) {
        // Directory entries are 16 bytes each, starting at sector 0
        let entryOffset = fileIndex * 16

        // Filename (8 bytes)
        let paddedName = fileName.uppercased().padding(toLength: 8, withPad: " ", startingAt: 0)
        for (i, char) in paddedName.prefix(8).enumerated() {
            data[entryOffset + i] = char.asciiValue ?? 0x20
        }

        // Extension/type (1 byte)
        let fileType = trdosFileType(for: fileExt)
        data[entryOffset + 8] = fileType

        // Start address (for BASIC programs, use 0)
        data[entryOffset + 9] = 0x00
        data[entryOffset + 10] = 0x00

        // Length in bytes (little-endian)
        data[entryOffset + 11] = UInt8(fileLength & 0xFF)
        data[entryOffset + 12] = UInt8((fileLength >> 8) & 0xFF)

        // Sector count
        data[entryOffset + 13] = UInt8(sectorCount)

        // Start sector and track
        let startTrack = startSector / (sectorsPerTrack * sides)
        let startSectorInTrack = startSector % (sectorsPerTrack * sides)
        data[entryOffset + 14] = UInt8(startSectorInTrack)
        data[entryOffset + 15] = UInt8(startTrack)
    }

    // MARK: - Disk Info Update

    private func updateDiskInfo(in data: inout Data, fileCount: Int, freeSectors: Int, firstFreeSector: Int) {
        let sysOffset = systemSector * sectorSize

        // File count
        data[sysOffset + 0xE4] = UInt8(fileCount)

        // Free sector count
        data[sysOffset + 0xE5] = UInt8(freeSectors & 0xFF)
        data[sysOffset + 0xE6] = UInt8((freeSectors >> 8) & 0xFF)

        // First free sector
        let freeTrack = firstFreeSector / (sectorsPerTrack * sides)
        let freeSectorInTrack = firstFreeSector % (sectorsPerTrack * sides)
        data[sysOffset + 0xE1] = UInt8(freeSectorInTrack)
        data[sysOffset + 0xE2] = UInt8(freeTrack)
    }

    // MARK: - Helpers

    private func trdosFileType(for ext: String) -> UInt8 {
        // TR-DOS file types
        switch ext.uppercased() {
        case "B", "BAS": return 0x42  // 'B' - BASIC
        case "C", "COD": return 0x43  // 'C' - Code
        case "D", "DAT": return 0x44  // 'D' - Data
        case "#", "SCR": return 0x23  // '#' - Screen
        default: return 0x43          // Default to Code
        }
    }

    private func splitTRDFileName(_ name: String) -> (String, String) {
        var baseName = name.uppercased()
        var ext = ""

        if let dotIndex = baseName.lastIndex(of: ".") {
            ext = String(baseName[baseName.index(after: dotIndex)...])
            baseName = String(baseName[..<dotIndex])
        }

        // TR-DOS: A-Z, 0-9 only
        baseName = baseName.filter { char in
            let ascii = char.asciiValue ?? 0
            return (ascii >= 0x41 && ascii <= 0x5A) || (ascii >= 0x30 && ascii <= 0x39)
        }

        return (String(baseName.prefix(8)), String(ext.prefix(1)))
    }
}
