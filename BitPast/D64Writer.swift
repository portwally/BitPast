import Foundation

// MARK: - D64 Disk Writer
// Commodore 64/VIC-20/Plus4 disk image writer supporting D64, D71, and D81 formats

class D64Writer {
    static let shared = D64Writer()
    private init() {}

    // MARK: - D64 Format Constants

    // D64: 35 tracks, 683 sectors
    private let d64TracksPerSide = 35
    private let d64TotalSectors = 683

    // D71: 70 tracks (double-sided), 1366 sectors
    private let d71TracksPerSide = 35
    private let d71TotalSectors = 1366

    // D81: 80 tracks, 3200 sectors
    private let d81Tracks = 80
    private let d81SectorsPerTrack = 40
    private let d81TotalSectors = 3200

    private let sectorSize = 256
    private let dirTrack = 18
    private let dirSector = 1

    // Sectors per track for D64/D71 (varies by zone)
    private let sectorsPerTrack: [Int] = [
        21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21,  // Tracks 1-17
        19, 19, 19, 19, 19, 19, 19,                                          // Tracks 18-24
        18, 18, 18, 18, 18, 18,                                              // Tracks 25-30
        17, 17, 17, 17, 17                                                   // Tracks 31-35
    ]

    // MARK: - Public Interface

    func createDiskImage(at url: URL, volumeName: String, format: DiskFormat, size: DiskSize, files: [URL]) -> Bool {
        // Convert to named files using URL's lastPathComponent
        let namedFiles = files.map { (url: $0, name: $0.deletingPathExtension().lastPathComponent) }
        return createDiskImageWithNames(at: url, volumeName: volumeName, format: format, size: size, files: namedFiles)
    }

    func createDiskImageWithNames(at url: URL, volumeName: String, format: DiskFormat, size: DiskSize, files: [(url: URL, name: String)]) -> Bool {
        switch format {
        case .d64:
            return createD64(at: url, volumeName: volumeName, files: files)
        case .d71:
            return createD71(at: url, volumeName: volumeName, files: files)
        case .d81:
            return createD81(at: url, volumeName: volumeName, files: files)
        default:
            print("D64Writer: Unsupported format \(format)")
            return false
        }
    }

    // MARK: - D64 Creation (35 tracks, 170KB)

    private func createD64(at url: URL, volumeName: String, files: [(url: URL, name: String)]) -> Bool {
        // Create blank disk image
        var diskData = Data(count: d64TotalSectors * sectorSize)

        // Initialize BAM at track 18, sector 0
        let bamOffset = sectorOffset(track: 18, sector: 0)
        initializeD64BAM(in: &diskData, at: bamOffset, volumeName: volumeName)

        // Initialize directory at track 18, sector 1
        let dirOffset = sectorOffset(track: 18, sector: 1)
        diskData[dirOffset] = 0x00  // No more directory sectors
        diskData[dirOffset + 1] = 0xFF

        // Write files to disk
        var nextTrack = 1
        var nextSector = 0
        var dirEntryIndex = 0

        for (fileUrl, originalName) in files {
            guard let fileData = try? Data(contentsOf: fileUrl) else {
                print("D64Writer: Could not read file \(fileUrl.lastPathComponent)")
                continue
            }

            // Determine file type from extension
            let ext = fileUrl.pathExtension.lowercased()
            let fileType: UInt8 = (ext == "prg" || ext == "kla" || ext == "art") ? 0x82 : 0x82  // PRG closed

            // Clean filename for CBM DOS (max 16 chars) - use original name
            let fileName = cleanCBMFileName(originalName)

            // Find starting track/sector (skip track 18 which is directory)
            if nextTrack == 18 {
                nextTrack = 19
                nextSector = 0
            }

            let startTrack = nextTrack
            let startSector = nextSector

            // Write file data in sectors
            var remaining = fileData
            var currentTrack = startTrack
            var currentSector = startSector
            var sectorCount = 0

            while !remaining.isEmpty {
                // Skip directory track
                if currentTrack == 18 {
                    currentTrack = 19
                    currentSector = 0
                }

                // Check if we've exceeded disk capacity
                if currentTrack > d64TracksPerSide {
                    print("D64Writer: Disk full")
                    break
                }

                let offset = sectorOffset(track: currentTrack, sector: currentSector)
                let chunkSize = min(254, remaining.count)  // 254 bytes per sector (2 bytes for link)
                let chunk = remaining.prefix(chunkSize)
                remaining = remaining.dropFirst(chunkSize)

                // Calculate next track/sector
                let (nextT, nextS) = nextFreeSector(track: currentTrack, sector: currentSector)

                if remaining.isEmpty {
                    // Last sector
                    diskData[offset] = 0x00
                    diskData[offset + 1] = UInt8(chunkSize + 1)  // Bytes used in last sector
                } else {
                    diskData[offset] = UInt8(nextT)
                    diskData[offset + 1] = UInt8(nextS)
                }

                // Copy file data
                for (i, byte) in chunk.enumerated() {
                    diskData[offset + 2 + i] = byte
                }

                // Mark sector as used in BAM
                markSectorUsed(in: &diskData, bamOffset: bamOffset, track: currentTrack, sector: currentSector)

                sectorCount += 1
                currentTrack = nextT
                currentSector = nextS
            }

            // Add directory entry
            addDirectoryEntry(
                in: &diskData,
                dirOffset: dirOffset,
                entryIndex: dirEntryIndex,
                fileName: fileName,
                fileType: fileType,
                startTrack: startTrack,
                startSector: startSector,
                sectorCount: sectorCount
            )
            dirEntryIndex += 1

            // Update next available position
            nextTrack = currentTrack
            nextSector = currentSector
        }

        // Write disk image to file
        do {
            try diskData.write(to: url)
            print("D64Writer: Created D64 at \(url.path)")
            return true
        } catch {
            print("D64Writer: Failed to write disk image: \(error)")
            return false
        }
    }

    // MARK: - D71 Creation (70 tracks, 340KB)

    private func createD71(at url: URL, volumeName: String, files: [(url: URL, name: String)]) -> Bool {
        // D71 is essentially two D64 sides
        var diskData = Data(count: d71TotalSectors * sectorSize)

        // Initialize BAM at track 18, sector 0
        let bamOffset = sectorOffset(track: 18, sector: 0)
        initializeD71BAM(in: &diskData, at: bamOffset, volumeName: volumeName)

        // Initialize directory
        let dirOffset = sectorOffset(track: 18, sector: 1)
        diskData[dirOffset] = 0x00
        diskData[dirOffset + 1] = 0xFF

        // Write files (similar to D64 but with extended track range)
        var nextTrack = 1
        var nextSector = 0
        var dirEntryIndex = 0

        for (fileUrl, originalName) in files {
            guard let fileData = try? Data(contentsOf: fileUrl) else { continue }

            let fileType: UInt8 = 0x82
            let fileName = cleanCBMFileName(originalName)

            if nextTrack == 18 { nextTrack = 19; nextSector = 0 }

            let startTrack = nextTrack
            let startSector = nextSector
            var remaining = fileData
            var currentTrack = startTrack
            var currentSector = startSector
            var sectorCount = 0

            while !remaining.isEmpty {
                if currentTrack == 18 { currentTrack = 19; currentSector = 0 }
                if currentTrack > 70 { break }

                let offset = sectorOffsetD71(track: currentTrack, sector: currentSector)
                let chunkSize = min(254, remaining.count)
                let chunk = remaining.prefix(chunkSize)
                remaining = remaining.dropFirst(chunkSize)

                let (nextT, nextS) = nextFreeSectorD71(track: currentTrack, sector: currentSector)

                if remaining.isEmpty {
                    diskData[offset] = 0x00
                    diskData[offset + 1] = UInt8(chunkSize + 1)
                } else {
                    diskData[offset] = UInt8(nextT)
                    diskData[offset + 1] = UInt8(nextS)
                }

                for (i, byte) in chunk.enumerated() {
                    diskData[offset + 2 + i] = byte
                }

                sectorCount += 1
                currentTrack = nextT
                currentSector = nextS
            }

            addDirectoryEntry(in: &diskData, dirOffset: dirOffset, entryIndex: dirEntryIndex,
                              fileName: fileName, fileType: fileType,
                              startTrack: startTrack, startSector: startSector, sectorCount: sectorCount)
            dirEntryIndex += 1
            nextTrack = currentTrack
            nextSector = currentSector
        }

        do {
            try diskData.write(to: url)
            print("D64Writer: Created D71 at \(url.path)")
            return true
        } catch {
            print("D64Writer: Failed to write D71: \(error)")
            return false
        }
    }

    // MARK: - D81 Creation (80 tracks, 800KB)

    private func createD81(at url: URL, volumeName: String, files: [(url: URL, name: String)]) -> Bool {
        // D81: 80 tracks, 40 sectors per track, 256 bytes per sector
        var diskData = Data(count: d81TotalSectors * sectorSize)

        // D81 has header at track 40, sector 0 and BAM at track 40, sectors 1-2
        let headerOffset = d81SectorOffset(track: 40, sector: 0)
        let bamOffset1 = d81SectorOffset(track: 40, sector: 1)
        let bamOffset2 = d81SectorOffset(track: 40, sector: 2)

        initializeD81Header(in: &diskData, at: headerOffset, volumeName: volumeName)
        initializeD81BAM(in: &diskData, at: bamOffset1, part: 1)
        initializeD81BAM(in: &diskData, at: bamOffset2, part: 2)

        // Directory starts at track 40, sector 3
        let dirOffset = d81SectorOffset(track: 40, sector: 3)
        diskData[dirOffset] = 0x00
        diskData[dirOffset + 1] = 0xFF

        // Write files
        var nextTrack = 1
        var nextSector = 0
        var dirEntryIndex = 0

        for (fileUrl, originalName) in files {
            guard let fileData = try? Data(contentsOf: fileUrl) else { continue }

            let fileType: UInt8 = 0x82
            let fileName = cleanCBMFileName(originalName)

            // Skip directory track (40)
            if nextTrack == 40 { nextTrack = 41; nextSector = 0 }

            let startTrack = nextTrack
            let startSector = nextSector
            var remaining = fileData
            var currentTrack = startTrack
            var currentSector = startSector
            var sectorCount = 0

            while !remaining.isEmpty {
                if currentTrack == 40 { currentTrack = 41; currentSector = 0 }
                if currentTrack > d81Tracks { break }

                let offset = d81SectorOffset(track: currentTrack, sector: currentSector)
                let chunkSize = min(254, remaining.count)
                let chunk = remaining.prefix(chunkSize)
                remaining = remaining.dropFirst(chunkSize)

                let (nextT, nextS) = nextFreeSectorD81(track: currentTrack, sector: currentSector)

                if remaining.isEmpty {
                    diskData[offset] = 0x00
                    diskData[offset + 1] = UInt8(chunkSize + 1)
                } else {
                    diskData[offset] = UInt8(nextT)
                    diskData[offset + 1] = UInt8(nextS)
                }

                for (i, byte) in chunk.enumerated() {
                    diskData[offset + 2 + i] = byte
                }

                sectorCount += 1
                currentTrack = nextT
                currentSector = nextS
            }

            addD81DirectoryEntry(in: &diskData, dirOffset: dirOffset, entryIndex: dirEntryIndex,
                                 fileName: fileName, fileType: fileType,
                                 startTrack: startTrack, startSector: startSector, sectorCount: sectorCount)
            dirEntryIndex += 1
            nextTrack = currentTrack
            nextSector = currentSector
        }

        do {
            try diskData.write(to: url)
            print("D64Writer: Created D81 at \(url.path)")
            return true
        } catch {
            print("D64Writer: Failed to write D81: \(error)")
            return false
        }
    }

    // MARK: - BAM Initialization

    private func initializeD64BAM(in data: inout Data, at offset: Int, volumeName: String) {
        // Track/sector of first directory sector
        data[offset + 0] = 18
        data[offset + 1] = 1

        // DOS version
        data[offset + 2] = 0x41  // 'A' for 1541

        // Unused
        data[offset + 3] = 0x00

        // BAM entries for tracks 1-35 (4 bytes each)
        for track in 1...35 {
            let bamEntryOffset = offset + 4 + (track - 1) * 4
            let sectors = sectorsPerTrack[track - 1]
            data[bamEntryOffset] = UInt8(sectors)  // Free sectors count

            // Bitmap of free sectors (1 = free)
            var bitmap: UInt32 = 0
            for s in 0..<sectors {
                bitmap |= (1 << s)
            }

            data[bamEntryOffset + 1] = UInt8(bitmap & 0xFF)
            data[bamEntryOffset + 2] = UInt8((bitmap >> 8) & 0xFF)
            data[bamEntryOffset + 3] = UInt8((bitmap >> 16) & 0xFF)
        }

        // Mark track 18 sectors 0-1 as used (BAM and directory)
        let track18Offset = offset + 4 + 17 * 4
        data[track18Offset] = UInt8(sectorsPerTrack[17] - 2)
        data[track18Offset + 1] &= ~0x03  // Clear bits 0-1

        // Disk name (16 bytes at offset $90 = 144)
        let nameOffset = offset + 0x90
        let paddedName = volumeName.padding(toLength: 16, withPad: "\u{A0}", startingAt: 0)
        for (i, char) in paddedName.prefix(16).enumerated() {
            data[nameOffset + i] = petsciiChar(char)
        }

        // $A0-$A1 (160-161): Shifted spaces after disk name
        data[offset + 0xA0] = 0xA0
        data[offset + 0xA1] = 0xA0

        // $A2-$A3 (162-163): Disk ID
        data[offset + 0xA2] = 0x30  // '0'
        data[offset + 0xA3] = 0x30  // '0'

        // $A4 (164): Shifted space
        data[offset + 0xA4] = 0xA0

        // $A5-$A6 (165-166): DOS type "2A"
        data[offset + 0xA5] = 0x32  // '2'
        data[offset + 0xA6] = 0x41  // 'A'

        // $A7-$AA (167-170): Shifted spaces
        data[offset + 0xA7] = 0xA0
        data[offset + 0xA8] = 0xA0
        data[offset + 0xA9] = 0xA0
        data[offset + 0xAA] = 0xA0
    }

    private func initializeD71BAM(in data: inout Data, at offset: Int, volumeName: String) {
        // Similar to D64 but with extended BAM for second side
        initializeD64BAM(in: &data, at: offset, volumeName: volumeName)

        // D71 flag
        data[offset + 3] = 0x80  // Double-sided flag
    }

    private func initializeD81Header(in data: inout Data, at offset: Int, volumeName: String) {
        // Track/sector of first directory sector
        data[offset + 0] = 40
        data[offset + 1] = 3

        // DOS version
        data[offset + 2] = 0x44  // 'D' for 1581

        // Disk name (16 bytes at offset 4)
        let paddedName = volumeName.padding(toLength: 16, withPad: "\u{A0}", startingAt: 0)
        for (i, char) in paddedName.prefix(16).enumerated() {
            data[offset + 4 + i] = petsciiChar(char)
        }

        // Disk ID
        data[offset + 22] = 0x33  // '3'
        data[offset + 23] = 0x44  // 'D'
    }

    private func initializeD81BAM(in data: inout Data, at offset: Int, part: Int) {
        // D81 BAM: 40 sectors per track, 6 bytes per track (1 byte count + 5 bytes bitmap)
        let startTrack = part == 1 ? 1 : 41
        let endTrack = part == 1 ? 40 : 80

        var pos = 0
        for track in startTrack...endTrack {
            // Free sectors count (40 per track, minus reserved on track 40)
            let freeCount = (track == 40) ? 37 : 40
            data[offset + pos] = UInt8(freeCount)

            // Bitmap (5 bytes = 40 bits)
            var bitmap: UInt64 = 0
            for s in 0..<40 {
                bitmap |= (1 << s)
            }

            // Mark reserved sectors on directory track
            if track == 40 {
                bitmap &= ~0x0F  // Sectors 0-3 used
            }

            data[offset + pos + 1] = UInt8(bitmap & 0xFF)
            data[offset + pos + 2] = UInt8((bitmap >> 8) & 0xFF)
            data[offset + pos + 3] = UInt8((bitmap >> 16) & 0xFF)
            data[offset + pos + 4] = UInt8((bitmap >> 24) & 0xFF)
            data[offset + pos + 5] = UInt8((bitmap >> 32) & 0xFF)

            pos += 6
        }
    }

    // MARK: - Directory Entry

    private func addDirectoryEntry(in data: inout Data, dirOffset: Int, entryIndex: Int,
                                   fileName: String, fileType: UInt8,
                                   startTrack: Int, startSector: Int, sectorCount: Int) {
        // Each directory entry is 32 bytes. Entry 0 at offset 0, entry 1 at offset 32, etc.
        // Bytes 0-1 of entry 0 overlap with sector chain link (set elsewhere)
        let entryOffset = dirOffset + (entryIndex % 8) * 32

        // $02: File type (PRG = $82)
        data[entryOffset + 2] = fileType

        // $03-$04: First track/sector of file
        data[entryOffset + 3] = UInt8(startTrack)
        data[entryOffset + 4] = UInt8(startSector)

        // $05-$14: Filename (16 bytes, PETSCII, padded with $A0)
        let paddedName = fileName.padding(toLength: 16, withPad: "\u{A0}", startingAt: 0)
        for (i, char) in paddedName.prefix(16).enumerated() {
            data[entryOffset + 5 + i] = petsciiChar(char)
        }

        // $1E-$1F: File size in sectors (16-bit little-endian)
        data[entryOffset + 0x1E] = UInt8(sectorCount & 0xFF)
        data[entryOffset + 0x1F] = UInt8((sectorCount >> 8) & 0xFF)
    }

    private func addD81DirectoryEntry(in data: inout Data, dirOffset: Int, entryIndex: Int,
                                      fileName: String, fileType: UInt8,
                                      startTrack: Int, startSector: Int, sectorCount: Int) {
        // Same format as D64
        addDirectoryEntry(in: &data, dirOffset: dirOffset, entryIndex: entryIndex,
                          fileName: fileName, fileType: fileType,
                          startTrack: startTrack, startSector: startSector, sectorCount: sectorCount)
    }

    // MARK: - Sector Calculations

    private func sectorOffset(track: Int, sector: Int) -> Int {
        // Calculate absolute byte offset for track/sector in D64
        var offset = 0
        for t in 1..<track {
            offset += sectorsPerTrack[t - 1] * sectorSize
        }
        offset += sector * sectorSize
        return offset
    }

    private func sectorOffsetD71(track: Int, sector: Int) -> Int {
        // D71: tracks 1-35 are side 1, tracks 36-70 are side 2
        if track <= 35 {
            return sectorOffset(track: track, sector: sector)
        } else {
            // Side 2 starts after all side 1 sectors
            let side1Size = d64TotalSectors * sectorSize
            return side1Size + sectorOffset(track: track - 35, sector: sector)
        }
    }

    private func d81SectorOffset(track: Int, sector: Int) -> Int {
        // D81: 40 sectors per track, 256 bytes per sector
        return ((track - 1) * d81SectorsPerTrack + sector) * sectorSize
    }

    private func nextFreeSector(track: Int, sector: Int) -> (Int, Int) {
        // Sequential sector allocation (simpler and more space-efficient)
        var newSector = sector + 1
        var newTrack = track

        // Check if we've exceeded sectors on this track
        if newSector >= sectorsPerTrack[track - 1] {
            newTrack += 1
            newSector = 0
            if newTrack == 18 { newTrack = 19 }  // Skip directory track
        }

        if newTrack > d64TracksPerSide {
            return (d64TracksPerSide + 1, 0)  // Disk full
        }

        return (newTrack, newSector)
    }

    private func nextFreeSectorD71(track: Int, sector: Int) -> (Int, Int) {
        let maxSectors = track <= 35 ? sectorsPerTrack[track - 1] : sectorsPerTrack[(track - 36)]
        var newSector = sector + 1
        var newTrack = track

        if newSector >= maxSectors {
            newTrack += 1
            newSector = 0
            if newTrack == 18 || newTrack == 53 { newTrack += 1 }  // Skip directory tracks
        }

        if newTrack > 70 {
            return (71, 0)  // Disk full
        }

        return (newTrack, newSector)
    }

    private func nextFreeSectorD81(track: Int, sector: Int) -> (Int, Int) {
        let newSector = (sector + 1) % d81SectorsPerTrack
        var newTrack = track

        if newSector == 0 {
            newTrack += 1
            if newTrack == 40 { newTrack = 41 }  // Skip directory track
            if newTrack > d81Tracks {
                return (d81Tracks + 1, 0)  // Disk full
            }
        }

        return (newTrack, newSector)
    }

    private func markSectorUsed(in data: inout Data, bamOffset: Int, track: Int, sector: Int) {
        let bamEntryOffset = bamOffset + 4 + (track - 1) * 4

        // Decrement free sector count
        if data[bamEntryOffset] > 0 {
            data[bamEntryOffset] -= 1
        }

        // Clear bit in bitmap
        let byteIndex = sector / 8
        let bitIndex = sector % 8
        data[bamEntryOffset + 1 + byteIndex] &= ~(1 << bitIndex)
    }

    // MARK: - Helpers

    private func cleanCBMFileName(_ name: String) -> String {
        // Remove extension and convert to uppercase
        var clean = name.uppercased()
        if let dotIndex = clean.lastIndex(of: ".") {
            clean = String(clean[..<dotIndex])
        }

        // Keep only valid CBM DOS characters
        clean = clean.filter { char in
            let ascii = char.asciiValue ?? 0
            return (ascii >= 0x41 && ascii <= 0x5A) ||  // A-Z
                   (ascii >= 0x30 && ascii <= 0x39) ||  // 0-9
                   char == " " || char == "-" || char == "_"
        }

        return String(clean.prefix(16))
    }

    private func petsciiChar(_ char: Character) -> UInt8 {
        let ascii = char.asciiValue ?? 0x20

        // Handle shifted space (padding character)
        if char == "\u{A0}" {
            return 0xA0
        }

        // Convert ASCII to PETSCII for CBM DOS
        // Use UNSHIFTED range $41-$5A for uppercase (displays as letters in default C64 mode)
        if ascii >= 0x41 && ascii <= 0x5A {
            // Uppercase letters: keep as $41-$5A
            return ascii
        } else if ascii >= 0x61 && ascii <= 0x7A {
            // Lowercase to uppercase: convert to $41-$5A range
            return ascii - 0x20
        }

        return ascii
    }
}
