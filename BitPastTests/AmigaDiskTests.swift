import Foundation
import Testing
@testable import BitPast

/// Amiga ADF images, checked against the OFS (Old File System) layout.
@Suite("Amiga ADF")
struct AmigaDiskTests {

    static func block(_ image: Data, _ n: Int) -> Data { image.slice(n * 512, 512) }

    /// OFS/FFS blocks are valid when all 128 longwords add up to zero.
    static func checksumOK(_ block: Data) -> Bool {
        var sum: UInt32 = 0
        for i in 0..<128 { sum = sum &+ block.be32(i * 4) }
        return sum == 0
    }

    static func hash(_ name: String) -> Int {
        var h = UInt32(name.utf8.count)
        for c in name.uppercased().utf8 { h = (h &* 13 &+ UInt32(c)) & 0x7FF }
        return Int(h % 72)
    }

    /// Reads every file reachable from the root hash table, checking checksums
    /// and hash buckets on the way. Returns the files and every block they use.
    static func readFiles(_ image: Data, root: Int) -> (files: [ReadFile], used: Set<Int>) {
        var files: [ReadFile] = []
        var used: Set<Int> = [root]
        let rootBlock = block(image, root)
        for bucket in 0..<72 {
            var header = Int(rootBlock.be32(24 + bucket * 4))
            while header != 0 {
                let fh = block(image, header)
                used.insert(header)
                #expect(checksumOK(fh), "file header checksum")
                #expect(fh.be32(0) == 2 && Int32(bitPattern: fh.be32(508)) == -3, "file header type")
                let name = String(decoding: fh.slice(433, fh.u8(432)), as: UTF8.self)
                #expect(hash(name) == bucket, "\(name) is in hash bucket \(bucket)")
                let size = Int(fh.be32(324))

                // Data block pointers are stored backwards from offset 308,
                // continued in extension blocks.
                var pointers: [Int] = []
                var current = fh
                while true {
                    let count = min(Int(current.be32(8)), 72)
                    pointers += (0..<count).map { Int(current.be32(308 - $0 * 4)) }
                    let ext = Int(current.be32(504))
                    if ext == 0 { break }
                    used.insert(ext)
                    current = block(image, ext)
                    #expect(checksumOK(current), "extension block checksum")
                }

                var data = Data()
                for (seq, p) in pointers.enumerated() {
                    let db = block(image, p)
                    used.insert(p)
                    #expect(checksumOK(db), "data block checksum")
                    #expect(db.be32(0) == 8 && Int(db.be32(8)) == seq + 1, "data block header")
                    data.append(db.slice(24, Int(db.be32(12))))
                }
                #expect(data.count == size, "\(name) byte size")
                files.append(ReadFile(name: name, data: data))
                header = Int(fh.be32(496))
            }
        }
        return (files, used)
    }

    func write(size: DiskSize, files: [SampleFile]) throws -> Data {
        try TestDisk.image(named: "TEST.adf", files: files) { url, inputs in
            ADFWriter.shared.createDiskImage(at: url, volumeName: "BITPAST", size: size, files: inputs)
        }
    }

    @Test("Image has the standard size", arguments: [(DiskSize.kb880, 901_120), (DiskSize.mb1_76, 1_802_240)])
    func imageSize(size: DiskSize, expectedBytes: Int) throws {
        #expect(try write(size: size, files: TestDisk.standardFiles(ext: "iff")).count == expectedBytes)
    }

    @Test("Boot and root blocks are valid", arguments: [(DiskSize.kb880, 880), (DiskSize.mb1_76, 1760)])
    func rootBlock(size: DiskSize, root: Int) throws {
        let image = try write(size: size, files: TestDisk.standardFiles(ext: "iff"))
        #expect(image.slice(0, 3) == Data("DOS".utf8))
        let rb = Self.block(image, root)
        #expect(rb.be32(0) == 2 && rb.be32(508) == 1, "root block type")
        #expect(Self.checksumOK(rb), "root block checksum")
        #expect(String(decoding: rb.slice(433, rb.u8(432)), as: UTF8.self) == "BITPAST")
    }

    @Test("Files read back intact", arguments: [(DiskSize.kb880, 880), (DiskSize.mb1_76, 1760)])
    func roundTrip(size: DiskSize, root: Int) throws {
        let samples = TestDisk.standardFiles(ext: "iff")
        let image = try write(size: size, files: samples)
        let files = Self.readFiles(image, root: root).files
        #expect(files.count == samples.count)
        for sample in samples {
            let match = files.first { $0.name.uppercased().hasPrefix(sample.name) }
            #expect(match?.data == sample.data, "\(sample.name)")
        }
    }

    @Test("Bitmap marks exactly the blocks in use", arguments: [(DiskSize.kb880, 880, 1760), (DiskSize.mb1_76, 1760, 3520)])
    func bitmap(size: DiskSize, root: Int, totalBlocks: Int) throws {
        let image = try write(size: size, files: TestDisk.standardFiles(ext: "iff"))
        let rb = Self.block(image, root)
        #expect(Int32(bitPattern: rb.be32(312)) == -1, "bitmap flagged valid")
        var used = Self.readFiles(image, root: root).used

        // Bitmap block pointers in the root block (up to 25).
        var bitmapBits: [Bool] = []
        for i in 0..<25 {
            let bm = Int(rb.be32(316 + i * 4))
            if bm == 0 { break }
            used.insert(bm)
            let bb = Self.block(image, bm)
            #expect(Self.checksumOK(bb), "bitmap checksum")
            for long in 1..<128 {
                let v = bb.be32(long * 4)
                for bit in 0..<32 { bitmapBits.append(v >> bit & 1 == 1) }
            }
        }
        // The bitmap starts at block 2 (boot blocks are not tracked).
        try #require(bitmapBits.count >= totalBlocks - 2, "bitmap covers the disk")
        for blockNum in 2..<totalBlocks {
            let isFree = bitmapBits[blockNum - 2]
            #expect(isFree != used.contains(blockNum), "bitmap block \(blockNum)")
        }
    }
}
