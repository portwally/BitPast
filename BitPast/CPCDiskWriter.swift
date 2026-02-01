import Foundation

// MARK: - CPC Disk Writer
// Amstrad CPC disk image writer supporting DSK format (CPCEMU extended format)

class CPCDiskWriter {
    static let shared = CPCDiskWriter()
    private init() {}

    // MARK: - CPC DSK Format Constants

    private let sectorSize = 512
    private let sectorsPerTrack = 9
    private let trackHeaderSize = 256
    private let diskHeaderSize = 256

    // AMSDOS constants
    private let directorySectors = 4
    private let directoryEntries = 64
    private let extentSize = 16384  // 16KB per extent

    // MARK: - Public Interface

    func createDiskImage(at url: URL, volumeName: String, size: DiskSize, files: [(url: URL, name: String)]) -> Bool {
        let geometry = diskGeometry(for: size)
        let numTracks = geometry.tracks
        let numSides = geometry.sides

        // Calculate total size with headers
        let trackSize = trackHeaderSize + sectorsPerTrack * sectorSize
        let totalSize = diskHeaderSize + numTracks * numSides * trackSize

        var diskData = Data(count: totalSize)

        // Disk header
        initializeDiskHeader(in: &diskData, tracks: numTracks, sides: numSides)

        // Track headers and sector data
        for track in 0..<numTracks {
            for side in 0..<numSides {
                let trackIndex = track * numSides + side
                let trackOffset = diskHeaderSize + trackIndex * trackSize
                initializeTrackHeader(in: &diskData, at: trackOffset, track: track, side: side)
            }
        }

        // Initialize directory (first 4 sectors of track 0)
        initializeDirectory(in: &diskData, numTracks: numTracks, numSides: numSides)

        // Write files
        var nextBlock = 2  // First two blocks are directory
        var dirEntryIndex = 0

        for file in files {
            guard let fileData = try? Data(contentsOf: file.url) else {
                print("CPCDiskWriter: Could not read file \(file.name)")
                continue
            }

            // Use provided name with extension from URL
            let ext = file.url.pathExtension
            let (fileName, fileExt) = splitCPCFileName("\(file.name).\(ext)")

            // 1KB blocks in AMSDOS
            let blockSize = 1024

            // Write file data
            var remaining = fileData
            var blockList: [Int] = []
            var currentBlock = nextBlock

            while !remaining.isEmpty {
                let chunk = remaining.prefix(blockSize)
                remaining = remaining.dropFirst(blockSize)

                // Write block to disk
                writeBlock(in: &diskData, block: currentBlock, data: chunk, numTracks: numTracks, numSides: numSides)

                blockList.append(currentBlock)
                currentBlock += 1
            }

            // Add directory entry (AMSDOS format) - may use multiple extents for large files
            let entriesUsed = addDirectoryEntry(
                in: &diskData,
                entryIndex: dirEntryIndex,
                fileName: fileName,
                fileExt: fileExt,
                blocks: blockList,
                fileSize: fileData.count,
                numTracks: numTracks,
                numSides: numSides
            )

            dirEntryIndex += entriesUsed
            nextBlock = currentBlock
        }

        // Write to file
        do {
            try diskData.write(to: url)
            print("CPCDiskWriter: Created DSK at \(url.path)")
            return true
        } catch {
            print("CPCDiskWriter: Failed to write DSK: \(error)")
            return false
        }
    }

    // MARK: - Disk Header

    private func initializeDiskHeader(in data: inout Data, tracks: Int, sides: Int) {
        // Extended CPC DSK format signature
        let signature = "EXTENDED CPC DSK File\r\nDisk-Info\r\n"
        for (i, char) in signature.enumerated() {
            data[i] = char.asciiValue ?? 0
        }

        // Creator name (offset 34, 14 bytes)
        let creator = "BitPast       "
        for (i, char) in creator.prefix(14).enumerated() {
            data[34 + i] = char.asciiValue ?? 0x20
        }

        // Number of tracks
        data[48] = UInt8(tracks)

        // Number of sides
        data[49] = UInt8(sides)

        // Track size table (offset 52, one byte per track * side)
        let trackSize = (trackHeaderSize + sectorsPerTrack * sectorSize) / 256
        for i in 0..<(tracks * sides) {
            data[52 + i] = UInt8(trackSize)
        }
    }

    // MARK: - Track Header

    private func initializeTrackHeader(in data: inout Data, at offset: Int, track: Int, side: Int) {
        // Track-Info signature
        let signature = "Track-Info\r\n"
        for (i, char) in signature.enumerated() {
            data[offset + i] = char.asciiValue ?? 0
        }

        // Track number
        data[offset + 16] = UInt8(track)

        // Side number
        data[offset + 17] = UInt8(side)

        // Sector size (2 = 512 bytes)
        data[offset + 20] = 2

        // Number of sectors
        data[offset + 21] = UInt8(sectorsPerTrack)

        // GAP3 length
        data[offset + 22] = 0x4E

        // Filler byte
        data[offset + 23] = 0xE5

        // Sector information (8 bytes per sector)
        for sector in 0..<sectorsPerTrack {
            let sectorInfoOffset = offset + 24 + sector * 8

            // Track ID
            data[sectorInfoOffset] = UInt8(track)

            // Side ID
            data[sectorInfoOffset + 1] = UInt8(side)

            // Sector ID (CPC uses 0xC1-0xC9)
            data[sectorInfoOffset + 2] = UInt8(0xC1 + sector)

            // Sector size (2 = 512 bytes)
            data[sectorInfoOffset + 3] = 2

            // FDC status registers
            data[sectorInfoOffset + 4] = 0
            data[sectorInfoOffset + 5] = 0

            // Actual data length (for extended format)
            data[sectorInfoOffset + 6] = UInt8((sectorSize) & 0xFF)
            data[sectorInfoOffset + 7] = UInt8((sectorSize >> 8) & 0xFF)
        }

        // Fill sector data with 0xE5 (format fill byte)
        let dataOffset = offset + trackHeaderSize
        for i in 0..<(sectorsPerTrack * sectorSize) {
            data[dataOffset + i] = 0xE5
        }
    }

    // MARK: - Directory

    private func initializeDirectory(in data: inout Data, numTracks: Int, numSides: Int) {
        // Directory is in first 4 sectors (2KB)
        // Initialize all entries as empty (0xE5)
        let dirOffset = sectorOffset(track: 0, sector: 0, numSides: numSides)
        for i in 0..<(directoryEntries * 32) {
            data[dirOffset + i] = 0xE5
        }
    }

    // MARK: - Directory Entry

    /// Adds directory entries for a file, creating multiple extents if needed for files > 16KB
    /// Returns the number of directory entries used
    private func addDirectoryEntry(in data: inout Data, entryIndex: Int, fileName: String,
                                   fileExt: String, blocks: [Int], fileSize: Int,
                                   numTracks: Int, numSides: Int) -> Int {
        let dirOffset = sectorOffset(track: 0, sector: 0, numSides: numSides)
        let blocksPerExtent = 16
        let bytesPerExtent = blocksPerExtent * 1024  // 16KB per extent

        var extentNumber = 0
        var remainingSize = fileSize
        var blockIndex = 0
        var entriesUsed = 0

        while blockIndex < blocks.count {
            let entryOffset = dirOffset + (entryIndex + entriesUsed) * 32

            // User number (0)
            data[entryOffset] = 0

            // Filename (8 bytes)
            let paddedName = fileName.uppercased().padding(toLength: 8, withPad: " ", startingAt: 0)
            for (i, char) in paddedName.prefix(8).enumerated() {
                data[entryOffset + 1 + i] = char.asciiValue ?? 0x20
            }

            // Extension (3 bytes)
            let paddedExt = fileExt.uppercased().padding(toLength: 3, withPad: " ", startingAt: 0)
            for (i, char) in paddedExt.prefix(3).enumerated() {
                data[entryOffset + 9 + i] = char.asciiValue ?? 0x20
            }

            // Extent number (low byte)
            data[entryOffset + 12] = UInt8(extentNumber & 0x1F)

            // Reserved
            data[entryOffset + 13] = 0

            // Extent number high byte (for very large files)
            data[entryOffset + 14] = UInt8((extentNumber >> 5) & 0x3F)

            // Calculate blocks for this extent
            let blocksInExtent = min(blocksPerExtent, blocks.count - blockIndex)
            let bytesInExtent = min(remainingSize, bytesPerExtent)

            // Record count (number of 128-byte records in this extent, max 128)
            let records = min((bytesInExtent + 127) / 128, 128)
            data[entryOffset + 15] = UInt8(records)

            // Block allocation (16 bytes for block numbers)
            for i in 0..<16 {
                if i < blocksInExtent {
                    data[entryOffset + 16 + i] = UInt8(blocks[blockIndex + i])
                } else {
                    data[entryOffset + 16 + i] = 0
                }
            }

            blockIndex += blocksInExtent
            remainingSize -= bytesInExtent
            extentNumber += 1
            entriesUsed += 1
        }

        return entriesUsed
    }

    // MARK: - Block Writing

    private func writeBlock(in data: inout Data, block: Int, data chunk: Data.SubSequence,
                            numTracks: Int, numSides: Int) {
        // CPC uses 1KB blocks (2 sectors of 512 bytes each)
        let sectorsPerBlock = 2
        let startSector = block * sectorsPerBlock

        // Write each sector separately to handle track boundaries correctly
        var chunkOffset = 0
        for sectorNum in 0..<sectorsPerBlock {
            // Check if there's any data left to write
            guard chunkOffset < chunk.count else { break }

            let absoluteSector = startSector + sectorNum
            let track = absoluteSector / sectorsPerTrack
            let sectorInTrack = absoluteSector % sectorsPerTrack

            let offset = sectorOffset(track: track, sector: sectorInTrack, numSides: numSides)

            // Write up to 512 bytes for this sector
            let remainingBytes = chunk.count - chunkOffset
            let bytesToWrite = min(sectorSize, remainingBytes)
            for i in 0..<bytesToWrite {
                let sourceIndex = chunk.startIndex.advanced(by: chunkOffset + i)
                if offset + i < data.count {
                    data[offset + i] = chunk[sourceIndex]
                }
            }
            chunkOffset += sectorSize
        }
    }

    // MARK: - Helpers

    private func sectorOffset(track: Int, sector: Int, numSides: Int) -> Int {
        let trackSize = trackHeaderSize + sectorsPerTrack * sectorSize
        let trackIndex = track * numSides + (sector >= sectorsPerTrack ? 1 : 0)
        let sectorInTrack = sector % sectorsPerTrack

        return diskHeaderSize + trackIndex * trackSize + trackHeaderSize + sectorInTrack * sectorSize
    }

    private struct DiskGeometry {
        let tracks: Int
        let sides: Int
    }

    private func diskGeometry(for size: DiskSize) -> DiskGeometry {
        switch size {
        case .kb180: return DiskGeometry(tracks: 40, sides: 1)
        case .kb360: return DiskGeometry(tracks: 40, sides: 2)
        default: return DiskGeometry(tracks: 40, sides: 1)
        }
    }

    private func splitCPCFileName(_ name: String) -> (String, String) {
        var baseName = name.uppercased()
        var ext = ""

        if let dotIndex = baseName.lastIndex(of: ".") {
            ext = String(baseName[baseName.index(after: dotIndex)...])
            baseName = String(baseName[..<dotIndex])
        }

        // CPC allows A-Z, 0-9
        baseName = baseName.filter { char in
            let ascii = char.asciiValue ?? 0
            return (ascii >= 0x41 && ascii <= 0x5A) || (ascii >= 0x30 && ascii <= 0x39)
        }

        ext = ext.filter { char in
            let ascii = char.asciiValue ?? 0
            return (ascii >= 0x41 && ascii <= 0x5A) || (ascii >= 0x30 && ascii <= 0x39)
        }

        return (String(baseName.prefix(8)), String(ext.prefix(3)))
    }
}
