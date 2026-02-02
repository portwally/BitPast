import Foundation

// MARK: - CoCo Disk Writer
// TRS-80 Color Computer disk image writer supporting RSDOS format (.DSK)

class CoCoDiskWriter {
    static let shared = CoCoDiskWriter()
    private init() {}

    // MARK: - RSDOS Format Constants

    private let sectorSize = 256
    private let sectorsPerTrack = 18
    private let tracksPerSide = 35
    private let directoryTrack = 17
    private let granulesPerTrack = 2
    private let sectorsPerGranule = 9
    private let maxDirectoryEntries = 72  // 9 sectors × 8 entries per sector

    // MARK: - Public Interface

    /// Creates a disk image and returns the number of files written (0 if failed)
    func createDiskImage(at url: URL, volumeName: String, size: DiskSize, files: [(url: URL, name: String)]) -> Int {
        let sides = size == .kb360 ? 2 : 1  // Double-sided for 360KB
        let totalTracks = tracksPerSide * sides
        let totalSectors = totalTracks * sectorsPerTrack
        let totalBytes = totalSectors * sectorSize
        var filesWritten = 0

        var diskData = Data(count: totalBytes)

        // Initialize disk with 0xFF (unformatted)
        for i in 0..<totalBytes {
            diskData[i] = 0xFF
        }

        // Initialize directory track
        initializeDirectory(in: &diskData, sides: sides)

        // Initialize Granule Allocation Table (GAT)
        initializeGAT(in: &diskData, totalTracks: totalTracks, sides: sides)

        // Write files
        var dirEntryIndex = 0
        var nextGranule = 0  // Start from granule 0 (track 0)

        for file in files {
            guard let fileData = try? Data(contentsOf: file.url) else {
                print("CoCoDiskWriter: Could not read file \(file.name)")
                continue
            }

            if dirEntryIndex >= maxDirectoryEntries {
                print("CoCoDiskWriter: Maximum file count reached")
                break
            }

            // Split filename into name and extension
            let ext = file.url.pathExtension
            let (fileName, fileExt) = splitCoCoFileName("\(file.name).\(ext)")

            // Calculate number of granules needed
            let granuleBytes = sectorsPerGranule * sectorSize  // 2304 bytes per granule
            let granulesNeeded = (fileData.count + granuleBytes - 1) / granuleBytes

            // Find available granules
            var allocatedGranules: [Int] = []
            var searchGranule = nextGranule
            let maxGranules = totalTracks * granulesPerTrack

            while allocatedGranules.count < granulesNeeded && searchGranule < maxGranules {
                // Skip directory track granules
                let trackForGranule = searchGranule / granulesPerTrack
                if trackForGranule == directoryTrack {
                    searchGranule += granulesPerTrack
                    continue
                }

                // Check if granule is free in GAT
                if isGranuleFree(in: diskData, granule: searchGranule, sides: sides) {
                    allocatedGranules.append(searchGranule)
                }
                searchGranule += 1
            }

            if allocatedGranules.count < granulesNeeded {
                print("CoCoDiskWriter: Disk full")
                break
            }

            // Write file data to allocated granules
            var remaining = fileData
            var lastSectorUsed = 0
            for (i, granule) in allocatedGranules.enumerated() {
                let chunk = remaining.prefix(granuleBytes)
                remaining = remaining.dropFirst(granuleBytes)

                writeGranule(in: &diskData, granule: granule, data: chunk, sides: sides)

                // Calculate sectors used in last granule
                if i == allocatedGranules.count - 1 {
                    lastSectorUsed = (chunk.count + sectorSize - 1) / sectorSize
                    if lastSectorUsed == 0 { lastSectorUsed = 1 }
                }
            }

            // Update GAT with allocation chain
            updateGAT(in: &diskData, granules: allocatedGranules, lastSectorCount: lastSectorUsed, sides: sides)

            // Add directory entry
            addDirectoryEntry(
                in: &diskData,
                entryIndex: dirEntryIndex,
                fileName: fileName,
                fileExt: fileExt,
                firstGranule: allocatedGranules.first ?? 0,
                fileType: 0x02,  // Binary file
                asciiFlag: 0x00,  // Binary
                sides: sides
            )

            dirEntryIndex += 1
            filesWritten += 1
            nextGranule = searchGranule
        }

        // Write to file
        do {
            try diskData.write(to: url)
            print("CoCoDiskWriter: Created DSK at \(url.path) with \(filesWritten) files")
            return filesWritten
        } catch {
            print("CoCoDiskWriter: Failed to write DSK: \(error)")
            return 0
        }
    }

    // MARK: - Directory Initialization

    private func initializeDirectory(in data: inout Data, sides: Int) {
        // Directory is on track 17, sectors 3-11 (after GAT in sectors 1-2)
        // Each sector holds 8 directory entries of 32 bytes each
        let dirOffset = sectorOffset(track: directoryTrack, sector: 2, side: 0)  // Start at sector 3 (0-indexed = 2)

        // Initialize directory entries as empty (0xFF)
        for i in 0..<(9 * sectorSize) {  // 9 sectors of directory
            data[dirOffset + i] = 0xFF
        }
    }

    // MARK: - GAT (Granule Allocation Table)

    private func initializeGAT(in data: inout Data, totalTracks: Int, sides: Int) {
        // GAT is in sector 2 of track 17 (0-indexed = sector 1)
        let gatOffset = sectorOffset(track: directoryTrack, sector: 1, side: 0)

        // Initialize all granules as free (0xFF)
        for i in 0..<sectorSize {
            data[gatOffset + i] = 0xFF
        }

        // Mark directory track granules as used (0xFC = system use)
        let dirGranuleStart = directoryTrack * granulesPerTrack
        for g in 0..<granulesPerTrack {
            data[gatOffset + dirGranuleStart + g] = 0xFC
        }

        // Mark any non-existent granules as unavailable
        let maxGranules = totalTracks * granulesPerTrack
        for g in maxGranules..<256 {
            if gatOffset + g < data.count {
                data[gatOffset + g] = 0xFC  // Mark as unavailable
            }
        }
    }

    private func isGranuleFree(in data: Data, granule: Int, sides: Int) -> Bool {
        let gatOffset = sectorOffset(track: directoryTrack, sector: 1, side: 0)
        return data[gatOffset + granule] == 0xFF
    }

    private func updateGAT(in data: inout Data, granules: [Int], lastSectorCount: Int, sides: Int) {
        let gatOffset = sectorOffset(track: directoryTrack, sector: 1, side: 0)

        for (i, granule) in granules.enumerated() {
            if i < granules.count - 1 {
                // Point to next granule
                data[gatOffset + granule] = UInt8(granules[i + 1])
            } else {
                // Last granule: encode sector count (0xC1-0xC9)
                // 0xC1 = 1 sector, 0xC2 = 2 sectors, ..., 0xC9 = 9 sectors
                data[gatOffset + granule] = UInt8(0xC0 + lastSectorCount)
            }
        }
    }

    // MARK: - Directory Entry

    private func addDirectoryEntry(in data: inout Data, entryIndex: Int, fileName: String,
                                   fileExt: String, firstGranule: Int, fileType: UInt8,
                                   asciiFlag: UInt8, sides: Int) {
        // Directory entries start at sector 3 of track 17
        let dirSector = 2 + (entryIndex / 8)  // 8 entries per sector
        let entryInSector = entryIndex % 8
        let entryOffset = sectorOffset(track: directoryTrack, sector: dirSector, side: 0) + entryInSector * 32

        // File type (0 = killed, 1 = BASIC, 2 = data, 3 = ML)
        data[entryOffset] = fileType

        // Filename (8 bytes, padded with spaces)
        let paddedName = fileName.uppercased().padding(toLength: 8, withPad: " ", startingAt: 0)
        for (i, char) in paddedName.prefix(8).enumerated() {
            data[entryOffset + 1 + i] = char.asciiValue ?? 0x20
        }

        // Extension (3 bytes, padded with spaces)
        let paddedExt = fileExt.uppercased().padding(toLength: 3, withPad: " ", startingAt: 0)
        for (i, char) in paddedExt.prefix(3).enumerated() {
            data[entryOffset + 9 + i] = char.asciiValue ?? 0x20
        }

        // ASCII flag (0 = binary, 0xFF = ASCII)
        data[entryOffset + 12] = asciiFlag

        // First granule
        data[entryOffset + 13] = UInt8(firstGranule)

        // Bytes in last sector (2 bytes, little-endian) - set to 0 for full sectors
        data[entryOffset + 14] = 0
        data[entryOffset + 15] = 0

        // Reserved bytes (16-31) - fill with zeros
        for i in 16..<32 {
            data[entryOffset + i] = 0
        }
    }

    // MARK: - Granule Writing

    private func writeGranule(in data: inout Data, granule: Int, data chunk: Data.SubSequence, sides: Int) {
        let track = granule / granulesPerTrack
        let granuleInTrack = granule % granulesPerTrack
        let startSector = granuleInTrack * sectorsPerGranule

        var offset = 0
        for sector in 0..<sectorsPerGranule {
            guard offset < chunk.count else { break }

            let sectorOffset = self.sectorOffset(track: track, sector: startSector + sector, side: 0)
            let bytesToWrite = min(sectorSize, chunk.count - offset)

            for i in 0..<bytesToWrite {
                let sourceIndex = chunk.startIndex.advanced(by: offset + i)
                data[sectorOffset + i] = chunk[sourceIndex]
            }

            // Pad remaining bytes with 0x00
            for i in bytesToWrite..<sectorSize {
                data[sectorOffset + i] = 0x00
            }

            offset += sectorSize
        }
    }

    // MARK: - Helpers

    private func sectorOffset(track: Int, sector: Int, side: Int) -> Int {
        // CoCo DSK format: sequential sectors
        // Track 0 sectors, Track 1 sectors, etc.
        let absoluteTrack = track
        let absoluteSector = absoluteTrack * sectorsPerTrack + sector
        return absoluteSector * sectorSize
    }

    private func splitCoCoFileName(_ name: String) -> (String, String) {
        var baseName = name.uppercased()
        var ext = ""

        if let dotIndex = baseName.lastIndex(of: ".") {
            ext = String(baseName[baseName.index(after: dotIndex)...])
            baseName = String(baseName[..<dotIndex])
        }

        // CoCo allows A-Z, 0-9
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
