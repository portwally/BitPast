import Foundation

// MARK: - Disk System Enumeration

enum DiskSystem: Int, CaseIterable, Identifiable {
    case appleII = 0
    case appleIIgs = 1
    case amiga500 = 2
    case amiga1200 = 3
    case amstradCPC = 4
    case atari800 = 5
    case atariST = 6
    case bbcMicro = 7
    case c64 = 8
    case msx = 9
    case pc = 10
    case plus4 = 11
    case vic20 = 12
    case zxSpectrum = 13

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .appleII: return "Apple II"
        case .appleIIgs: return "Apple IIgs"
        case .amiga500: return "Amiga 500"
        case .amiga1200: return "Amiga 1200"
        case .amstradCPC: return "Amstrad CPC"
        case .atari800: return "Atari 800"
        case .atariST: return "Atari ST"
        case .bbcMicro: return "BBC Micro"
        case .c64: return "C64"
        case .msx: return "MSX"
        case .pc: return "PC"
        case .plus4: return "Plus/4"
        case .vic20: return "VIC-20"
        case .zxSpectrum: return "ZX Spectrum"
        }
    }

    var iconName: String {
        switch self {
        case .appleII: return "icon_apple2"
        case .appleIIgs: return "icon_iigs"
        case .amiga500: return "icon_Amiga500"
        case .amiga1200: return "icon_Amiga1200"
        case .amstradCPC: return "icon_AmstradCPC"
        case .atari800: return "icon_Atari800"
        case .atariST: return "icon_AtariST"
        case .bbcMicro: return "icon_BBCmicro"
        case .c64: return "icon_C64"
        case .msx: return "icon_MSX"
        case .pc: return "icon_PC"
        case .plus4: return "icon_commodoreplus4"
        case .vic20: return "icon_vic20"
        case .zxSpectrum: return "icon_ZXSpectrum"
        }
    }

    var availableFormats: [DiskFormat] {
        switch self {
        case .appleII, .appleIIgs:
            return [.po, .twoMG, .hdv]
        case .c64, .vic20, .plus4:
            return [.d64, .d71, .d81]
        case .amiga500, .amiga1200:
            return [.adf]
        case .atari800:
            return [.atr]
        case .atariST:
            return [.st]
        case .msx:
            return [.dsk]
        case .amstradCPC:
            return [.dsk]
        case .zxSpectrum:
            return [.trd, .dsk]
        case .bbcMicro:
            return [.ssd, .dsd]
        case .pc:
            return [.img]
        }
    }

    var availableSizes: [DiskSize] {
        switch self {
        case .appleII, .appleIIgs:
            return [.kb140, .kb800, .mb32]
        case .c64, .vic20, .plus4:
            return [.kb170, .kb340, .kb800]
        case .amiga500:
            return [.kb880]
        case .amiga1200:
            return [.kb880, .mb1_76]
        case .atari800:
            return [.kb90, .kb130, .kb180, .kb360]
        case .atariST:
            return [.kb360, .kb720, .mb1_44]
        case .msx:
            return [.kb360, .kb720]
        case .amstradCPC:
            return [.kb180, .kb360]
        case .zxSpectrum:
            return [.kb640, .kb180]
        case .bbcMicro:
            return [.kb100, .kb200, .kb400]
        case .pc:
            return [.kb360, .kb720, .mb1_2, .mb1_44]
        }
    }

    var defaultFormat: DiskFormat {
        availableFormats.first!
    }

    var defaultSize: DiskSize {
        availableSizes.first!
    }

    var supportsVolumeName: Bool {
        true  // All systems support volume names
    }

    var maxVolumeNameLength: Int {
        switch self {
        case .appleII, .appleIIgs:
            return 15
        case .c64, .vic20, .plus4:
            return 16
        case .amiga500, .amiga1200:
            return 30
        case .atari800:
            return 8
        case .atariST:
            return 11
        case .msx:
            return 11
        case .amstradCPC:
            return 8
        case .zxSpectrum:
            return 8
        case .bbcMicro:
            return 12
        case .pc:
            return 11
        }
    }

    var volumeNameCharacterSet: CharacterSet {
        switch self {
        case .appleII, .appleIIgs:
            // ProDOS: A-Z, 0-9, period, must start with letter
            return CharacterSet.uppercaseLetters.union(.decimalDigits).union(CharacterSet(charactersIn: "."))
        case .c64, .vic20, .plus4:
            // PETSCII: Most printable characters
            return CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " !\"#$%&'()*+,-./:;<=>?"))
        case .amiga500, .amiga1200:
            // AmigaDOS: Most ASCII
            return CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " _-"))
        case .atari800, .atariST, .msx, .pc:
            // FAT-style: A-Z, 0-9
            return CharacterSet.uppercaseLetters.union(.decimalDigits)
        case .amstradCPC, .zxSpectrum, .bbcMicro:
            // ASCII alphanumerics
            return CharacterSet.alphanumerics
        }
    }

    func sanitizeVolumeName(_ name: String) -> String {
        var sanitized = name.uppercased()

        // Filter to allowed characters
        sanitized = String(sanitized.unicodeScalars.filter { volumeNameCharacterSet.contains($0) })

        // Truncate to max length
        if sanitized.count > maxVolumeNameLength {
            sanitized = String(sanitized.prefix(maxVolumeNameLength))
        }

        // Ensure first character is a letter for ProDOS
        if self == .appleII || self == .appleIIgs {
            if let first = sanitized.first, !first.isLetter {
                sanitized = "A" + sanitized.dropFirst()
            }
        }

        // Default if empty
        if sanitized.isEmpty {
            sanitized = "DISK"
        }

        return sanitized
    }
}

// MARK: - Disk Format Enumeration

enum DiskFormat: String, CaseIterable, Identifiable {
    // Apple II/IIgs
    case po = "po"
    case twoMG = "2mg"
    case hdv = "hdv"

    // Commodore
    case d64 = "d64"
    case d71 = "d71"
    case d81 = "d81"

    // Amiga
    case adf = "adf"

    // Atari
    case atr = "atr"
    case st = "st"

    // Generic
    case dsk = "dsk"
    case trd = "trd"
    case ssd = "ssd"
    case dsd = "dsd"
    case img = "img"

    var id: String { rawValue }

    var fileExtension: String { rawValue }

    var displayName: String {
        switch self {
        case .po: return ".PO (ProDOS Order)"
        case .twoMG: return ".2MG (2IMG)"
        case .hdv: return ".HDV (Hard Disk)"
        case .d64: return ".D64 (1541)"
        case .d71: return ".D71 (1571)"
        case .d81: return ".D81 (1581)"
        case .adf: return ".ADF (Amiga Disk)"
        case .atr: return ".ATR (Atari)"
        case .st: return ".ST (Atari ST)"
        case .dsk: return ".DSK"
        case .trd: return ".TRD (TR-DOS)"
        case .ssd: return ".SSD (Single-Sided)"
        case .dsd: return ".DSD (Double-Sided)"
        case .img: return ".IMG (DOS)"
        }
    }
}

// MARK: - Disk Size Enumeration

enum DiskSize: String, CaseIterable, Identifiable, Hashable {
    // Small sizes
    case kb90 = "90KB"
    case kb100 = "100KB"
    case kb130 = "130KB"
    case kb140 = "140KB"
    case kb170 = "170KB"
    case kb180 = "180KB"
    case kb200 = "200KB"

    // Medium sizes
    case kb340 = "340KB"
    case kb360 = "360KB"
    case kb400 = "400KB"
    case kb640 = "640KB"
    case kb720 = "720KB"
    case kb800 = "800KB"
    case kb880 = "880KB"

    // Large sizes
    case mb1_2 = "1.2MB"
    case mb1_44 = "1.44MB"
    case mb1_76 = "1.76MB"
    case mb32 = "32MB"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kb90: return "90 KB (Single Density)"
        case .kb100: return "100 KB (40 Track)"
        case .kb130: return "130 KB (Enhanced)"
        case .kb140: return "140 KB (5.25\")"
        case .kb170: return "170 KB (35 Tracks)"
        case .kb180: return "180 KB (Single-Sided)"
        case .kb200: return "200 KB (80 Track)"
        case .kb340: return "340 KB (Double-Sided)"
        case .kb360: return "360 KB"
        case .kb400: return "400 KB (DS 80 Track)"
        case .kb640: return "640 KB (TR-DOS)"
        case .kb720: return "720 KB"
        case .kb800: return "800 KB (3.5\")"
        case .kb880: return "880 KB (Amiga DD)"
        case .mb1_2: return "1.2 MB (5.25\" HD)"
        case .mb1_44: return "1.44 MB (3.5\" HD)"
        case .mb1_76: return "1.76 MB (Amiga HD)"
        case .mb32: return "32 MB (Hard Disk)"
        }
    }

    var bytes: Int {
        switch self {
        case .kb90: return 92160        // 90KB
        case .kb100: return 102400      // 100KB
        case .kb130: return 133120      // 130KB
        case .kb140: return 143360      // 140KB (280 blocks * 512)
        case .kb170: return 174848      // 170KB (683 sectors * 256)
        case .kb180: return 184320      // 180KB
        case .kb200: return 204800      // 200KB
        case .kb340: return 348160      // 340KB
        case .kb360: return 368640      // 360KB
        case .kb400: return 409600      // 400KB
        case .kb640: return 655360      // 640KB
        case .kb720: return 737280      // 720KB
        case .kb800: return 819200      // 800KB (1600 blocks * 512)
        case .kb880: return 901120      // 880KB (1760 sectors * 512)
        case .mb1_2: return 1228800     // 1.2MB
        case .mb1_44: return 1474560    // 1.44MB
        case .mb1_76: return 1802240    // 1.76MB
        case .mb32: return 33553920     // 32MB (65535 blocks * 512)
        }
    }

    // ProDOS block count (512-byte blocks)
    var proDOSBlocks: Int {
        bytes / 512
    }

    // CBM sector count (256-byte sectors)
    var cbmSectors: Int {
        switch self {
        case .kb170: return 683   // D64: 35 tracks
        case .kb340: return 1366  // D71: 70 tracks
        case .kb800: return 3200  // D81: 80 tracks
        default: return bytes / 256
        }
    }
}

// MARK: - Disk Configuration

struct DiskConfiguration {
    var system: DiskSystem
    var format: DiskFormat
    var size: DiskSize
    var volumeName: String

    // Apple II bootable disk options
    var bootable: Bool = false

    init(system: DiskSystem, format: DiskFormat? = nil, size: DiskSize? = nil, volumeName: String = "BITPAST", bootable: Bool = false) {
        self.system = system
        self.format = format ?? system.defaultFormat
        self.size = size ?? system.defaultSize
        self.volumeName = system.sanitizeVolumeName(volumeName)
        self.bootable = bootable
    }

    mutating func updateSystem(_ newSystem: DiskSystem) {
        system = newSystem
        // Reset to defaults for new system if current format/size not available
        if !system.availableFormats.contains(format) {
            format = system.defaultFormat
        }
        if !system.availableSizes.contains(size) {
            size = system.defaultSize
        }
        volumeName = system.sanitizeVolumeName(volumeName)

        // Reset bootable if not Apple II
        if system != .appleII && system != .appleIIgs {
            bootable = false
        }
    }

    /// Whether this system supports bootable disks
    var supportsBootable: Bool {
        system == .appleII || system == .appleIIgs
    }
}
