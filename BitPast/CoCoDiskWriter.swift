import Foundation

// MARK: - CoCo Disk Writer
// TRS-80 Color Computer disk image writer: RS-DOS (Disk BASIC) volumes in .DSK (JVC) images

class CoCoDiskWriter {
    static let shared = CoCoDiskWriter()
    private init() {}

    // MARK: - RS-DOS Format Constants

    private let sectorSize = 256
    private let sectorsPerTrack = 18
    private let tracksPerSide = 35
    private let directoryTrack = 17
    private let sectorsPerGranule = 9
    private let maxDirectoryEntries = 72  // 9 sectors × 8 entries per sector
    private let totalGranules = 68        // 34 data tracks × 2 (track 17 is the directory)
    private var granuleBytes: Int { sectorsPerGranule * sectorSize }

    /// Single-sided images are plain 35-track JVC files. Double-sided images carry
    /// a 2-byte JVC header (sectors per track, sides) and interleave the sides track
    /// by track; each side holds its own RS-DOS volume, like a separate drive.
    private struct Layout {
        let sides: Int
        var headerSize: Int { sides == 2 ? 2 : 0 }
    }

    // MARK: - Public Interface

    /// Creates a disk image and returns the number of files written (0 if failed).
    /// RS-DOS has no volume names, so `volumeName` is not stored.
    func createDiskImage(at url: URL, volumeName: String, size: DiskSize, files: [(url: URL, name: String)]) -> Int {
        let layout = Layout(sides: size == .kb360 ? 2 : 1)
        let totalBytes = layout.headerSize + tracksPerSide * layout.sides * sectorsPerTrack * sectorSize

        // Unused sectors are 0xFF, as DSKINI leaves them
        var diskData = Data(repeating: 0xFF, count: totalBytes)
        if layout.headerSize > 0 {
            diskData[0] = UInt8(sectorsPerTrack)
            diskData[1] = UInt8(layout.sides)
        }
        for side in 0..<layout.sides {
            formatVolume(in: &diskData, side: side, layout: layout)
        }

        // Fill side 0 first, then continue on side 1
        var side = 0
        var filesWritten = 0
        for file in files {
            guard let fileData = try? Data(contentsOf: file.url) else {
                Log.error("CoCoDiskWriter: Could not read file \(file.name)")
                continue
            }
            let (fileName, fileExt) = splitCoCoFileName("\(file.name).\(file.url.pathExtension)")

            while side < layout.sides,
                  !addFile(fileData, name: fileName, ext: fileExt, to: &diskData, side: side, layout: layout) {
                side += 1
            }
            guard side < layout.sides else {
                Log.error("CoCoDiskWriter: Disk full, cannot add \(file.name)")
                break
            }
            filesWritten += 1
        }

        do {
            try diskData.write(to: url)
            Log.debug("CoCoDiskWriter: Created DSK at \(url.path) with \(filesWritten) files")
            return filesWritten
        } catch {
            Log.error("CoCoDiskWriter: Failed to write DSK: \(error)")
            return 0
        }
    }

    // MARK: - Volume

    /// Track 17 holds the GAT in sector 2 and the directory in sectors 3-11.
    /// The first 68 GAT bytes describe the granules; 0xFF means free.
    private func formatVolume(in data: inout Data, side: Int, layout: Layout) {
        let gat = gatOffset(side: side, layout: layout)
        for i in 0..<sectorSize {
            data[gat + i] = i < totalGranules ? 0xFF : 0x00
        }
    }

    /// Adds one file to the volume on `side`. Returns false if it does not fit.
    private func addFile(_ fileData: Data, name: String, ext: String, to data: inout Data, side: Int, layout: Layout) -> Bool {
        guard let entryIndex = freeDirectoryEntry(in: data, side: side, layout: layout) else { return false }

        let gat = gatOffset(side: side, layout: layout)
        let needed = max(1, (fileData.count + granuleBytes - 1) / granuleBytes)
        let granules = Array((0..<totalGranules).filter { data[gat + $0] == 0xFF }.prefix(needed))
        guard granules.count == needed else { return false }

        // Write the data and chain the granules in the GAT. The last granule's
        // entry is 0xC0 plus the number of sectors used in it.
        for (i, granule) in granules.enumerated() {
            let chunk = fileData.dropFirst(i * granuleBytes).prefix(granuleBytes)
            writeGranule(in: &data, granule: granule, chunk: chunk, side: side, layout: layout)
            if i + 1 < granules.count {
                data[gat + granule] = UInt8(granules[i + 1])
            } else {
                let sectorsUsed = max(1, (chunk.count + sectorSize - 1) / sectorSize)
                data[gat + granule] = UInt8(0xC0 + sectorsUsed)
            }
        }

        // Bytes used in the last sector: 1-256 (0 only for an empty file)
        let lastSectorBytes = fileData.isEmpty ? 0 : (fileData.count - 1) % sectorSize + 1
        writeDirectoryEntry(in: &data, entryIndex: entryIndex, side: side, layout: layout,
                            fileName: name, fileExt: ext, firstGranule: granules[0],
                            fileType: 0x02,   // Machine language (LOADM)
                            asciiFlag: 0x00,  // Binary
                            lastSectorBytes: lastSectorBytes)
        return true
    }

    /// First directory entry that is unused (0xFF) or killed (0x00).
    private func freeDirectoryEntry(in data: Data, side: Int, layout: Layout) -> Int? {
        (0..<maxDirectoryEntries).first { index in
            let first = data[directoryEntryOffset(index, side: side, layout: layout)]
            return first == 0xFF || first == 0x00
        }
    }

    // MARK: - Directory Entry

    /// RS-DOS entry: name (0-7), extension (8-10), type (11), ASCII flag (12),
    /// first granule (13), bytes used in last sector (14-15, big-endian), unused (16-31).
    private func writeDirectoryEntry(in data: inout Data, entryIndex: Int, side: Int, layout: Layout,
                                     fileName: String, fileExt: String, firstGranule: Int,
                                     fileType: UInt8, asciiFlag: UInt8, lastSectorBytes: Int) {
        let offset = directoryEntryOffset(entryIndex, side: side, layout: layout)
        let name = Array(fileName.uppercased().padding(toLength: 8, withPad: " ", startingAt: 0).utf8.prefix(8))
        let ext = Array(fileExt.uppercased().padding(toLength: 3, withPad: " ", startingAt: 0).utf8.prefix(3))
        var entry = [UInt8](repeating: 0, count: 32)
        entry.replaceSubrange(0..<8, with: name)
        entry.replaceSubrange(8..<11, with: ext)
        entry[11] = fileType       // 0 = BASIC, 1 = data, 2 = machine language, 3 = text
        entry[12] = asciiFlag      // 0 = binary, 0xFF = ASCII
        entry[13] = UInt8(firstGranule)
        entry[14] = UInt8((lastSectorBytes >> 8) & 0xFF)
        entry[15] = UInt8(lastSectorBytes & 0xFF)
        data.replaceSubrange(offset..<(offset + 32), with: entry)
    }

    // MARK: - Layout Helpers

    /// Offset of a sector (0-based within the track) on one side.
    private func sectorOffset(track: Int, sector: Int, side: Int, layout: Layout) -> Int {
        layout.headerSize + ((track * layout.sides + side) * sectorsPerTrack + sector) * sectorSize
    }

    private func gatOffset(side: Int, layout: Layout) -> Int {
        sectorOffset(track: directoryTrack, sector: 1, side: side, layout: layout)  // sector 2
    }

    private func directoryEntryOffset(_ index: Int, side: Int, layout: Layout) -> Int {
        // Sectors 3-11 (0-based 2-10), 8 entries of 32 bytes each
        sectorOffset(track: directoryTrack, sector: 2 + index / 8, side: side, layout: layout) + (index % 8) * 32
    }

    /// Granules 0-33 are tracks 0-16; granules 34-67 skip the directory track.
    /// Each track holds two granules of 9 sectors.
    private func writeGranule(in data: inout Data, granule: Int, chunk: Data, side: Int, layout: Layout) {
        var track = granule / 2
        if track >= directoryTrack { track += 1 }
        let firstSector = (granule % 2) * sectorsPerGranule
        for s in 0..<sectorsPerGranule {
            let part = chunk.dropFirst(s * sectorSize).prefix(sectorSize)
            guard !part.isEmpty else { break }
            let offset = sectorOffset(track: track, sector: firstSector + s, side: side, layout: layout)
            // Pad the rest of a partial sector with zeros
            var sector = Data(part)
            sector.append(Data(count: sectorSize - part.count))
            data.replaceSubrange(offset..<(offset + sectorSize), with: sector)
        }
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
