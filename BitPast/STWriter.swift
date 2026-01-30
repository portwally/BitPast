import Foundation

// MARK: - ST Disk Writer
// Atari ST disk image writer supporting ST format (FAT12)

class STWriter {
    static let shared = STWriter()
    private init() {}

    // MARK: - ST Format Constants

    private let sectorSize = 512
    private let sectorsPerCluster = 2
    private let reservedSectors = 1
    private let numberOfFATs = 2
    private let rootDirEntries = 112  // For 360KB/720KB

    // MARK: - Public Interface

    func createDiskImage(at url: URL, volumeName: String, size: DiskSize, files: [URL]) -> Bool {
        let (totalSectors, sectorsPerTrack, heads, rootEntries) = diskGeometry(for: size)
        let bytesPerCluster = sectorSize * sectorsPerCluster

        // FAT size calculation
        let fatSectors = (totalSectors / sectorsPerCluster * 3 / 2 + sectorSize - 1) / sectorSize
        let rootDirSectors = (rootEntries * 32 + sectorSize - 1) / sectorSize
        let dataStartSector = reservedSectors + numberOfFATs * fatSectors + rootDirSectors

        var diskData = Data(count: totalSectors * sectorSize)

        // Boot sector
        initializeBootSector(in: &diskData, volumeName: volumeName, totalSectors: totalSectors,
                             sectorsPerTrack: sectorsPerTrack, heads: heads, fatSectors: fatSectors,
                             rootEntries: rootEntries)

        // Initialize FATs
        let fat1Offset = reservedSectors * sectorSize
        let fat2Offset = fat1Offset + fatSectors * sectorSize

        // Media descriptor in FAT
        diskData[fat1Offset] = 0xF9  // 3.5" double-sided
        diskData[fat1Offset + 1] = 0xFF
        diskData[fat1Offset + 2] = 0xFF

        // Copy to second FAT
        for i in 0..<(fatSectors * sectorSize) {
            diskData[fat2Offset + i] = diskData[fat1Offset + i]
        }

        // Root directory offset
        let rootDirOffset = (reservedSectors + numberOfFATs * fatSectors) * sectorSize

        // Write files
        var nextCluster = 2  // First data cluster
        var dirEntryIndex = 0

        for fileUrl in files {
            guard let fileData = try? Data(contentsOf: fileUrl) else {
                print("STWriter: Could not read file \(fileUrl.lastPathComponent)")
                continue
            }

            let (fileName, fileExt) = splitFileName(fileUrl.lastPathComponent)
            let startCluster = nextCluster

            // Write file data
            var remaining = fileData
            var currentCluster = startCluster
            var clusterList: [Int] = []

            while !remaining.isEmpty {
                let chunk = remaining.prefix(bytesPerCluster)
                remaining = remaining.dropFirst(bytesPerCluster)

                // Write cluster data
                let clusterOffset = dataStartSector * sectorSize + (currentCluster - 2) * bytesPerCluster
                for (i, byte) in chunk.enumerated() {
                    if clusterOffset + i < diskData.count {
                        diskData[clusterOffset + i] = byte
                    }
                }

                clusterList.append(currentCluster)
                currentCluster += 1
            }

            // Update FAT chain
            for (i, cluster) in clusterList.enumerated() {
                let nextC = (i < clusterList.count - 1) ? clusterList[i + 1] : 0xFFF
                writeFAT12Entry(in: &diskData, fatOffset: fat1Offset, cluster: cluster, value: nextC)
                writeFAT12Entry(in: &diskData, fatOffset: fat2Offset, cluster: cluster, value: nextC)
            }

            // Add directory entry
            addDirectoryEntry(
                in: &diskData,
                dirOffset: rootDirOffset,
                entryIndex: dirEntryIndex,
                fileName: fileName,
                fileExt: fileExt,
                startCluster: startCluster,
                fileSize: fileData.count
            )

            dirEntryIndex += 1
            nextCluster = currentCluster
        }

        // Write to file
        do {
            try diskData.write(to: url)
            print("STWriter: Created ST at \(url.path)")
            return true
        } catch {
            print("STWriter: Failed to write ST: \(error)")
            return false
        }
    }

    // MARK: - Boot Sector

    private func initializeBootSector(in data: inout Data, volumeName: String, totalSectors: Int,
                                      sectorsPerTrack: Int, heads: Int, fatSectors: Int, rootEntries: Int) {
        // Jump instruction
        data[0] = 0xEB
        data[1] = 0x3C
        data[2] = 0x90

        // OEM name
        let oem = "BITPAST "
        for (i, char) in oem.prefix(8).enumerated() {
            data[3 + i] = char.asciiValue ?? 0x20
        }

        // Bytes per sector
        data[11] = UInt8(sectorSize & 0xFF)
        data[12] = UInt8((sectorSize >> 8) & 0xFF)

        // Sectors per cluster
        data[13] = UInt8(sectorsPerCluster)

        // Reserved sectors
        data[14] = UInt8(reservedSectors)
        data[15] = 0

        // Number of FATs
        data[16] = UInt8(numberOfFATs)

        // Root directory entries
        data[17] = UInt8(rootEntries & 0xFF)
        data[18] = UInt8((rootEntries >> 8) & 0xFF)

        // Total sectors
        data[19] = UInt8(totalSectors & 0xFF)
        data[20] = UInt8((totalSectors >> 8) & 0xFF)

        // Media descriptor
        data[21] = 0xF9  // 3.5" double-sided

        // Sectors per FAT
        data[22] = UInt8(fatSectors & 0xFF)
        data[23] = UInt8((fatSectors >> 8) & 0xFF)

        // Sectors per track
        data[24] = UInt8(sectorsPerTrack)
        data[25] = 0

        // Number of heads
        data[26] = UInt8(heads)
        data[27] = 0

        // Hidden sectors
        data[28] = 0
        data[29] = 0
        data[30] = 0
        data[31] = 0

        // Volume label (at offset 43 for FAT12)
        let label = volumeName.uppercased().padding(toLength: 11, withPad: " ", startingAt: 0)
        for (i, char) in label.prefix(11).enumerated() {
            data[43 + i] = char.asciiValue ?? 0x20
        }

        // Boot signature
        data[510] = 0x55
        data[511] = 0xAA
    }

    // MARK: - FAT12 Operations

    private func writeFAT12Entry(in data: inout Data, fatOffset: Int, cluster: Int, value: Int) {
        let offset = fatOffset + (cluster * 3) / 2

        if cluster % 2 == 0 {
            // Even cluster: low 8 bits in byte N, high 4 bits in low nibble of byte N+1
            data[offset] = UInt8(value & 0xFF)
            data[offset + 1] = (data[offset + 1] & 0xF0) | UInt8((value >> 8) & 0x0F)
        } else {
            // Odd cluster: low 4 bits in high nibble of byte N, high 8 bits in byte N+1
            data[offset] = (data[offset] & 0x0F) | UInt8((value & 0x0F) << 4)
            data[offset + 1] = UInt8((value >> 4) & 0xFF)
        }
    }

    // MARK: - Directory Entry

    private func addDirectoryEntry(in data: inout Data, dirOffset: Int, entryIndex: Int,
                                   fileName: String, fileExt: String, startCluster: Int, fileSize: Int) {
        let entryOffset = dirOffset + entryIndex * 32

        // Filename (8 chars, space padded)
        let paddedName = fileName.uppercased().padding(toLength: 8, withPad: " ", startingAt: 0)
        for (i, char) in paddedName.prefix(8).enumerated() {
            data[entryOffset + i] = char.asciiValue ?? 0x20
        }

        // Extension (3 chars, space padded)
        let paddedExt = fileExt.uppercased().padding(toLength: 3, withPad: " ", startingAt: 0)
        for (i, char) in paddedExt.prefix(3).enumerated() {
            data[entryOffset + 8 + i] = char.asciiValue ?? 0x20
        }

        // Attributes (archive)
        data[entryOffset + 11] = 0x20

        // Reserved
        for i in 12..<22 {
            data[entryOffset + i] = 0
        }

        // Time and date (use fixed values)
        data[entryOffset + 22] = 0x00
        data[entryOffset + 23] = 0x00
        data[entryOffset + 24] = 0x21  // Jan 1, 1980
        data[entryOffset + 25] = 0x00

        // Start cluster
        data[entryOffset + 26] = UInt8(startCluster & 0xFF)
        data[entryOffset + 27] = UInt8((startCluster >> 8) & 0xFF)

        // File size
        data[entryOffset + 28] = UInt8(fileSize & 0xFF)
        data[entryOffset + 29] = UInt8((fileSize >> 8) & 0xFF)
        data[entryOffset + 30] = UInt8((fileSize >> 16) & 0xFF)
        data[entryOffset + 31] = UInt8((fileSize >> 24) & 0xFF)
    }

    // MARK: - Helpers

    private func diskGeometry(for size: DiskSize) -> (totalSectors: Int, sectorsPerTrack: Int, heads: Int, rootEntries: Int) {
        switch size {
        case .kb360: return (720, 9, 2, 112)
        case .kb720: return (1440, 9, 2, 112)
        case .mb1_44: return (2880, 18, 2, 224)
        default: return (1440, 9, 2, 112)
        }
    }

    private func splitFileName(_ name: String) -> (String, String) {
        var baseName = name.uppercased()
        var ext = ""

        if let dotIndex = baseName.lastIndex(of: ".") {
            ext = String(baseName[baseName.index(after: dotIndex)...])
            baseName = String(baseName[..<dotIndex])
        }

        // Clean to valid FAT characters
        baseName = baseName.filter { char in
            let ascii = char.asciiValue ?? 0
            return (ascii >= 0x41 && ascii <= 0x5A) ||
                   (ascii >= 0x30 && ascii <= 0x39) ||
                   char == "_" || char == "-"
        }

        ext = ext.filter { char in
            let ascii = char.asciiValue ?? 0
            return (ascii >= 0x41 && ascii <= 0x5A) ||
                   (ascii >= 0x30 && ascii <= 0x39)
        }

        return (String(baseName.prefix(8)), String(ext.prefix(3)))
    }
}
