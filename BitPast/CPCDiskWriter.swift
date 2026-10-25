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

    /// CP/M-based disk formats written by this class. Both use 9 sectors of
    /// 512 bytes per track, 1 KB blocks and a 64-entry directory.
    enum Format {
        /// Amstrad CPC AMSDOS "Data" format: sector IDs &C1-&C9, no reserved tracks.
        case amstradData
        /// ZX Spectrum +3DOS format: sector IDs 1-9, track 0 reserved for the
        /// disk specification, and a 128-byte PLUS3DOS header on every file.
        case spectrumPlus3
    }

    /// Where things live on the disk for one format and size.
    private struct Layout {
        let tracks: Int
        let sides: Int
        let firstSectorID: Int
        let reservedTracks: Int

        init(size: DiskSize, format: Format) {
            tracks = 40
            sides = size == .kb360 ? 2 : 1
            firstSectorID = format == .spectrumPlus3 ? 0x01 : 0xC1
            reservedTracks = format == .spectrumPlus3 ? 1 : 0
        }
    }

    // MARK: - Public Interface

    func createDiskImage(at url: URL, volumeName: String, size: DiskSize, files: [(url: URL, name: String)],
                         format: Format = .amstradData) -> Bool {
        let layout = Layout(size: size, format: format)
        let numTracks = layout.tracks
        let numSides = layout.sides

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
                initializeTrackHeader(in: &diskData, at: trackOffset, track: track, side: side,
                                      firstSectorID: layout.firstSectorID)
            }
        }

        // Initialize directory (first 4 sectors after the reserved tracks)
        initializeDirectory(in: &diskData, layout: layout)

        if format == .spectrumPlus3 {
            writePlus3DiskSpec(in: &diskData)
        }

        // Write files
        var nextBlock = 2  // First two blocks are directory
        var dirEntryIndex = 0

        for file in files {
            guard var fileData = try? Data(contentsOf: file.url) else {
                print("CPCDiskWriter: Could not read file \(file.name)")
                continue
            }
            if format == .spectrumPlus3 {
                fileData = plus3Header(for: fileData, ext: file.url.pathExtension) + fileData
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
                writeBlock(in: &diskData, block: currentBlock, data: chunk, layout: layout)

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
                layout: layout
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
        // Written as raw bytes: Swift treats "\r\n" as one Character
        let signature = Array("EXTENDED CPC DSK File\r\nDisk-Info\r\n".utf8)
        data.replaceSubrange(0..<signature.count, with: signature)

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

    private func initializeTrackHeader(in data: inout Data, at offset: Int, track: Int, side: Int, firstSectorID: Int) {
        // Track-Info signature (raw bytes, see initializeDiskHeader)
        let signature = Array("Track-Info\r\n".utf8)
        data.replaceSubrange(offset..<(offset + signature.count), with: signature)

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

            // Sector ID (&C1-&C9 on CPC Data disks, 1-9 on +3 disks)
            data[sectorInfoOffset + 2] = UInt8(firstSectorID + sector)

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

    private func initializeDirectory(in data: inout Data, layout: Layout) {
        // Directory is in first 4 sectors (2KB)
        // Initialize all entries as empty (0xE5)
        let dirOffset = sectorOffset(track: 0, sector: 0, layout: layout)
        for i in 0..<(directoryEntries * 32) {
            data[dirOffset + i] = 0xE5
        }
    }

    // MARK: - Directory Entry

    /// Adds directory entries for a file, creating multiple extents if needed for files > 16KB
    /// Returns the number of directory entries used
    private func addDirectoryEntry(in data: inout Data, entryIndex: Int, fileName: String,
                                   fileExt: String, blocks: [Int], fileSize: Int,
                                   layout: Layout) -> Int {
        let dirOffset = sectorOffset(track: 0, sector: 0, layout: layout)
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
                            layout: Layout) {
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

            let offset = sectorOffset(track: track, sector: sectorInTrack, layout: layout)

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

    /// Offset of a filesystem sector. `track` counts from the first track after
    /// the reserved ones; the filesystem only uses side 0.
    private func sectorOffset(track: Int, sector: Int, layout: Layout) -> Int {
        let trackSize = trackHeaderSize + sectorsPerTrack * sectorSize
        let trackIndex = (track + layout.reservedTracks) * layout.sides + (sector >= sectorsPerTrack ? 1 : 0)
        let sectorInTrack = sector % sectorsPerTrack

        return diskHeaderSize + trackIndex * trackSize + trackHeaderSize + sectorInTrack * sectorSize
    }

    // MARK: - Spectrum +3

    /// Disk specification in the first sector of track 0: standard +3 format,
    /// single sided, 40 tracks, 9 sectors of 512 bytes, 1 reserved track,
    /// 1 KB blocks, 2 directory blocks.
    private func writePlus3DiskSpec(in data: inout Data) {
        let spec: [UInt8] = [0x00, 0x00, 0x28, 0x09, 0x02, 0x01, 0x03, 0x02, 0x2A, 0x52, 0, 0, 0, 0, 0, 0]
        let offset = diskHeaderSize + trackHeaderSize  // track 0, first sector
        data.replaceSubrange(offset..<(offset + spec.count), with: spec)
    }

    /// 128-byte PLUS3DOS header describing the file as CODE. Screens load at
    /// 16384, anything else at 32768.
    private func plus3Header(for fileData: Data, ext: String) -> Data {
        var header = Data(count: 128)
        header.replaceSubrange(0..<8, with: Array("PLUS3DOS".utf8))
        header[8] = 0x1A  // soft EOF
        header[9] = 0x01  // issue
        header[10] = 0x00 // version
        let total = fileData.count + 128
        for i in 0..<4 { header[11 + i] = UInt8((total >> (8 * i)) & 0xFF) }
        let isScreen = ext.lowercased() == "scr" || fileData.count == 6912
        let loadAddress = isScreen ? 16384 : 32768
        header[15] = 0x03  // CODE
        header[16] = UInt8(fileData.count & 0xFF)
        header[17] = UInt8((fileData.count >> 8) & 0xFF)
        header[18] = UInt8(loadAddress & 0xFF)
        header[19] = UInt8((loadAddress >> 8) & 0xFF)
        header[20] = 0x00
        header[21] = 0x80  // 32768: unused for CODE, the conventional value
        header[127] = UInt8(header.prefix(127).reduce(0) { ($0 + Int($1)) & 0xFF })
        return header
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
