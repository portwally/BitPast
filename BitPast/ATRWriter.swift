import Foundation

// MARK: - ATR Disk Writer
// Atari 800 disk image writer supporting ATR format

class ATRWriter {
    static let shared = ATRWriter()
    private init() {}

    // MARK: - ATR Format Constants

    private let sectorSize = 128  // Standard density (can be 256 for double density)
    private let atrHeaderSize = 16
    private let vtocBitmapSectors = 720  // DOS 2 VTOC tracks sectors 0-719
    private let vtoc2Sector = 1024       // DOS 2.5 second VTOC (enhanced density)

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

        // Write files. DOS 2 links hold 10-bit sector numbers, so nothing at or
        // above 1024 is usable; sector 720 is never used either.
        let enhanced = isEnhancedDensity(sectorCount: sectorCount, bytesPerSector: bytesPerSector)
        let sectorLimit = min(sectorCount, 1024)
        let dataSize = bytesPerSector - 3  // 3 bytes for link
        var nextSector = 4  // First user data sector (1-3 are boot)
        var dirEntryIndex = 0

        for file in files {
            guard let fileData = try? Data(contentsOf: file.url) else {
                Log.error("ATRWriter: Could not read file \(file.name)")
                continue
            }

            // Use provided name with extension from URL
            let fileName = cleanAtariFileName(file.name)
            let fileExt = file.url.pathExtension.uppercased().prefix(3)

            // Pick all sectors first, so a file that does not fit is skipped cleanly
            let sectorsNeeded = max(1, (fileData.count + dataSize - 1) / dataSize)
            var sectorList: [Int] = []
            var candidate = nextSector
            while sectorList.count < sectorsNeeded && candidate < sectorLimit {
                if !isReserved(candidate) { sectorList.append(candidate) }
                candidate += 1
            }
            guard sectorList.count == sectorsNeeded else {
                Log.error("ATRWriter: Disk full, cannot add \(file.name)")
                break
            }
            let startSector = sectorList[0]

            for (i, sector) in sectorList.enumerated() {
                let chunk = fileData.dropFirst(i * dataSize).prefix(dataSize)
                let offset = sectorOffset(sector: sector, bytesPerSector: bytesPerSector)
                diskData.replaceSubrange(offset..<(offset + chunk.count), with: chunk)

                // Atari DOS 2 sector link (last 3 bytes):
                // Byte 0: bits 7-2 = file number (0-63), bits 1-0 = high 2 bits of next sector
                // Byte 1: low 8 bits of next sector
                // Byte 2: number of data bytes in this sector
                let nextS = i + 1 < sectorList.count ? sectorList[i + 1] : 0
                let linkOffset = offset + bytesPerSector - 3
                let fileNum = UInt8(truncatingIfNeeded: dirEntryIndex & 0x3F)
                diskData[linkOffset] = (fileNum << 2) | UInt8((nextS >> 8) & 0x03)
                diskData[linkOffset + 1] = UInt8(nextS & 0xFF)
                diskData[linkOffset + 2] = UInt8(chunk.count)
            }
            nextSector = candidate

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

            // Mark sectors as used in VTOC
            for sector in sectorList {
                markSectorUsed(in: &diskData, sector: sector, bytesPerSector: bytesPerSector, enhanced: enhanced)
            }
        }

        // Combine header and disk data
        var fullImage = header
        fullImage.append(diskData)

        // Write to file
        do {
            try fullImage.write(to: url)
            Log.debug("ATRWriter: Created ATR at \(url.path)")
            return true
        } catch {
            Log.error("ATRWriter: Failed to write ATR: \(error)")
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

        // VTOC bitmap: one bit per sector for sectors 0-719, starting at byte 10.
        // Bit 7 of byte 10 is sector 0, bit 6 is sector 1, ...; a set bit means free.
        // Sector 0 does not exist; sectors 1-3 (boot), 360 (VTOC) and 361-368
        // (directory) are reserved.
        var freeSectors = 0
        for sector in 1..<min(sectorCount, vtocBitmapSectors) {
            if sector <= 3 || (360...368).contains(sector) { continue }
            data[vtocOffset + 10 + sector / 8] |= UInt8(0x80 >> (sector % 8))
            freeSectors += 1
        }

        // Free sectors below 720 (707 on a freshly formatted disk)
        data[vtocOffset + 3] = UInt8(freeSectors & 0xFF)
        data[vtocOffset + 4] = UInt8((freeSectors >> 8) & 0xFF)

        // Enhanced density (DOS 2.5) adds VTOC2 for sectors 720-1023
        var totalSectors = freeSectors
        if isEnhancedDensity(sectorCount: sectorCount, bytesPerSector: bytesPerSector) {
            totalSectors += initializeVTOC2(in: &data, mainVTOCOffset: vtocOffset, bytesPerSector: bytesPerSector)
        }

        // Total usable sectors (707 for 90 KB, 1010 for 130 KB)
        data[vtocOffset + 1] = UInt8(totalSectors & 0xFF)
        data[vtocOffset + 2] = UInt8((totalSectors >> 8) & 0xFF)

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

    private func markSectorUsed(in data: inout Data, sector: Int, bytesPerSector: Int, enhanced: Bool) {
        let vtocOffset = sectorOffset(sector: 360, bytesPerSector: bytesPerSector)
        let vtoc2Offset = sectorOffset(sector: vtoc2Sector, bytesPerSector: bytesPerSector)

        if sector < vtocBitmapSectors {
            if clearBit(in: &data, at: vtocOffset + 10, sector: sector) {
                adjustCount(in: &data, at: vtocOffset + 3, by: -1)
            }
            // VTOC2 mirrors the main bitmap for sectors 48-719
            if enhanced && sector >= 48 {
                _ = clearBit(in: &data, at: vtoc2Offset - 6, sector: sector)
            }
        } else if enhanced && sector < vtoc2Sector {
            if clearBit(in: &data, at: vtoc2Offset + 84 - 90, sector: sector) {
                adjustCount(in: &data, at: vtoc2Offset + 122, by: -1)
            }
        }
    }

    /// Clears the "free" bit for a sector in a bitmap whose bit 7 of byte 0 is
    /// sector 0. Returns false if the sector was already marked used.
    private func clearBit(in data: inout Data, at bitmapOffset: Int, sector: Int) -> Bool {
        let byteOffset = bitmapOffset + sector / 8
        let mask = UInt8(0x80 >> (sector % 8))
        guard data[byteOffset] & mask != 0 else { return false }
        data[byteOffset] &= ~mask
        return true
    }

    private func adjustCount(in data: inout Data, at offset: Int, by delta: Int) {
        let count = max(0, (Int(data[offset]) | Int(data[offset + 1]) << 8) + delta)
        data[offset] = UInt8(count & 0xFF)
        data[offset + 1] = UInt8((count >> 8) & 0xFF)
    }

    // MARK: - Enhanced Density (DOS 2.5)

    private func isEnhancedDensity(sectorCount: Int, bytesPerSector: Int) -> Bool {
        sectorCount == 1040 && bytesPerSector == 128
    }

    /// VTOC2 (sector 1024): bytes 0-83 mirror the main bitmap for sectors 48-719,
    /// bytes 84-121 cover sectors 720-1023, and bytes 122-123 count the free
    /// sectors above 719. Sector 720 stays used, as DOS 2.5 formats it.
    /// Returns the number of free sectors above 719.
    private func initializeVTOC2(in data: inout Data, mainVTOCOffset: Int, bytesPerSector: Int) -> Int {
        let vtoc2Offset = sectorOffset(sector: vtoc2Sector, bytesPerSector: bytesPerSector)
        for i in 0..<84 {
            data[vtoc2Offset + i] = data[mainVTOCOffset + 10 + 6 + i]
        }
        var free = 0
        for sector in 721..<vtoc2Sector {
            let index = sector - 720
            data[vtoc2Offset + 84 + index / 8] |= UInt8(0x80 >> (index % 8))
            free += 1
        }
        data[vtoc2Offset + 122] = UInt8(free & 0xFF)
        data[vtoc2Offset + 123] = UInt8((free >> 8) & 0xFF)
        return free
    }

    /// Sectors DOS never gives to files.
    private func isReserved(_ sector: Int) -> Bool {
        sector <= 3 || (360...368).contains(sector) || sector == 720 || sector >= vtoc2Sector
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
