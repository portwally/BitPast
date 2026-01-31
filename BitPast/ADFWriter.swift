import Foundation

// MARK: - ADF Disk Writer
// Amiga disk image writer supporting ADF format (OFS/FFS)

class ADFWriter {
    static let shared = ADFWriter()
    private init() {}

    // MARK: - ADF Format Constants

    private let sectorSize = 512
    private let sectorsPerTrack = 11
    private let tracks = 80
    private let sides = 2

    // Standard ADF: 880KB (DD) or 1.76MB (HD)
    private let sectorsDD = 1760  // 80 tracks * 2 sides * 11 sectors
    private let sectorsHD = 3520  // 80 tracks * 2 sides * 22 sectors

    // Block types
    private let T_HEADER: Int32 = 2
    private let T_DATA: Int32 = 8
    private let T_LIST: Int32 = 16
    private let ST_ROOT: Int32 = 1
    private let ST_FILE: Int32 = -3

    // Root block location
    private let rootBlockDD = 880  // Middle of disk

    // MARK: - Public Interface

    func createDiskImage(at url: URL, volumeName: String, size: DiskSize, files: [URL]) -> Bool {
        let isHD = (size == .mb1_76)
        let totalSectors = isHD ? sectorsHD : sectorsDD
        let rootBlock = isHD ? 1760 : 880

        var diskData = Data(count: totalSectors * sectorSize)

        // Initialize root block
        initializeRootBlock(in: &diskData, at: rootBlock, volumeName: volumeName, totalSectors: totalSectors)

        // Initialize bitmap blocks
        initializeBitmap(in: &diskData, rootBlock: rootBlock, totalSectors: totalSectors)

        // Write files
        // Start file blocks at block 2 (after bootblock at 0-1)
        // Avoid root block area (880-881 for DD, 1760-1761 for HD)
        var nextBlock = 2
        var hashTable = [Int](repeating: 0, count: 72)

        for fileUrl in files {
            guard let fileData = try? Data(contentsOf: fileUrl) else {
                print("ADFWriter: Could not read file \(fileUrl.lastPathComponent)")
                continue
            }

            let fileName = cleanAmigaFileName(fileUrl.lastPathComponent)
            let hashIndex = amigaHash(fileName) % 72

            // Skip root block and bitmap block area when finding header block
            while nextBlock == rootBlock || nextBlock == rootBlock + 1 {
                nextBlock = rootBlock + 2
            }

            // Find free header block
            let headerBlock = nextBlock
            nextBlock += 1

            // Calculate data blocks needed
            let dataBlockSize = sectorSize - 24  // OFS data blocks have header
            let numDataBlocks = (fileData.count + dataBlockSize - 1) / dataBlockSize

            // Write file header block
            let fileHeaderOffset = headerBlock * sectorSize
            writeFileHeader(
                in: &diskData,
                at: fileHeaderOffset,
                fileName: fileName,
                fileSize: fileData.count,
                headerBlock: headerBlock,
                dataBlocks: numDataBlocks,
                firstDataBlock: nextBlock
            )

            // Write data blocks
            var remaining = fileData
            var dataBlockNum = 0
            var dataBlocks: [Int] = []

            while !remaining.isEmpty && nextBlock < totalSectors {
                // Skip root block and bitmap block area
                if nextBlock == rootBlock || nextBlock == rootBlock + 1 {
                    nextBlock = rootBlock + 2
                    continue
                }

                let chunk = remaining.prefix(dataBlockSize)
                remaining = remaining.dropFirst(dataBlockSize)

                let dataBlockOffset = nextBlock * sectorSize
                dataBlocks.append(nextBlock)

                // OFS data block header
                let nextDataBlock = remaining.isEmpty ? 0 : nextBlock + 1
                writeDataBlock(
                    in: &diskData,
                    at: dataBlockOffset,
                    headerBlock: headerBlock,
                    seqNum: dataBlockNum + 1,
                    dataSize: chunk.count,
                    nextBlock: nextDataBlock,
                    data: chunk
                )

                dataBlockNum += 1
                nextBlock += 1
            }

            // Update file header with data block pointers
            updateFileHeaderDataBlocks(in: &diskData, at: fileHeaderOffset, dataBlocks: dataBlocks)

            // Add to hash table
            if hashTable[hashIndex] == 0 {
                hashTable[hashIndex] = headerBlock
            } else {
                // Chain to existing entry (simplified - just overwrite for now)
                hashTable[hashIndex] = headerBlock
            }

            // Mark blocks as used in bitmap
            markBlockUsed(in: &diskData, rootBlock: rootBlock, block: headerBlock)
            for block in dataBlocks {
                markBlockUsed(in: &diskData, rootBlock: rootBlock, block: block)
            }
        }

        // Update root block hash table
        updateRootHashTable(in: &diskData, at: rootBlock, hashTable: hashTable)

        // Write to file
        do {
            try diskData.write(to: url)
            print("ADFWriter: Created ADF at \(url.path)")
            return true
        } catch {
            print("ADFWriter: Failed to write ADF: \(error)")
            return false
        }
    }

    // MARK: - Root Block

    private func initializeRootBlock(in data: inout Data, at block: Int, volumeName: String, totalSectors: Int) {
        let offset = block * sectorSize

        // Block type (T_HEADER)
        writeInt32(in: &data, at: offset, value: T_HEADER)

        // Header key (self pointer)
        writeInt32(in: &data, at: offset + 4, value: Int32(block))

        // High seq (unused for root)
        writeInt32(in: &data, at: offset + 8, value: 0)

        // Hash table size
        writeInt32(in: &data, at: offset + 12, value: 72)

        // First size (unused)
        writeInt32(in: &data, at: offset + 16, value: 0)

        // Checksum (will be calculated later)
        writeInt32(in: &data, at: offset + 20, value: 0)

        // Hash table (72 entries at offset 24)
        for i in 0..<72 {
            writeInt32(in: &data, at: offset + 24 + i * 4, value: 0)
        }

        // Bitmap flag
        writeInt32(in: &data, at: offset + 312, value: -1)

        // Bitmap pages (root + 1)
        writeInt32(in: &data, at: offset + 316, value: Int32(block + 1))

        // Days since 1978-01-01
        let days = daysSince1978()
        writeInt32(in: &data, at: offset + 420, value: Int32(days))
        writeInt32(in: &data, at: offset + 424, value: 0)  // Minutes
        writeInt32(in: &data, at: offset + 428, value: 0)  // Ticks

        // Volume name
        let nameLength = min(volumeName.count, 30)
        data[offset + 432] = UInt8(nameLength)
        for (i, char) in volumeName.prefix(30).enumerated() {
            data[offset + 433 + i] = char.asciiValue ?? 0x20
        }

        // Creation date
        writeInt32(in: &data, at: offset + 484, value: Int32(days))
        writeInt32(in: &data, at: offset + 488, value: 0)
        writeInt32(in: &data, at: offset + 492, value: 0)

        // Secondary type (ST_ROOT)
        writeInt32(in: &data, at: offset + 508, value: ST_ROOT)

        // Calculate and write checksum
        let checksum = calculateBlockChecksum(data: data, offset: offset)
        writeInt32(in: &data, at: offset + 20, value: checksum)
    }

    // MARK: - Bitmap

    private func initializeBitmap(in data: inout Data, rootBlock: Int, totalSectors: Int) {
        let bitmapBlock = rootBlock + 1
        let offset = bitmapBlock * sectorSize

        // All blocks free initially (bits set to 1)
        for i in 0..<(sectorSize / 4) {
            writeInt32(in: &data, at: offset + i * 4, value: -1)  // 0xFFFFFFFF
        }

        // Mark reserved blocks as used (root, bitmap, boot blocks)
        // Boot blocks: 0, 1
        clearBit(in: &data, bitmapOffset: offset, block: 0)
        clearBit(in: &data, bitmapOffset: offset, block: 1)
        clearBit(in: &data, bitmapOffset: offset, block: rootBlock)
        clearBit(in: &data, bitmapOffset: offset, block: bitmapBlock)
    }

    private func markBlockUsed(in data: inout Data, rootBlock: Int, block: Int) {
        let bitmapBlock = rootBlock + 1
        let offset = bitmapBlock * sectorSize
        clearBit(in: &data, bitmapOffset: offset, block: block)
    }

    private func clearBit(in data: inout Data, bitmapOffset: Int, block: Int) {
        let wordIndex = block / 32
        let bitIndex = block % 32
        let wordOffset = bitmapOffset + wordIndex * 4

        var word = readInt32(from: data, at: wordOffset)
        word &= ~(1 << bitIndex)
        writeInt32(in: &data, at: wordOffset, value: word)
    }

    // MARK: - File Header

    private func writeFileHeader(in data: inout Data, at offset: Int, fileName: String,
                                 fileSize: Int, headerBlock: Int, dataBlocks: Int, firstDataBlock: Int) {
        // Block type (T_HEADER)
        writeInt32(in: &data, at: offset, value: T_HEADER)

        // Header key (self pointer)
        writeInt32(in: &data, at: offset + 4, value: Int32(headerBlock))

        // High seq (number of data blocks)
        writeInt32(in: &data, at: offset + 8, value: Int32(min(dataBlocks, 72)))

        // Data size (unused for file header)
        writeInt32(in: &data, at: offset + 12, value: 0)

        // First data block
        writeInt32(in: &data, at: offset + 16, value: Int32(firstDataBlock))

        // Checksum placeholder
        writeInt32(in: &data, at: offset + 20, value: 0)

        // File size
        writeInt32(in: &data, at: offset + 324, value: Int32(fileSize))

        // File name
        let nameLength = min(fileName.count, 30)
        data[offset + 432] = UInt8(nameLength)
        for (i, char) in fileName.prefix(30).enumerated() {
            data[offset + 433 + i] = char.asciiValue ?? 0x20
        }

        // Parent (root block)
        writeInt32(in: &data, at: offset + 504, value: Int32(rootBlockDD))

        // Secondary type (ST_FILE = -3)
        writeInt32(in: &data, at: offset + 508, value: ST_FILE)
    }

    private func updateFileHeaderDataBlocks(in data: inout Data, at offset: Int, dataBlocks: [Int]) {
        // Data block pointers stored in reverse order at end of header
        // Offsets 24-308 (72 pointers * 4 bytes)
        for (i, block) in dataBlocks.prefix(72).enumerated() {
            writeInt32(in: &data, at: offset + 308 - i * 4, value: Int32(block))
        }

        // Calculate and write checksum
        let checksum = calculateBlockChecksum(data: data, offset: offset)
        writeInt32(in: &data, at: offset + 20, value: checksum)
    }

    // MARK: - Data Block

    private func writeDataBlock(in data: inout Data, at offset: Int, headerBlock: Int,
                                seqNum: Int, dataSize: Int, nextBlock: Int, data chunk: Data.SubSequence) {
        // Block type (T_DATA)
        writeInt32(in: &data, at: offset, value: T_DATA)

        // Header key (file header block)
        writeInt32(in: &data, at: offset + 4, value: Int32(headerBlock))

        // Sequence number
        writeInt32(in: &data, at: offset + 8, value: Int32(seqNum))

        // Data size
        writeInt32(in: &data, at: offset + 12, value: Int32(dataSize))

        // Next data block
        writeInt32(in: &data, at: offset + 16, value: Int32(nextBlock))

        // Checksum placeholder
        writeInt32(in: &data, at: offset + 20, value: 0)

        // Data (starting at offset 24)
        for (i, byte) in chunk.enumerated() {
            data[offset + 24 + i] = byte
        }

        // Calculate and write checksum
        let checksum = calculateBlockChecksum(data: data, offset: offset)
        writeInt32(in: &data, at: offset + 20, value: checksum)
    }

    // MARK: - Hash Table

    private func updateRootHashTable(in data: inout Data, at block: Int, hashTable: [Int]) {
        let offset = block * sectorSize

        for (i, entry) in hashTable.enumerated() {
            writeInt32(in: &data, at: offset + 24 + i * 4, value: Int32(entry))
        }

        // Recalculate checksum
        let checksum = calculateBlockChecksum(data: data, offset: offset)
        writeInt32(in: &data, at: offset + 20, value: checksum)
    }

    // MARK: - Helpers

    private func writeInt32(in data: inout Data, at offset: Int, value: Int32) {
        // Big-endian
        data[offset] = UInt8((value >> 24) & 0xFF)
        data[offset + 1] = UInt8((value >> 16) & 0xFF)
        data[offset + 2] = UInt8((value >> 8) & 0xFF)
        data[offset + 3] = UInt8(value & 0xFF)
    }

    private func readInt32(from data: Data, at offset: Int) -> Int32 {
        let b0 = Int32(data[offset]) << 24
        let b1 = Int32(data[offset + 1]) << 16
        let b2 = Int32(data[offset + 2]) << 8
        let b3 = Int32(data[offset + 3])
        return b0 | b1 | b2 | b3
    }

    private func calculateBlockChecksum(data: Data, offset: Int) -> Int32 {
        var sum: Int32 = 0
        for i in stride(from: 0, to: sectorSize, by: 4) {
            if i != 20 {  // Skip checksum field
                sum = sum &+ readInt32(from: data, at: offset + i)
            }
        }
        return -sum
    }

    private func amigaHash(_ name: String) -> Int {
        var hash = UInt32(name.count)
        for char in name.uppercased() {
            hash = hash &* 13
            hash = hash &+ UInt32(char.asciiValue ?? 0)
            hash &= 0x7FF
        }
        return Int(hash % 72)
    }

    private func daysSince1978() -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let epoch = calendar.date(from: DateComponents(year: 1978, month: 1, day: 1))!
        let now = Date()
        return calendar.dateComponents([.day], from: epoch, to: now).day ?? 0
    }

    private func cleanAmigaFileName(_ name: String) -> String {
        var clean = name

        // Remove path components
        if let lastSlash = clean.lastIndex(of: "/") {
            clean = String(clean[clean.index(after: lastSlash)...])
        }

        // AmigaDOS allows most characters except : and /
        clean = clean.filter { $0 != ":" && $0 != "/" }

        return String(clean.prefix(30))
    }
}
