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

    func createDiskImage(at url: URL, volumeName: String, size: DiskSize, files: [(url: URL, name: String)]) -> Bool {
        let isHD = (size == .mb1_76)
        let totalSectors = isHD ? sectorsHD : sectorsDD
        let rootBlock = isHD ? 1760 : 880

        var diskData = Data(count: totalSectors * sectorSize)

        // Initialize boot block with DOS\0 signature
        writeBootBlock(in: &diskData, rootBlock: rootBlock)

        // Initialize root block
        initializeRootBlock(in: &diskData, at: rootBlock, volumeName: volumeName, totalSectors: totalSectors)

        // Initialize bitmap blocks
        initializeBitmap(in: &diskData, rootBlock: rootBlock, totalSectors: totalSectors)

        // Write files
        // Start file blocks at block 2 (after bootblock at 0-1)
        // Avoid root block area (880-881 for DD, 1760-1761 for HD)
        var nextBlock = 2
        var hashTable = [Int](repeating: 0, count: 72)

        // Pre-generate unique Amiga filenames for all files
        let amigaFileNames = generateUniqueAmigaFileNames(for: files)

        for (fileIndex, file) in files.enumerated() {
            guard let fileData = try? Data(contentsOf: file.url) else {
                print("ADFWriter: Could not read file \(file.name)")
                continue
            }

            let fileName = amigaFileNames[fileIndex]
            let hashIndex = amigaHash(fileName) % 72

            // Skip root block and bitmap block area when finding header block
            while nextBlock == rootBlock || nextBlock == rootBlock + 1 {
                nextBlock = rootBlock + 2
            }

            // Check if disk is full
            if nextBlock >= totalSectors {
                print("ADFWriter: Disk full, cannot add file \(fileName)")
                break
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
                firstDataBlock: nextBlock,
                parentBlock: rootBlock
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

            // Update file header with data block pointers (and create extension blocks if needed)
            var extraBlocks: [Int] = []
            updateFileHeaderDataBlocks(
                in: &diskData,
                at: fileHeaderOffset,
                headerBlock: headerBlock,
                parentBlock: rootBlock,
                dataBlocks: dataBlocks,
                nextBlock: &nextBlock,
                rootBlock: rootBlock,
                totalSectors: totalSectors,
                extensionBlocks: &extraBlocks
            )

            // Add to hash table (AmigaDOS hash chain linking)
            if hashTable[hashIndex] == 0 {
                hashTable[hashIndex] = headerBlock
            } else {
                // Hash collision: link via hash_chain pointer at offset +496
                let existingBlock = hashTable[hashIndex]
                writeInt32(in: &diskData, at: fileHeaderOffset + 496, value: Int32(existingBlock))
                // Recalculate file header checksum after modifying hash_chain
                let newChecksum = calculateBlockChecksum(data: diskData, offset: fileHeaderOffset)
                writeInt32(in: &diskData, at: fileHeaderOffset + 20, value: newChecksum)
                hashTable[hashIndex] = headerBlock
            }

            // Mark blocks as used in bitmap
            markBlockUsed(in: &diskData, rootBlock: rootBlock, block: headerBlock)
            for block in dataBlocks {
                markBlockUsed(in: &diskData, rootBlock: rootBlock, block: block)
            }
            for block in extraBlocks {
                markBlockUsed(in: &diskData, rootBlock: rootBlock, block: block)
            }
        }

        // Update bitmap checksum
        updateBitmapChecksum(in: &diskData, rootBlock: rootBlock)

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

        // Offset 0-3 = checksum (set to 0 initially)
        writeInt32(in: &data, at: offset, value: 0)

        // Offset 4-511 = bitmap data, all blocks free (bits set to 1)
        for i in 1..<(sectorSize / 4) {
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
        let wordOffset = bitmapOffset + 4 + wordIndex * 4  // +4 to skip bitmap checksum at offset 0

        // Bounds check: bitmap data is 504 bytes (offset 4..507)
        guard wordOffset >= 0 && wordOffset + 4 <= data.count && wordIndex < 127 else {
            print("ADFWriter: Block \(block) out of bitmap range")
            return
        }

        var word = readInt32(from: data, at: wordOffset)
        word &= ~(1 << bitIndex)
        writeInt32(in: &data, at: wordOffset, value: word)
    }

    // MARK: - Boot Block

    private func writeBootBlock(in data: inout Data, rootBlock: Int) {
        // DOS\0 for OFS (root block is always at disk midpoint, no pointer needed)
        data[0] = 0x44  // D
        data[1] = 0x4F  // O
        data[2] = 0x53  // S
        data[3] = 0x00  // \0 = OFS

        // Boot block checksum (1024 bytes = 256 longwords, checksum at offset 4)
        // Uses carry-aware unsigned addition, then bitwise NOT
        var sum: UInt32 = 0
        for i in 0..<256 {
            if i == 1 { continue }  // skip checksum position (offset 4)
            let off = i * 4
            let word = UInt32(data[off]) << 24 | UInt32(data[off + 1]) << 16 |
                       UInt32(data[off + 2]) << 8 | UInt32(data[off + 3])
            let oldSum = sum
            sum = sum &+ word
            if sum < oldSum { sum &+= 1 }  // carry
        }
        sum = ~sum

        // Write checksum at offset 4 (big-endian)
        data[4] = UInt8((sum >> 24) & 0xFF)
        data[5] = UInt8((sum >> 16) & 0xFF)
        data[6] = UInt8((sum >> 8) & 0xFF)
        data[7] = UInt8(sum & 0xFF)
    }

    private func updateBitmapChecksum(in data: inout Data, rootBlock: Int) {
        let bitmapBlock = rootBlock + 1
        let offset = bitmapBlock * sectorSize

        // Clear checksum field
        writeInt32(in: &data, at: offset, value: 0)

        // Sum all 128 longwords, skipping the checksum at offset 0
        var sum: Int32 = 0
        for i in 1..<(sectorSize / 4) {
            sum = sum &+ readInt32(from: data, at: offset + i * 4)
        }

        // Write checksum = -sum
        writeInt32(in: &data, at: offset, value: -sum)
    }

    // MARK: - File Header

    private func writeFileHeader(in data: inout Data, at offset: Int, fileName: String,
                                 fileSize: Int, headerBlock: Int, dataBlocks: Int,
                                 firstDataBlock: Int, parentBlock: Int) {
        // Block type (T_HEADER)
        writeInt32(in: &data, at: offset, value: T_HEADER)

        // Header key (self pointer)
        writeInt32(in: &data, at: offset + 4, value: Int32(headerBlock))

        // High seq (number of data block pointers stored in this header, max 72)
        writeInt32(in: &data, at: offset + 8, value: Int32(min(dataBlocks, 72)))

        // Data size (unused for file header)
        writeInt32(in: &data, at: offset + 12, value: 0)

        // First data block
        writeInt32(in: &data, at: offset + 16, value: Int32(firstDataBlock))

        // Checksum placeholder
        writeInt32(in: &data, at: offset + 20, value: 0)

        // File size (byte_size at offset 324)
        writeInt32(in: &data, at: offset + 324, value: Int32(fileSize))

        // File date (days, minutes, ticks since 1978-01-01)
        let days = daysSince1978()
        writeInt32(in: &data, at: offset + 420, value: Int32(days))
        writeInt32(in: &data, at: offset + 424, value: 0)  // Minutes
        writeInt32(in: &data, at: offset + 428, value: 0)  // Ticks

        // File name (BCPL string: length byte + chars)
        let nameLength = min(fileName.count, 30)
        data[offset + 432] = UInt8(nameLength)
        for (i, char) in fileName.prefix(30).enumerated() {
            data[offset + 433 + i] = char.asciiValue ?? 0x20
        }

        // hash_chain at offset 496 (0 = no chain)
        writeInt32(in: &data, at: offset + 496, value: 0)

        // Parent directory block at offset 500
        writeInt32(in: &data, at: offset + 500, value: Int32(parentBlock))

        // Extension block pointer at offset 504 (0 = none, set later if needed)
        writeInt32(in: &data, at: offset + 504, value: 0)

        // Secondary type (ST_FILE = -3)
        writeInt32(in: &data, at: offset + 508, value: ST_FILE)
    }

    private func updateFileHeaderDataBlocks(in data: inout Data, at offset: Int,
                                            headerBlock: Int, parentBlock: Int,
                                            dataBlocks: [Int], nextBlock: inout Int,
                                            rootBlock: Int, totalSectors: Int,
                                            extensionBlocks: inout [Int]) {
        // First 72 data block pointers go into the file header (reverse order)
        let firstChunk = Array(dataBlocks.prefix(72))
        for (i, block) in firstChunk.enumerated() {
            writeInt32(in: &data, at: offset + 308 - i * 4, value: Int32(block))
        }

        // Calculate and write checksum for file header
        let checksum = calculateBlockChecksum(data: data, offset: offset)
        writeInt32(in: &data, at: offset + 20, value: checksum)

        // If more than 72 data blocks, create extension blocks (T_LIST)
        if dataBlocks.count > 72 {
            var remainingBlocks = Array(dataBlocks.dropFirst(72))
            var prevBlockOffset = offset  // Start with file header

            while !remainingBlocks.isEmpty {
                // Allocate an extension block
                while nextBlock == rootBlock || nextBlock == rootBlock + 1 {
                    nextBlock = rootBlock + 2
                }
                guard nextBlock < totalSectors else {
                    print("ADFWriter: Disk full, cannot create extension block")
                    break
                }

                let extBlock = nextBlock
                nextBlock += 1
                extensionBlocks.append(extBlock)

                // Take next chunk of up to 72 data block pointers
                let chunk = Array(remainingBlocks.prefix(72))
                remainingBlocks = Array(remainingBlocks.dropFirst(72))

                // Write the extension block
                let extOffset = extBlock * sectorSize
                writeExtensionBlock(
                    in: &data,
                    at: extOffset,
                    headerBlock: headerBlock,
                    parentBlock: headerBlock,
                    dataBlockPtrs: chunk
                )

                // Link previous block (file header or prior extension) to this extension block
                // Extension pointer is at offset +504
                writeInt32(in: &data, at: prevBlockOffset + 504, value: Int32(extBlock))

                // Recalculate checksum of the previous block since we modified it
                let prevChecksum = calculateBlockChecksum(data: data, offset: prevBlockOffset)
                writeInt32(in: &data, at: prevBlockOffset + 20, value: prevChecksum)

                prevBlockOffset = extOffset
            }
        }
    }

    // MARK: - Extension Block (T_LIST)

    private func writeExtensionBlock(in data: inout Data, at offset: Int,
                                     headerBlock: Int, parentBlock: Int,
                                     dataBlockPtrs: [Int]) {
        // Block type (T_LIST = 16)
        writeInt32(in: &data, at: offset, value: T_LIST)

        // Header key (points back to file header)
        writeInt32(in: &data, at: offset + 4, value: Int32(headerBlock))

        // High seq (number of data block pointers in this block)
        writeInt32(in: &data, at: offset + 8, value: Int32(dataBlockPtrs.count))

        // Checksum placeholder
        writeInt32(in: &data, at: offset + 20, value: 0)

        // Data block pointers (reverse order, same layout as file header: offsets 24-308)
        for (i, block) in dataBlockPtrs.enumerated() {
            writeInt32(in: &data, at: offset + 308 - i * 4, value: Int32(block))
        }

        // Parent (file header block) at offset 500
        writeInt32(in: &data, at: offset + 500, value: Int32(parentBlock))

        // Extension (next extension block, 0 = none) at offset 504
        writeInt32(in: &data, at: offset + 504, value: 0)

        // Secondary type (ST_FILE = -3)
        writeInt32(in: &data, at: offset + 508, value: ST_FILE)

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
        // Bounds check
        guard offset >= 0 && offset + 4 <= data.count else {
            print("ADFWriter: writeInt32 out of bounds at offset \(offset), data size \(data.count)")
            return
        }
        // Big-endian
        data[offset] = UInt8((value >> 24) & 0xFF)
        data[offset + 1] = UInt8((value >> 16) & 0xFF)
        data[offset + 2] = UInt8((value >> 8) & 0xFF)
        data[offset + 3] = UInt8(value & 0xFF)
    }

    private func readInt32(from data: Data, at offset: Int) -> Int32 {
        // Bounds check
        guard offset >= 0 && offset + 4 <= data.count else {
            print("ADFWriter: readInt32 out of bounds at offset \(offset), data size \(data.count)")
            return 0
        }
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

    /// Generate unique Amiga-safe filenames for all files, preserving extensions
    private func generateUniqueAmigaFileNames(for files: [(url: URL, name: String)]) -> [String] {
        var result: [String] = []
        var usedNames: [String: Int] = [:]  // uppercased name -> count

        for file in files {
            let ext = file.url.pathExtension  // e.g. "iff"

            // Clean the base name (remove : and /)
            var baseName = file.name
            if let lastSlash = baseName.lastIndex(of: "/") {
                baseName = String(baseName[baseName.index(after: lastSlash)...])
            }
            baseName = baseName.filter { $0 != ":" && $0 != "/" }

            // Truncate base name to leave room for extension (e.g. ".iff" = 4 chars)
            let extPart = ext.isEmpty ? "" : ".\(ext)"
            let maxBase = 30 - extPart.count
            let truncatedBase = String(baseName.prefix(max(maxBase, 1)))
            var fullName = "\(truncatedBase)\(extPart)"

            // Ensure uniqueness (AmigaDOS is case-insensitive)
            let key = fullName.uppercased()
            if let count = usedNames[key] {
                usedNames[key] = count + 1
                // Shorten base to make room for sequence suffix "_2", "_3", etc.
                let suffix = "_\(count + 1)"
                let shorterBase = String(truncatedBase.prefix(max(maxBase - suffix.count, 1)))
                fullName = "\(shorterBase)\(suffix)\(extPart)"
            } else {
                usedNames[key] = 1
            }

            result.append(String(fullName.prefix(30)))
        }
        return result
    }
}
