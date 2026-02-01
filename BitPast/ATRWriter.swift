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

    func createDiskImage(at url: URL, volumeName: String, size: DiskSize, files: [(url: URL, name: String)]) -> Bool {
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
        // Start after boot sectors, skip VTOC (360) and directory (361-368)
        var nextSector = 4  // First user data sector (1-3 are boot)
        var dirEntryIndex = 0

        // Reserved sectors: VTOC at 360, directory at 361-368
        let reservedStart = 360
        let reservedEnd = 368

        for file in files {
            guard let fileData = try? Data(contentsOf: file.url) else {
                print("ATRWriter: Could not read file \(file.name)")
                continue
            }

            // Use provided name with extension from URL
            let fileName = cleanAtariFileName(file.name)
            let fileExt = file.url.pathExtension.uppercased().prefix(3)

            // Skip reserved sectors if we're about to write into them
            if nextSector >= reservedStart && nextSector <= reservedEnd {
                nextSector = reservedEnd + 1
            }

            let startSector = nextSector

            // Write file data
            var remaining = fileData
            var currentSector = startSector
            var sectorList: [Int] = []

            while !remaining.isEmpty && currentSector < sectorCount {
                // Skip reserved sectors
                if currentSector >= reservedStart && currentSector <= reservedEnd {
                    currentSector = reservedEnd + 1
                }

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
                var nextS = 0
                if !remaining.isEmpty {
                    nextS = currentSector + 1
                    // Skip reserved sectors in link
                    if nextS >= reservedStart && nextS <= reservedEnd {
                        nextS = reservedEnd + 1
                    }
                }
                let bytesInSector = remaining.isEmpty ? chunk.count : dataSize

                // Atari DOS 2.0S sector link format (last 3 bytes):
                // Byte 0: bits 7-2 = file number (0-63), bits 1-0 = high 2 bits of next sector
                // Byte 1: low 8 bits of next sector
                // Byte 2: number of data bytes in sector (excluding link bytes)
                let linkOffset = offset + bytesPerSector - 3
                let fileNum = UInt8(truncatingIfNeeded: dirEntryIndex & 0x3F)
                let nextHi = UInt8((nextS >> 8) & 0x03)
                diskData[linkOffset] = (fileNum << 2) | nextHi
                diskData[linkOffset + 1] = UInt8(nextS & 0xFF)
                diskData[linkOffset + 2] = UInt8(bytesInSector)

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
        // VTOC at sector 360 (standard location for DOS 2.0S/2.5)
        let vtocSector = 360
        let vtocOffset = sectorOffset(sector: vtocSector, bytesPerSector: bytesPerSector)

        // DOS code type: 0x02 for DOS 2.0S (720 sectors), DOS 2.5 uses same for ED disks
        data[vtocOffset] = 0x02

        // Total sectors (for DOS 2.0S compatibility, report up to 720 in main VTOC)
        // Enhanced density (1040 sectors) is tracked separately in extended VTOC
        let reportedSectors = min(sectorCount, 720)
        data[vtocOffset + 1] = UInt8(reportedSectors & 0xFF)
        data[vtocOffset + 2] = UInt8((reportedSectors >> 8) & 0xFF)

        // Free sectors (minus boot, VTOC, directory)
        // Reserved: sectors 1-3 (boot), 360 (VTOC), 361-368 (directory) = 12 sectors
        let reservedSectors = 12
        let freeSectors = sectorCount - reservedSectors
        data[vtocOffset + 3] = UInt8(freeSectors & 0xFF)
        data[vtocOffset + 4] = UInt8((freeSectors >> 8) & 0xFF)

        // VTOC bitmap - bytes to cover all sectors (1 bit per sector)
        // 90 bytes covers 720 sectors, 130 bytes covers 1040 sectors
        let bitmapBytes = (sectorCount + 7) / 8
        let safeBitmapBytes = min(bitmapBytes, 118)  // Leave room in 128-byte sector

        // Initialize bitmap: all sectors free (1 = free)
        for i in 0..<safeBitmapBytes {
            data[vtocOffset + 10 + i] = 0xFF
        }

        // Mark boot sectors (1-3) as used
        data[vtocOffset + 10] = 0xF8  // Sectors 1-3 used (bits 0-2 clear)

        // Mark VTOC and directory sectors (360-368) as used
        for sector in 360...368 {
            let byteIndex = sector / 8
            let bitIndex = sector % 8
            if byteIndex < safeBitmapBytes {
                data[vtocOffset + 10 + byteIndex] &= ~UInt8(1 << bitIndex)
            }
        }

        // Initialize all 8 directory sectors (361-368)
        for dirSectorNum in 361...368 {
            let dirOffset = sectorOffset(sector: dirSectorNum, bytesPerSector: bytesPerSector)
            // Initialize all 8 entries in this sector (16 bytes each)
            for i in 0..<8 {
                let entryOffset = dirOffset + i * 16
                // Clear entire entry
                for j in 0..<16 {
                    data[entryOffset + j] = 0x00
                }
            }
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

        // Support up to 1040 sectors (130KB enhanced density)
        // 118 bytes for bitmap leaves room in 128-byte sector
        if byteIndex < 118 {
            data[vtocOffset + 10 + byteIndex] &= ~UInt8(1 << bitIndex)

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
