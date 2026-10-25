import Foundation
import Testing
@testable import BitPast

/// ZX Spectrum TR-DOS (.trd) images: 80 tracks, 2 sides, 16 sectors of 256 bytes.
@Suite("ZX Spectrum TRD")
struct SpectrumDiskTests {

    static func write(format: DiskFormat, size: DiskSize, files: [SampleFile]) throws -> Data {
        try TestDisk.image(named: "TEST.\(format.fileExtension)", files: files) { url, inputs in
            TRDWriter.shared.createDiskImage(at: url, volumeName: "BITPAST", format: format, size: size, files: inputs)
        }
    }

    /// Reads the directory in track 0, sectors 0-7 (16 bytes per entry).
    static func readFiles(_ image: Data) -> [ReadFile] {
        var files: [ReadFile] = []
        for i in 0..<128 {
            let e = image.slice(i * 16, 16)
            if e.u8(0) == 0 { break }
            if e.u8(0) == 1 { continue }  // deleted
            let name = e.text(0, 8) + "." + String(UnicodeScalar(UInt8(e.u8(8))))
            let length = e.le16(11)
            #expect(e.u8(14) < 16, "\(name) start sector is 0-15")
            let offset = (e.u8(15) * 16 + e.u8(14)) * 256
            #expect(e.u8(13) == (length + 255) / 256, "\(name) sector count")
            files.append(ReadFile(name: name, data: image.slice(offset, length)))
        }
        return files
    }

    @Test("640 KB image has the TR-DOS size and system sector")
    func systemSector() throws {
        let samples = TestDisk.standardFiles(ext: "scr")
        let image = try Self.write(format: .trd, size: .kb640, files: samples)
        #expect(image.count == 655_360)
        let sys = image.slice(8 * 256, 256)
        #expect(sys.u8(0xE3) == 0x16, "disk type: 80 tracks, double sided")
        #expect(sys.u8(0xE7) == 0x10, "TR-DOS id byte")
        #expect(sys.u8(0xE4) == samples.count, "file count")
        let usedSectors = samples.reduce(0) { $0 + ($1.data.count + 255) / 256 }
        #expect(sys.le16(0xE5) == 2560 - 16 - usedSectors, "free sectors")
        let firstFree = 16 + usedSectors
        #expect(sys.u8(0xE2) * 16 + sys.u8(0xE1) == firstFree, "first free sector")
    }

    /// The large file runs past track 0, which checks the track/sector numbering
    /// (16 sectors per logical track).
    @Test("Files read back intact")
    func roundTrip() throws {
        let samples = TestDisk.standardFiles(ext: "c") + [SampleFile(name: "BIG", ext: "c", data: TestDisk.bytes(40_000, seed: 4))]
        let files = Self.readFiles(try Self.write(format: .trd, size: .kb640, files: samples))
        #expect(files.map(\.name) == samples.map { "\($0.name).C" })
        #expect(files.map(\.data) == samples.map(\.data))
    }

    /// The disk sheet offers "180 KB .dsk" for the Spectrum: a +3DOS disk with
    /// sector IDs 1-9, track 0 reserved, and a PLUS3DOS header on each file.
    @Test("180 KB .dsk option writes a +3 disk that reads back")
    func plus3Dsk() throws {
        let samples = TestDisk.standardFiles(ext: "scr") + [SampleFile(name: "SCREEN", ext: "scr", data: TestDisk.bytes(6912, seed: 6))]
        let image = try Self.write(format: .dsk, size: .kb180, files: samples)
        #expect(image.slice(0, 34) == Data("EXTENDED CPC DSK File\r\nDisk-Info\r\n".utf8))
        let disk = AmstradDiskTests.Disk(image: image, firstSectorID: 0x01, reservedTracks: 1)
        #expect(disk.tracks == 40 && disk.sides == 1)

        // Disk specification in track 0, sector 1
        let spec = disk.sector(trackIndex: 0, id: 0x01)?.slice(0, 10)
        #expect(spec == Data([0x00, 0x00, 0x28, 0x09, 0x02, 0x01, 0x03, 0x02, 0x2A, 0x52]))

        let files = disk.files()
        #expect(files.map(\.name) == samples.map { "\($0.name).SCR" })
        for (file, sample) in zip(files, samples) {
            let header = file.data.slice(0, 128)
            #expect(header.slice(0, 8) == Data("PLUS3DOS".utf8), "\(sample.name) header")
            #expect(header.u8(127) == header.prefix(127).reduce(0) { ($0 + Int($1)) & 0xFF }, "\(sample.name) header checksum")
            #expect(header.le32(11) == sample.data.count + 128, "\(sample.name) total length")
            #expect(header.u8(15) == 3 && header.le16(16) == sample.data.count, "\(sample.name) CODE header")
            #expect(file.data.dropFirst(128).prefix(sample.data.count) == sample.data, "\(sample.name) contents")
        }
        #expect(files.last?.data.slice(0, 128).le16(18) == 16384, "screens load at 16384")
    }
}
