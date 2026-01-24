//
//  ProDOSWriter.swift
//  BitPast
//
//  Native ProDOS disk image creation
//  Adapted from ProBrowse project
//

import Foundation

class ProDOSWriter {
    static let shared = ProDOSWriter()

    private let BLOCK_SIZE = 512
    private let VOLUME_DIR_BLOCK = 2
    private let ENTRIES_PER_BLOCK = 13  // 0x0D
    private let ENTRY_LENGTH = 39       // 0x27

    private init() {}

    // MARK: - Sanitize Filename

    /// Sanitizes a filename for ProDOS: removes invalid chars, max 15 chars, uppercase
    private func sanitizeProDOSFilename(_ filename: String) -> String {
        var name = filename.uppercased()

        // ProDOS allows: A-Z, 0-9, and period (.)
        let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "."))
        name = name.filter { char in
            guard let scalar = char.unicodeScalars.first else { return false }
            return validChars.contains(scalar)
        }

        // Max 15 characters
        if name.count > 15 {
            name = String(name.prefix(15))
        }

        // ProDOS requirement: First character must be a letter
        if let firstChar = name.first, !firstChar.isLetter {
            name = "A" + name
            if name.count > 15 {
                name = String(name.prefix(15))
            }
        }

        if name.isEmpty {
            name = "UNNAMED"
        }

        return name
    }

    // MARK: - Block Read/Write

    private func readBlock(_ diskData: Data, blockIndex: Int) -> Data? {
        let offset = blockIndex * BLOCK_SIZE
        guard offset + BLOCK_SIZE <= diskData.count else { return nil }
        return diskData.subdata(in: offset..<(offset + BLOCK_SIZE))
    }

    private func writeBlock(_ diskData: NSMutableData, blockIndex: Int, blockData: Data) {
        guard blockData.count == BLOCK_SIZE else { return }
        let bytes = diskData.mutableBytes.assumingMemoryBound(to: UInt8.self)
        let offset = blockIndex * BLOCK_SIZE
        blockData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            memcpy(bytes + offset, ptr.baseAddress!, BLOCK_SIZE)
        }
    }

    // MARK: - Create Disk Image

    func createDiskImage(at path: URL, volumeName: String, totalBlocks: Int, completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let sanitizedVolume = self.sanitizeProDOSFilename(volumeName)

                print("Creating ProDOS disk image:")
                print("   Path: \(path.path)")
                print("   Volume: \(sanitizedVolume)")
                print("   Blocks: \(totalBlocks)")

                let diskData = NSMutableData(length: totalBlocks * self.BLOCK_SIZE)!

                self.createBootBlocks(diskData)
                self.createVolumeDirectory(diskData, volumeName: sanitizedVolume, totalBlocks: totalBlocks)
                self.createBitmap(diskData, totalBlocks: totalBlocks)

                try diskData.write(to: path, options: .atomic)

                print("   Disk image created successfully!")

                DispatchQueue.main.async {
                    completion(true, "Disk image created successfully")
                }

            } catch {
                print("   Error: \(error)")
                DispatchQueue.main.async {
                    completion(false, "Error creating disk: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Add File

    func addFile(diskImagePath: URL, fileName: String, fileData: Data, fileType: UInt8, auxType: UInt16, completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let sanitizedName = self.sanitizeProDOSFilename(fileName)

                guard let diskData = NSMutableData(contentsOf: diskImagePath) else {
                    DispatchQueue.main.async {
                        completion(false, "Could not read disk image")
                    }
                    return
                }

                // Check if filename already exists and rename if needed
                var finalName = sanitizedName
                var counter = 1
                while self.fileExists(diskData, fileName: finalName) {
                    let baseName = String(sanitizedName.prefix(13))
                    finalName = "\(baseName).\(counter)"
                    counter += 1
                    if counter > 99 {
                        DispatchQueue.main.async {
                            completion(false, "Too many files with same name")
                        }
                        return
                    }
                }

                print("Adding file to ProDOS image:")
                print("   File: \(finalName)")
                print("   Size: \(fileData.count) bytes")
                print("   Type: $\(String(format: "%02X", fileType))")

                // Find free directory entry
                guard let (dirBlock, entryOffset) = self.findFreeDirectoryEntry(diskData) else {
                    DispatchQueue.main.async {
                        completion(false, "No free directory entries")
                    }
                    return
                }

                // Allocate blocks for file data
                let blocksNeeded = max(1, (fileData.count + self.BLOCK_SIZE - 1) / self.BLOCK_SIZE)
                guard let dataBlocks = self.allocateBlocks(diskData, count: blocksNeeded) else {
                    DispatchQueue.main.async {
                        completion(false, "Not enough free blocks (need \(blocksNeeded))")
                    }
                    return
                }

                // Write file data to allocated blocks
                self.writeFileData(diskData, fileData: fileData, blocks: dataBlocks)

                // Handle index blocks for larger files
                var keyBlock = 0
                var totalBlocks = dataBlocks.count

                if dataBlocks.isEmpty {
                    keyBlock = 0
                    totalBlocks = 0
                } else if dataBlocks.count > 256 {
                    // Tree file
                    let numIndexBlocks = (dataBlocks.count + 255) / 256
                    guard let indexBlocks = self.allocateBlocks(diskData, count: numIndexBlocks),
                          let masterIndexBlocks = self.allocateBlocks(diskData, count: 1) else {
                        DispatchQueue.main.async {
                            completion(false, "Could not allocate index blocks")
                        }
                        return
                    }

                    keyBlock = masterIndexBlocks[0]
                    totalBlocks += numIndexBlocks + 1

                    for i in 0..<numIndexBlocks {
                        let startIdx = i * 256
                        let endIdx = min(startIdx + 256, dataBlocks.count)
                        let blocksForThisIndex = Array(dataBlocks[startIdx..<endIdx])
                        self.createIndexBlock(diskData, indexBlock: indexBlocks[i], dataBlocks: blocksForThisIndex)
                    }

                    self.createMasterIndexBlock(diskData, masterIndexBlock: keyBlock, indexBlocks: indexBlocks)

                } else if dataBlocks.count > 1 {
                    // Sapling file
                    guard let indexBlocks = self.allocateBlocks(diskData, count: 1) else {
                        DispatchQueue.main.async {
                            completion(false, "Could not allocate index block")
                        }
                        return
                    }
                    keyBlock = indexBlocks[0]
                    totalBlocks += 1
                    self.createIndexBlock(diskData, indexBlock: keyBlock, dataBlocks: dataBlocks)
                } else {
                    // Seedling file
                    keyBlock = dataBlocks[0]
                }

                // Create directory entry
                self.createDirectoryEntry(diskData, dirBlock: dirBlock, entryOffset: entryOffset,
                                         fileName: finalName, fileType: fileType, auxType: auxType,
                                         keyBlock: keyBlock, blockCount: totalBlocks, fileSize: fileData.count)

                // Update file count
                self.incrementFileCount(diskData)

                // Write back to disk
                try diskData.write(to: diskImagePath, options: .atomic)

                print("   File added successfully!")

                DispatchQueue.main.async {
                    completion(true, "File added successfully")
                }

            } catch {
                print("   Error: \(error)")
                DispatchQueue.main.async {
                    completion(false, "Error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Rename File

    func renameFile(diskImagePath: URL, oldName: String, newName: String, completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let diskData = NSMutableData(contentsOf: diskImagePath) else {
                    DispatchQueue.main.async {
                        completion(false, "Could not read disk image")
                    }
                    return
                }

                guard let (blockNum, entryOffset) = self.findFileEntry(Data(referencing: diskData), fileName: oldName) else {
                    DispatchQueue.main.async {
                        completion(false, "File '\(oldName)' not found")
                    }
                    return
                }

                let sanitizedName = self.sanitizeProDOSFilename(newName)

                // Check if new name already exists
                if self.fileExists(diskData, fileName: sanitizedName) {
                    DispatchQueue.main.async {
                        completion(false, "A file named '\(sanitizedName)' already exists")
                    }
                    return
                }

                guard var blockData = self.readBlock(Data(referencing: diskData), blockIndex: blockNum) else {
                    DispatchQueue.main.async {
                        completion(false, "Could not read directory block")
                    }
                    return
                }

                let storageType = blockData[entryOffset] >> 4
                let nameLen = min(sanitizedName.count, 15)
                blockData[entryOffset] = (storageType << 4) | UInt8(nameLen)

                // Clear old name and write new
                for i in 0..<15 {
                    blockData[entryOffset + 1 + i] = 0x00
                }
                for (i, char) in sanitizedName.uppercased().prefix(15).enumerated() {
                    blockData[entryOffset + 1 + i] = UInt8(char.asciiValue ?? 0x20)
                }

                self.writeBlock(diskData, blockIndex: blockNum, blockData: blockData)
                try diskData.write(to: diskImagePath, options: .atomic)

                DispatchQueue.main.async {
                    completion(true, "File renamed successfully")
                }

            } catch {
                DispatchQueue.main.async {
                    completion(false, "Error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func fileExists(_ diskData: NSMutableData, fileName: String) -> Bool {
        return findFileEntry(Data(referencing: diskData), fileName: fileName) != nil
    }

    private func findFileEntry(_ diskData: Data, fileName: String) -> (block: Int, entryOffset: Int)? {
        let searchName = fileName.uppercased()
        var currentBlock = VOLUME_DIR_BLOCK
        var entryIndex = 1  // Skip header

        while currentBlock != 0 {
            guard let blockData = readBlock(diskData, blockIndex: currentBlock) else { break }

            while entryIndex < ENTRIES_PER_BLOCK {
                let entryOffset = 4 + (entryIndex * ENTRY_LENGTH)
                let storageType = blockData[entryOffset] >> 4

                if storageType != 0 {
                    let nameLen = Int(blockData[entryOffset] & 0x0F)
                    var entryName = ""
                    for i in 0..<nameLen {
                        let char = blockData[entryOffset + 1 + i] & 0x7F
                        entryName.append(Character(UnicodeScalar(char)))
                    }

                    if entryName == searchName {
                        return (currentBlock, entryOffset)
                    }
                }
                entryIndex += 1
            }

            let nextBlockLo = Int(blockData[2])
            let nextBlockHi = Int(blockData[3])
            currentBlock = nextBlockLo | (nextBlockHi << 8)
            entryIndex = 0
        }

        return nil
    }

    private func findFreeDirectoryEntry(_ diskData: NSMutableData) -> (block: Int, entryOffset: Int)? {
        var currentBlock = VOLUME_DIR_BLOCK
        var entryIndex = 1

        while currentBlock != 0 {
            guard let blockData = readBlock(Data(referencing: diskData), blockIndex: currentBlock) else { break }

            while entryIndex < ENTRIES_PER_BLOCK {
                let entryOffset = 4 + (entryIndex * ENTRY_LENGTH)
                let storageType = blockData[entryOffset] >> 4

                if storageType == 0 {
                    return (currentBlock, entryOffset)
                }
                entryIndex += 1
            }

            let nextBlockLo = Int(blockData[2])
            let nextBlockHi = Int(blockData[3])
            currentBlock = nextBlockLo | (nextBlockHi << 8)
            entryIndex = 0
        }

        return nil
    }

    private func allocateBlocks(_ diskData: NSMutableData, count: Int) -> [Int]? {
        guard count > 0 else { return [] }

        var allocatedBlocks: [Int] = []

        guard let volBlock = readBlock(Data(referencing: diskData), blockIndex: VOLUME_DIR_BLOCK) else {
            return nil
        }

        let totalBlocksLo = Int(volBlock[0x29])
        let totalBlocksHi = Int(volBlock[0x2A])
        let totalBlocks = totalBlocksLo | (totalBlocksHi << 8)

        let startBlock = 24
        let bitmapStartBlock = 6

        for block in startBlock..<totalBlocks {
            if allocatedBlocks.count >= count { break }

            let byteIndex = block / 8
            let bitPosition = 7 - (block % 8)
            let bitmapBlock = bitmapStartBlock + (byteIndex / BLOCK_SIZE)
            let bitmapByteOffset = byteIndex % BLOCK_SIZE

            guard let bitmapBlockData = readBlock(Data(referencing: diskData), blockIndex: bitmapBlock) else {
                continue
            }

            let bitmapByte = bitmapBlockData[bitmapByteOffset]
            let isFree = (bitmapByte & (1 << bitPosition)) != 0

            if isFree {
                allocatedBlocks.append(block)

                var mutableBitmapBlock = bitmapBlockData
                mutableBitmapBlock[bitmapByteOffset] = bitmapByte & ~(1 << bitPosition)
                writeBlock(diskData, blockIndex: bitmapBlock, blockData: mutableBitmapBlock)
            }
        }

        return allocatedBlocks.count >= count ? allocatedBlocks : nil
    }

    private func writeFileData(_ diskData: NSMutableData, fileData: Data, blocks: [Int]) {
        var dataPosition = 0

        for block in blocks {
            let bytesToWrite = min(BLOCK_SIZE, fileData.count - dataPosition)
            var blockData = Data(repeating: 0, count: BLOCK_SIZE)
            if bytesToWrite > 0 {
                blockData.replaceSubrange(0..<bytesToWrite, with: fileData.subdata(in: dataPosition..<(dataPosition + bytesToWrite)))
            }
            writeBlock(diskData, blockIndex: block, blockData: blockData)
            dataPosition += bytesToWrite
        }
    }

    private func createIndexBlock(_ diskData: NSMutableData, indexBlock: Int, dataBlocks: [Int]) {
        var blockData = Data(repeating: 0, count: BLOCK_SIZE)

        for i in 0..<min(dataBlocks.count, 256) {
            let block = dataBlocks[i]
            blockData[i] = UInt8(block & 0xFF)
            blockData[256 + i] = UInt8((block >> 8) & 0xFF)
        }

        writeBlock(diskData, blockIndex: indexBlock, blockData: blockData)
    }

    private func createMasterIndexBlock(_ diskData: NSMutableData, masterIndexBlock: Int, indexBlocks: [Int]) {
        var blockData = Data(repeating: 0, count: BLOCK_SIZE)

        for i in 0..<min(indexBlocks.count, 256) {
            let block = indexBlocks[i]
            blockData[i] = UInt8(block & 0xFF)
            blockData[256 + i] = UInt8((block >> 8) & 0xFF)
        }

        writeBlock(diskData, blockIndex: masterIndexBlock, blockData: blockData)
    }

    private func createDirectoryEntry(_ diskData: NSMutableData, dirBlock: Int, entryOffset: Int,
                                     fileName: String, fileType: UInt8, auxType: UInt16,
                                     keyBlock: Int, blockCount: Int, fileSize: Int) {
        guard var blockData = readBlock(Data(referencing: diskData), blockIndex: dirBlock) else { return }

        let storageType: UInt8
        if blockCount == 0 || blockCount == 1 {
            storageType = 1  // Seedling
        } else if blockCount <= 256 {
            storageType = 2  // Sapling
        } else {
            storageType = 3  // Tree
        }

        var nameBytes = [UInt8](repeating: 0x00, count: 15)
        let nameData = fileName.uppercased().data(using: .ascii) ?? Data()
        let nameLen = min(nameData.count, 15)
        for i in 0..<nameLen {
            nameBytes[i] = nameData[i]
        }

        var entry = [UInt8](repeating: 0, count: ENTRY_LENGTH)
        entry[0] = (storageType << 4) | UInt8(nameLen)

        for i in 0..<15 {
            entry[1 + i] = nameBytes[i]
        }

        entry[0x10] = fileType
        entry[0x11] = UInt8(keyBlock & 0xFF)
        entry[0x12] = UInt8((keyBlock >> 8) & 0xFF)
        entry[0x13] = UInt8(blockCount & 0xFF)
        entry[0x14] = UInt8((blockCount >> 8) & 0xFF)
        entry[0x15] = UInt8(fileSize & 0xFF)
        entry[0x16] = UInt8((fileSize >> 8) & 0xFF)
        entry[0x17] = UInt8((fileSize >> 16) & 0xFF)

        // Creation date/time
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)

        let year = (components.year ?? 2024) - 1900
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        let dateWord = (year << 9) | (month << 5) | day
        entry[0x18] = UInt8(dateWord & 0xFF)
        entry[0x19] = UInt8((dateWord >> 8) & 0xFF)
        entry[0x1A] = UInt8(hour & 0x1F)
        entry[0x1B] = UInt8(minute & 0x3F)

        entry[0x1C] = 0x00
        entry[0x1D] = 0x00
        entry[0x1E] = 0xE3  // Access

        entry[0x1F] = UInt8(auxType & 0xFF)
        entry[0x20] = UInt8((auxType >> 8) & 0xFF)

        // Last mod = creation
        entry[0x21] = entry[0x18]
        entry[0x22] = entry[0x19]
        entry[0x23] = entry[0x1A]
        entry[0x24] = entry[0x1B]

        entry[0x25] = 0x00
        entry[0x26] = 0x00

        for i in 0..<ENTRY_LENGTH {
            blockData[entryOffset + i] = entry[i]
        }

        writeBlock(diskData, blockIndex: dirBlock, blockData: blockData)
    }

    private func incrementFileCount(_ diskData: NSMutableData) {
        guard var blockData = readBlock(Data(referencing: diskData), blockIndex: VOLUME_DIR_BLOCK) else { return }

        let fileCountOffset = 0x25
        let currentCountLo = Int(blockData[fileCountOffset])
        let currentCountHi = Int(blockData[fileCountOffset + 1])
        var fileCount = currentCountLo | (currentCountHi << 8)

        fileCount += 1

        blockData[fileCountOffset] = UInt8(fileCount & 0xFF)
        blockData[fileCountOffset + 1] = UInt8((fileCount >> 8) & 0xFF)

        writeBlock(diskData, blockIndex: VOLUME_DIR_BLOCK, blockData: blockData)
    }

    // MARK: - Boot Blocks

    private func createBootBlocks(_ diskData: NSMutableData) {
        let bytes = diskData.mutableBytes.assumingMemoryBound(to: UInt8.self)

        // Standard ProDOS boot loader
        let bootCode: [UInt8] = [
            0x01, 0x38, 0xB0, 0x03, 0x4C, 0x32, 0xA1, 0x86, 0x43, 0xC9, 0x03, 0x08, 0x8A, 0x29, 0x70, 0x4A,
            0x4A, 0x4A, 0x4A, 0x09, 0xC0, 0x85, 0x49, 0xA0, 0xFF, 0x84, 0x48, 0x28, 0xC8, 0xB1, 0x48, 0xD0,
            0x3A, 0xB0, 0x0E, 0xA9, 0x03, 0x8D, 0x00, 0x08, 0xE6, 0x3D, 0xA5, 0x49, 0x48, 0xA9, 0x5B, 0x48,
            0x60, 0x85, 0x40, 0x85, 0x48, 0xA0, 0x63, 0xB1, 0x48, 0x99, 0x94, 0x09, 0xC8, 0xC0, 0xEB, 0xD0,
            0xF6, 0xA2, 0x06, 0xBC, 0x1D, 0x09, 0xBD, 0x24, 0x09, 0x99, 0xF2, 0x09, 0xBD, 0x2B, 0x09, 0x9D,
            0x7F, 0x0A, 0xCA, 0x10, 0xEE, 0xA9, 0x09, 0x85, 0x49, 0xA9, 0x86, 0xA0, 0x00, 0xC9, 0xF9, 0xB0,
            0x2F, 0x85, 0x48, 0x84, 0x60, 0x84, 0x4A, 0x84, 0x4C, 0x84, 0x4E, 0x84, 0x47, 0xC8, 0x84, 0x42,
            0xC8, 0x84, 0x46, 0xA9, 0x0C, 0x85, 0x61, 0x85, 0x4B, 0x20, 0x12, 0x09, 0xB0, 0x68, 0xE6, 0x61
        ]

        for (i, byte) in bootCode.enumerated() {
            bytes[i] = byte
        }
    }

    // MARK: - Volume Directory

    private func createVolumeDirectory(_ diskData: NSMutableData, volumeName: String, totalBlocks: Int) {
        let bytes = diskData.mutableBytes.assumingMemoryBound(to: UInt8.self)
        let blockOffset = VOLUME_DIR_BLOCK * BLOCK_SIZE

        memset(bytes + blockOffset, 0, BLOCK_SIZE)

        // Previous block
        bytes[blockOffset + 0] = 0x00
        bytes[blockOffset + 1] = 0x00

        // Next block (block 3)
        bytes[blockOffset + 2] = 0x03
        bytes[blockOffset + 3] = 0x00

        // Storage type (0xF = volume header) + name length
        let nameLength = min(volumeName.count, 15)
        bytes[blockOffset + 4] = UInt8(0xF0 | nameLength)

        // Volume name
        for i in 0..<nameLength {
            let index = volumeName.index(volumeName.startIndex, offsetBy: i)
            bytes[blockOffset + 5 + i] = UInt8(volumeName[index].asciiValue ?? 0x20)
        }

        // Creation date/time
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)

        if let year = components.year, let month = components.month, let day = components.day {
            let proDOSYear = year - 1900
            let dateWord = UInt16((proDOSYear << 9) | (month << 5) | day)
            bytes[blockOffset + 0x1C] = UInt8(dateWord & 0xFF)
            bytes[blockOffset + 0x1D] = UInt8((dateWord >> 8) & 0xFF)
        }

        if let hour = components.hour, let minute = components.minute {
            let timeWord = UInt16((minute << 8) | hour)
            bytes[blockOffset + 0x1E] = UInt8(timeWord & 0xFF)
            bytes[blockOffset + 0x1F] = UInt8((timeWord >> 8) & 0xFF)
        }

        bytes[blockOffset + 0x20] = 0x00  // Version
        bytes[blockOffset + 0x21] = 0x00  // Min version
        bytes[blockOffset + 0x22] = 0xC3  // Access
        bytes[blockOffset + 0x23] = 0x27  // Entry length
        bytes[blockOffset + 0x24] = 0x0D  // Entries per block
        bytes[blockOffset + 0x25] = 0x00  // File count lo
        bytes[blockOffset + 0x26] = 0x00  // File count hi
        bytes[blockOffset + 0x27] = 0x06  // Bitmap pointer lo
        bytes[blockOffset + 0x28] = 0x00  // Bitmap pointer hi
        bytes[blockOffset + 0x29] = UInt8(totalBlocks & 0xFF)
        bytes[blockOffset + 0x2A] = UInt8((totalBlocks >> 8) & 0xFF)

        // Create additional directory blocks (3, 4, 5)
        for additionalBlock in 3...5 {
            let addBlockOffset = additionalBlock * BLOCK_SIZE
            memset(bytes + addBlockOffset, 0, BLOCK_SIZE)

            bytes[addBlockOffset + 0] = UInt8((additionalBlock - 1) & 0xFF)
            bytes[addBlockOffset + 1] = 0x00

            if additionalBlock < 5 {
                bytes[addBlockOffset + 2] = UInt8((additionalBlock + 1) & 0xFF)
                bytes[addBlockOffset + 3] = 0x00
            }
        }
    }

    // MARK: - Bitmap

    private func createBitmap(_ diskData: NSMutableData, totalBlocks: Int) {
        let bytes = diskData.mutableBytes.assumingMemoryBound(to: UInt8.self)
        let bitmapStartBlock = 6
        let bitmapBytes = (totalBlocks + 7) / 8
        let bitmapBlocks = (bitmapBytes + BLOCK_SIZE - 1) / BLOCK_SIZE

        let bitmapOffset = bitmapStartBlock * BLOCK_SIZE
        memset(bytes + bitmapOffset, 0xFF, bitmapBytes)

        // Mark system blocks as used
        let systemBlocks = 6 + bitmapBlocks
        for block in 0..<systemBlocks {
            let byteIndex = block / 8
            let bitPosition = 7 - (block % 8)
            bytes[bitmapOffset + byteIndex] &= ~(1 << bitPosition)
        }
    }
}
