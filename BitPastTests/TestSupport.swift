import Foundation
@testable import BitPast

/// A file to put on a test disk: its name, extension and contents.
nonisolated struct SampleFile {
    let name: String
    let ext: String
    let data: Data
}

/// Shared helpers for the disk writer tests.
enum TestDisk {
    /// Deterministic pseudo-random bytes, so failures are reproducible.
    static func bytes(_ count: Int, seed: UInt32) -> Data {
        var state = seed &* 2_654_435_761 | 1
        var data = Data(count: count)
        for i in 0..<count {
            state ^= state << 13; state ^= state >> 17; state ^= state << 5
            data[i] = UInt8(truncatingIfNeeded: state)
        }
        return data
    }

    /// Files of awkward sizes: tiny, odd, and large enough to span many sectors.
    static func standardFiles(ext: String) -> [SampleFile] {
        [
            SampleFile(name: "PIC1", ext: ext, data: bytes(1, seed: 1)),
            SampleFile(name: "PIC2", ext: ext, data: bytes(1_000, seed: 2)),
            SampleFile(name: "PIC3", ext: ext, data: bytes(10_003, seed: 3)),
        ]
    }

    /// A fresh folder for one test. It lives in Caches, not the temp folder,
    /// because the host app empties its temp folder at launch, which can race
    /// with the first tests.
    static func makeDirectory() throws -> URL {
        let caches = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = caches.appendingPathComponent("BitPastTests/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Writes the sample files to disk and returns them in the shape the writers expect.
    static func writeInputs(_ files: [SampleFile], in dir: URL) throws -> [(url: URL, name: String)] {
        try files.map { file in
            let url = dir.appendingPathComponent("\(file.name).\(file.ext)")
            try file.data.write(to: url)
            return (url: url, name: file.name)
        }
    }

    /// Runs a writer into a temp folder and returns the image bytes.
    static func image(named fileName: String, files: [SampleFile],
                      write: (URL, [(url: URL, name: String)]) throws -> Bool) throws -> Data {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let inputs = try writeInputs(files, in: dir)
        let url = dir.appendingPathComponent(fileName)
        guard try write(url, inputs) else { throw TestDiskError.writerFailed }
        return try Data(contentsOf: url)
    }
}

enum TestDiskError: Error {
    case writerFailed
}

/// One file as read back from a disk image by a test reader.
nonisolated struct ReadFile: Equatable, CustomStringConvertible {
    let name: String
    let data: Data
    var description: String { "\(name) (\(data.count) bytes)" }
}

/// Byte readers for disk images. Reads outside the image return zeros instead of
/// trapping, so a broken image fails its own test rather than crashing the test run.
nonisolated extension Data {
    func u8(_ offset: Int) -> Int {
        guard offset >= 0, offset < count else { return 0 }
        return Int(self[startIndex + offset])
    }
    func le16(_ offset: Int) -> Int { u8(offset) | u8(offset + 1) << 8 }
    func le24(_ offset: Int) -> Int { le16(offset) | u8(offset + 2) << 16 }
    func le32(_ offset: Int) -> Int { le16(offset) | le16(offset + 2) << 16 }
    func be16(_ offset: Int) -> Int { u8(offset) << 8 | u8(offset + 1) }
    func be32(_ offset: Int) -> UInt32 {
        UInt32(u8(offset)) << 24 | UInt32(u8(offset + 1)) << 16 | UInt32(u8(offset + 2)) << 8 | UInt32(u8(offset + 3))
    }
    func slice(_ offset: Int, _ length: Int) -> Data {
        let length = Swift.min(Swift.max(0, length), 1 << 24)
        var out = Data(count: length)
        let lo = Swift.max(0, offset), hi = Swift.min(count, offset + length)
        if lo < hi {
            out.replaceSubrange((lo - offset)..<(hi - offset), with: self[(startIndex + lo)..<(startIndex + hi)])
        }
        return out
    }

    /// Text from fixed-width directory fields, with padding removed.
    func text(_ offset: Int, _ count: Int, padding: Set<UInt8> = [0x20, 0x00, 0xA0]) -> String {
        var bytes = Array(slice(offset, count))
        while let last = bytes.last, padding.contains(last) { bytes.removeLast() }
        return String(decoding: bytes.map { $0 & 0x7F }, as: UTF8.self)
    }
}
