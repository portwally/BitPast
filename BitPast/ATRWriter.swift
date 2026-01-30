import Foundation

// MARK: - ATR Disk Writer
// Atari 800 disk image writer supporting ATR format

class ATRWriter {
    static let shared = ATRWriter()
    private init() {}

    // MARK: - ATR Format Constants

    private let sectorSize = 128  // Standard density (can be 256 for double density)
    private let atrHeaderSize = 16

    // Disk sizes
    private let sectors90KB = 720    // 90KB: 720 sectors
    private let sectors130KB = 1040  // 130KB (enhanced): 1040 sectors
    private let sectors180KB = 720   // 180KB: 720 sectors @ 256 bytes
    private let sectors360KB = 1440  // 360KB: 1440 sectors @ 256 bytes

    // MARK: - Public Interface

    func createDiskImage(at url: URL, volumeName: String, size: DiskSize, files: [URL]) -> Bool {
        let (sectorCount, bytesPerSector) = sectorConfig(for: size)
        let diskBytes = sectorCount * bytesPerSector

        // Create ATR header
        var header = Data(count: atrHeaderSize)
        header[0] = 0x96  // ATR signature byte 1
        header[1] = 0x02  // ATR signature byte 2

        // Disk size in paragraphs (16-byte units)
        let paragraphs = diskBytes / 16
        header[2] = UInt8(paragraphs & 0xFF)
        header[3] = UInt8((paragraphs >> 8) & 0xFF)

        // Sector size
        header[4] = UInt8(bytesPerSector & 0xFF)
        header[5] = UInt8((bytesPerSector >> 8) & 0xFF)

        // High byte of paragraph count
        header[6] = UInt8((paragraphs >> 16) & 0xFF)

        // Create disk data
        var diskData = Data(count: diskBytes)

        // Initialize Atari DOS 2.0S compatible structure
        initializeAtariDOS(in: &diskData, volumeName: volumeName, sectorCount: sectorCount, bytesPerSector: bytesPerSector)

        // Write files
        var nextSector = 4  // First user data sector (1-3 are boot + VTOC)
        var dirEntryIndex = 0

        for fileUrl in files {
            guard let fileData = try? Data(contentsOf: fileUrl) else {
                print("ATRWriter: Could not read file \(fileUrl.lastPathComponent)")
                continue
            }

            let fileName = cleanAtariFileName(fileUrl.lastPathComponent)
            let fileExt = fileUrl.pathExtension.uppercased().prefix(3)
            let startSector = nextSector

            // Write file data
            var remaining = fileData
            var currentSector = startSector
            var sectorList: [Int] = []

            while !remaining.isEmpty && currentSector < sectorCount {
                let dataSize = bytesPerSector - 3  // 3 bytes for link
                let chunk = remaining.prefix(dataSize)
                remaining = remaining.dropFirst(dataSize)

                let offset = sectorOffset(sector: currentSector, bytesPerSector: bytesPerSector)

                // Write data
                for (i, byte) in chunk.enumerated() {
                    diskData[offset + i] = byte
                }

                sectorList.append(currentSector)

                // Link to next sector (or end marker)
                let nextS = remaining.isEmpty ? 0 : currentSector + 1
                let bytesInSector = remaining.isEmpty ? chunk.count : dataSize

                // Atari DOS sector format: last 3 bytes are [file#, next_sector_hi_lo, bytes_used]
                let linkOffset = offset + bytesPerSector - 3
                diskData[linkOffset] = UInt8(dirEntryIndex)  // File number
                diskData[linkOffset + 1] = UInt8((nextS >> 8) & 0x03) | UInt8(bytesInSector << 2)
                diskData[linkOffset + 2] = UInt8(nextS & 0xFF)

                currentSector += 1
            }

            // Add directory entry
            addDirectoryEntry(
                in: &diskData,
                entryIndex: dirEntryIndex,
                fileName: String(fileName.prefix(8)),
                fileExt: String(fileExt),
                startSector: startSector,
                sectorCount: sectorList.count,
                bytesPerSector: bytesPerSector
            )

            dirEntryIndex += 1
            nextSector = currentSector

            // Mark sectors as used in VTOC
            for sector in sectorList {
                markSectorUsed(in: &diskData, sector: sector, bytesPerSector: bytesPerSector)
            }
        }

        // Combine header and disk data
        var fullImage = header
        fullImage.append(diskData)

        // Write to file
        do {
            try fullImage.write(to: url)
            print("ATRWriter: Created ATR at \(url.path)")
            return true
        } catch {
            print("ATRWriter: Failed to write ATR: \(error)")
            return false
        }
    }

    // MARK: - DOS Initialization

    private func initializeAtariDOS(in data: inout Data, volumeName: String, sectorCount: Int, bytesPerSector: Int) {
        // VTOC at sector 360 (standard location for DOS 2.0S)
        let vtocSector = 360
        let vtocOffset = sectorOffset(sector: vtocSector, bytesPerSector: bytesPerSector)

        // DOS code type
        data[vtocOffset] = 0x02  // DOS 2.0S

        // Total sectors
        let totalSectors = min(sectorCount, 720)
        data[vtocOffset + 1] = UInt8(totalSectors & 0xFF)
        data[vtocOffset + 2] = UInt8((totalSectors >> 8) & 0xFF)

        // Free sectors
        let freeSectors = totalSectors - 3  // Minus boot + VTOC
        data[vtocOffset + 3] = UInt8(freeSectors & 0xFF)
        data[vtocOffset + 4] = UInt8((freeSectors >> 8) & 0xFF)

        // VTOC bitmap (10 bytes starting at offset 10)
        // Each bit represents a sector (1 = free)
        for i in 0..<90 {
            data[vtocOffset + 10 + i] = 0xFF  // All sectors free initially
        }

        // Mark boot sectors (1-3) and VTOC (360) as used
        data[vtocOffset + 10] = 0xF8  // Sectors 1-3 used (bits 0-2 clear)

        // Mark sector 360 as used
        let vtocByte = 360 / 8
        let vtocBit = 360 % 8
        if vtocByte < 90 {
            data[vtocOffset + 10 + vtocByte] &= ~(1 << vtocBit)
        }

        // Directory starts at sector 361
        let dirOffset = sectorOffset(sector: 361, bytesPerSector: bytesPerSector)
        // Initialize empty directory (8 entries per sector, 16 bytes each)
        for i in 0..<8 {
            data[dirOffset + i * 16] = 0x00  // Deleted/unused entry
        }
    }

    private func addDirectoryEntry(in data: inout Data, entryIndex: Int, fileName: String, fileExt: String,
                                   startSector: Int, sectorCount: Int, bytesPerSector: Int) {
        // Directory at sector 361, 8 entries per sector
        let dirSector = 361 + (entryIndex / 8)
        let entryOffset = sectorOffset(sector: dirSector, bytesPerSector: bytesPerSector) + (entryIndex % 8) * 16

        // Status flags: $42 = in use, DOS 2 file
        data[entryOffset] = 0x42

        // Sector count
        data[entryOffset + 1] = UInt8(sectorCount & 0xFF)
        data[entryOffset + 2] = UInt8((sectorCount >> 8) & 0xFF)

        // Start sector
        data[entryOffset + 3] = UInt8(startSector & 0xFF)
        data[entryOffset + 4] = UInt8((startSector >> 8) & 0xFF)

        // Filename (8 chars, space padded)
        let paddedName = fileName.padding(toLength: 8, withPad: " ", startingAt: 0)
        for (i, char) in paddedName.prefix(8).enumerated() {
            data[entryOffset + 5 + i] = char.asciiValue ?? 0x20
        }

        // Extension (3 chars, space padded)
        let paddedExt = fileExt.padding(toLength: 3, withPad: " ", startingAt: 0)
        for (i, char) in paddedExt.prefix(3).enumerated() {
            data[entryOffset + 13 + i] = char.asciiValue ?? 0x20
        }
    }

    private func markSectorUsed(in data: inout Data, sector: Int, bytesPerSector: Int) {
        let vtocOffset = sectorOffset(sector: 360, bytesPerSector: bytesPerSector)
        let byteIndex = sector / 8
        let bitIndex = sector % 8

        if byteIndex < 90 {
            data[vtocOffset + 10 + byteIndex] &= ~(1 << bitIndex)

            // Decrement free sector count
            let freeCount = Int(data[vtocOffset + 3]) | (Int(data[vtocOffset + 4]) << 8)
            let newCount = max(0, freeCount - 1)
            data[vtocOffset + 3] = UInt8(newCount & 0xFF)
            data[vtocOffset + 4] = UInt8((newCount >> 8) & 0xFF)
        }
    }

    // MARK: - Helpers

    private func sectorConfig(for size: DiskSize) -> (Int, Int) {
        switch size {
        case .kb90: return (720, 128)
        case .kb130: return (1040, 128)
        case .kb180: return (720, 256)
        case .kb360: return (1440, 256)
        default: return (720, 128)
        }
    }

    private func sectorOffset(sector: Int, bytesPerSector: Int) -> Int {
        // First 3 sectors may have different sizes in some formats
        // For simplicity, use uniform sector size
        return (sector - 1) * bytesPerSector
    }

    private func cleanAtariFileName(_ name: String) -> String {
        var clean = name.uppercased()
        if let dotIndex = clean.lastIndex(of: ".") {
            clean = String(clean[..<dotIndex])
        }

        // Atari DOS: A-Z, 0-9 only
        clean = clean.filter { char in
            let ascii = char.asciiValue ?? 0
            return (ascii >= 0x41 && ascii <= 0x5A) || (ascii >= 0x30 && ascii <= 0x39)
        }

        return String(clean.prefix(8))
    }
}
