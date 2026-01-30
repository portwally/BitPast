import Foundation

// MARK: - IMG Disk Writer
// PC DOS/Windows disk image writer supporting IMG format (FAT12/FAT16)

class IMGWriter {
    static let shared = IMGWriter()
    private init() {}

    // MARK: - IMG Format Constants

    private let sectorSize = 512

    // MARK: - Public Interface

    func createDiskImage(at url: URL, volumeName: String, size: DiskSize, files: [URL]) -> Bool {
        let geometry = diskGeometry(for: size)
        let totalSectors = geometry.totalSectors
        let sectorsPerCluster = geometry.sectorsPerCluster
        let bytesPerCluster = sectorSize * sectorsPerCluster

        // Calculate FAT size
        let fatType = geometry.fatType
        let reservedSectors = 1
        let numberOfFATs = 2
        let rootDirEntries = geometry.rootEntries
        let rootDirSectors = (rootDirEntries * 32 + sectorSize - 1) / sectorSize

        let fatSectors: Int
        if fatType == 12 {
            fatSectors = ((totalSectors / sectorsPerCluster) * 3 / 2 + sectorSize - 1) / sectorSize
        } else {
            fatSectors = ((totalSectors / sectorsPerCluster) * 2 + sectorSize - 1) / sectorSize
        }

        let dataStartSector = reservedSectors + numberOfFATs * fatSectors + rootDirSectors

        var diskData = Data(count: totalSectors * sectorSize)

        // Boot sector
        initializeBootSector(
            in: &diskData,
            volumeName: volumeName,
            geometry: geometry,
            fatSectors: fatSectors
        )

        // Initialize FATs
        let fat1Offset = reservedSectors * sectorSize
        let fat2Offset = fat1Offset + fatSectors * sectorSize

        // Media descriptor in FAT
        diskData[fat1Offset] = geometry.mediaDescriptor
        diskData[fat1Offset + 1] = 0xFF
        if fatType == 12 {
            diskData[fat1Offset + 2] = 0xFF
        } else {
            diskData[fat1Offset + 2] = 0xFF
            diskData[fat1Offset + 3] = 0xFF
        }

        // Copy to second FAT
        for i in 0..<(fatSectors * sectorSize) {
            diskData[fat2Offset + i] = diskData[fat1Offset + i]
        }

        // Root directory
        let rootDirOffset = (reservedSectors + numberOfFATs * fatSectors) * sectorSize

        // Add volume label as first directory entry
        addVolumeLabelEntry(in: &diskData, dirOffset: rootDirOffset, volumeName: volumeName)

        // Write files
        var nextCluster = 2
        var dirEntryIndex = 1  // Start after volume label

        for fileUrl in files {
            guard let fileData = try? Data(contentsOf: fileUrl) else {
                print("IMGWriter: Could not read file \(fileUrl.lastPathComponent)")
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
            let endMarker = fatType == 12 ? 0xFFF : 0xFFFF
            for (i, cluster) in clusterList.enumerated() {
                let nextC = (i < clusterList.count - 1) ? clusterList[i + 1] : endMarker
                if fatType == 12 {
                    writeFAT12Entry(in: &diskData, fatOffset: fat1Offset, cluster: cluster, value: nextC)
                    writeFAT12Entry(in: &diskData, fatOffset: fat2Offset, cluster: cluster, value: nextC)
                } else {
                    writeFAT16Entry(in: &diskData, fatOffset: fat1Offset, cluster: cluster, value: nextC)
                    writeFAT16Entry(in: &diskData, fatOffset: fat2Offset, cluster: cluster, value: nextC)
                }
            }

            // Add directory entry
            addFileEntry(
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
            print("IMGWriter: Created IMG at \(url.path)")
            return true
        } catch {
            print("IMGWriter: Failed to write IMG: \(error)")
            return false
        }
    }

    // MARK: - Boot Sector

    private func initializeBootSector(in data: inout Data, volumeName: String,
                                      geometry: DiskGeometry, fatSectors: Int) {
        // Jump instruction
        data[0] = 0xEB
        data[1] = 0x3C
        data[2] = 0x90

        // OEM name
        let oem = "MSDOS5.0"
        for (i, char) in oem.prefix(8).enumerated() {
            data[3 + i] = char.asciiValue ?? 0x20
        }

        // BPB (BIOS Parameter Block)
        // Bytes per sector
        data[11] = UInt8(sectorSize & 0xFF)
        data[12] = UInt8((sectorSize >> 8) & 0xFF)

        // Sectors per cluster
        data[13] = UInt8(geometry.sectorsPerCluster)

        // Reserved sectors
        data[14] = 1
        data[15] = 0

        // Number of FATs
        data[16] = 2

        // Root directory entries
        data[17] = UInt8(geometry.rootEntries & 0xFF)
        data[18] = UInt8((geometry.rootEntries >> 8) & 0xFF)

        // Total sectors (16-bit)
        if geometry.totalSectors < 65536 {
            data[19] = UInt8(geometry.totalSectors & 0xFF)
            data[20] = UInt8((geometry.totalSectors >> 8) & 0xFF)
        } else {
            data[19] = 0
            data[20] = 0
        }

        // Media descriptor
        data[21] = geometry.mediaDescriptor

        // Sectors per FAT
        data[22] = UInt8(fatSectors & 0xFF)
        data[23] = UInt8((fatSectors >> 8) & 0xFF)

        // Sectors per track
        data[24] = UInt8(geometry.sectorsPerTrack)
        data[25] = 0

        // Number of heads
        data[26] = UInt8(geometry.heads)
        data[27] = 0

        // Hidden sectors
        data[28] = 0
        data[29] = 0
        data[30] = 0
        data[31] = 0

        // Total sectors (32-bit) for large disks
        if geometry.totalSectors >= 65536 {
            data[32] = UInt8(geometry.totalSectors & 0xFF)
            data[33] = UInt8((geometry.totalSectors >> 8) & 0xFF)
            data[34] = UInt8((geometry.totalSectors >> 16) & 0xFF)
            data[35] = UInt8((geometry.totalSectors >> 24) & 0xFF)
        }

        // Extended boot record
        data[36] = 0x00  // Drive number
        data[37] = 0x00  // Reserved
        data[38] = 0x29  // Extended boot signature

        // Volume serial number
        let serial = UInt32.random(in: 0...UInt32.max)
        data[39] = UInt8(serial & 0xFF)
        data[40] = UInt8((serial >> 8) & 0xFF)
        data[41] = UInt8((serial >> 16) & 0xFF)
        data[42] = UInt8((serial >> 24) & 0xFF)

        // Volume label
        let label = volumeName.uppercased().padding(toLength: 11, withPad: " ", startingAt: 0)
        for (i, char) in label.prefix(11).enumerated() {
            data[43 + i] = char.asciiValue ?? 0x20
        }

        // File system type
        let fsType = geometry.fatType == 12 ? "FAT12   " : "FAT16   "
        for (i, char) in fsType.prefix(8).enumerated() {
            data[54 + i] = char.asciiValue ?? 0x20
        }

        // Boot signature
        data[510] = 0x55
        data[511] = 0xAA
    }

    // MARK: - FAT Operations

    private func writeFAT12Entry(in data: inout Data, fatOffset: Int, cluster: Int, value: Int) {
        let offset = fatOffset + (cluster * 3) / 2

        if cluster % 2 == 0 {
            data[offset] = UInt8(value & 0xFF)
            data[offset + 1] = (data[offset + 1] & 0xF0) | UInt8((value >> 8) & 0x0F)
        } else {
            data[offset] = (data[offset] & 0x0F) | UInt8((value & 0x0F) << 4)
            data[offset + 1] = UInt8((value >> 4) & 0xFF)
        }
    }

    private func writeFAT16Entry(in data: inout Data, fatOffset: Int, cluster: Int, value: Int) {
        let offset = fatOffset + cluster * 2
        data[offset] = UInt8(value & 0xFF)
        data[offset + 1] = UInt8((value >> 8) & 0xFF)
    }

    // MARK: - Directory Entries

    private func addVolumeLabelEntry(in data: inout Data, dirOffset: Int, volumeName: String) {
        let label = volumeName.uppercased().padding(toLength: 11, withPad: " ", startingAt: 0)
        for (i, char) in label.prefix(11).enumerated() {
            data[dirOffset + i] = char.asciiValue ?? 0x20
        }
        data[dirOffset + 11] = 0x08  // Volume label attribute
    }

    private func addFileEntry(in data: inout Data, dirOffset: Int, entryIndex: Int,
                              fileName: String, fileExt: String, startCluster: Int, fileSize: Int) {
        let entryOffset = dirOffset + entryIndex * 32

        // Filename
        let paddedName = fileName.uppercased().padding(toLength: 8, withPad: " ", startingAt: 0)
        for (i, char) in paddedName.prefix(8).enumerated() {
            data[entryOffset + i] = char.asciiValue ?? 0x20
        }

        // Extension
        let paddedExt = fileExt.uppercased().padding(toLength: 3, withPad: " ", startingAt: 0)
        for (i, char) in paddedExt.prefix(3).enumerated() {
            data[entryOffset + 8 + i] = char.asciiValue ?? 0x20
        }

        // Attributes (archive)
        data[entryOffset + 11] = 0x20

        // Reserved / NT flags
        data[entryOffset + 12] = 0

        // Creation time (tenths)
        data[entryOffset + 13] = 0

        // Creation time
        data[entryOffset + 14] = 0
        data[entryOffset + 15] = 0

        // Creation date
        data[entryOffset + 16] = 0x21
        data[entryOffset + 17] = 0x00

        // Last access date
        data[entryOffset + 18] = 0x21
        data[entryOffset + 19] = 0x00

        // High word of cluster (FAT32 only)
        data[entryOffset + 20] = 0
        data[entryOffset + 21] = 0

        // Last write time
        data[entryOffset + 22] = 0
        data[entryOffset + 23] = 0

        // Last write date
        data[entryOffset + 24] = 0x21
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

    private struct DiskGeometry {
        let totalSectors: Int
        let sectorsPerTrack: Int
        let heads: Int
        let sectorsPerCluster: Int
        let rootEntries: Int
        let mediaDescriptor: UInt8
        let fatType: Int  // 12 or 16
    }

    private func diskGeometry(for size: DiskSize) -> DiskGeometry {
        switch size {
        case .kb360:
            return DiskGeometry(totalSectors: 720, sectorsPerTrack: 9, heads: 2,
                                sectorsPerCluster: 2, rootEntries: 112, mediaDescriptor: 0xFD, fatType: 12)
        case .kb720:
            return DiskGeometry(totalSectors: 1440, sectorsPerTrack: 9, heads: 2,
                                sectorsPerCluster: 2, rootEntries: 112, mediaDescriptor: 0xF9, fatType: 12)
        case .mb1_2:
            return DiskGeometry(totalSectors: 2400, sectorsPerTrack: 15, heads: 2,
                                sectorsPerCluster: 1, rootEntries: 224, mediaDescriptor: 0xF9, fatType: 12)
        case .mb1_44:
            return DiskGeometry(totalSectors: 2880, sectorsPerTrack: 18, heads: 2,
                                sectorsPerCluster: 1, rootEntries: 224, mediaDescriptor: 0xF0, fatType: 12)
        default:
            return DiskGeometry(totalSectors: 1440, sectorsPerTrack: 9, heads: 2,
                                sectorsPerCluster: 2, rootEntries: 112, mediaDescriptor: 0xF9, fatType: 12)
        }
    }

    private func splitFileName(_ name: String) -> (String, String) {
        var baseName = name.uppercased()
        var ext = ""

        if let dotIndex = baseName.lastIndex(of: ".") {
            ext = String(baseName[baseName.index(after: dotIndex)...])
            baseName = String(baseName[..<dotIndex])
        }

        baseName = baseName.filter { char in
            let ascii = char.asciiValue ?? 0
            return (ascii >= 0x41 && ascii <= 0x5A) ||
                   (ascii >= 0x30 && ascii <= 0x39) ||
                   char == "_" || char == "-" || char == "~"
        }

        ext = ext.filter { char in
            let ascii = char.asciiValue ?? 0
            return (ascii >= 0x41 && ascii <= 0x5A) ||
                   (ascii >= 0x30 && ascii <= 0x39)
        }

        return (String(baseName.prefix(8)), String(ext.prefix(3)))
    }
}
