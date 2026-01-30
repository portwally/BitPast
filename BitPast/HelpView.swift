import SwiftUI

enum HelpSection: String, CaseIterable, Identifiable {
    case appleII = "Apple II"
    case appleIIgs = "Apple IIgs"
    case bbcMicro = "BBC Micro"
    case c64 = "Commodore 64"
    case vic20 = "VIC-20"
    case zxSpectrum = "ZX Spectrum"
    case amstradCPC = "Amstrad CPC"
    case plus4 = "Plus/4"
    case atari800 = "Atari 800"
    case atariST = "Atari ST"
    case amiga500 = "Amiga 500"
    case amiga1200 = "Amiga 1200"
    case pc = "PC"
    case msx = "MSX"
    case diskImages = "Disk Images"
    case generalOptions = "General Options"
    case filters = "Preprocessing Filters"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .appleII: return "desktopcomputer"
        case .appleIIgs: return "desktopcomputer"
        case .bbcMicro: return "desktopcomputer"
        case .c64: return "tv"
        case .vic20: return "tv"
        case .zxSpectrum: return "tv"
        case .amstradCPC: return "tv"
        case .plus4: return "tv"
        case .atari800: return "desktopcomputer"
        case .atariST: return "desktopcomputer"
        case .amiga500: return "desktopcomputer"
        case .amiga1200: return "desktopcomputer"
        case .pc: return "desktopcomputer"
        case .msx: return "tv"
        case .diskImages: return "externaldrive"
        case .generalOptions: return "slider.horizontal.3"
        case .filters: return "camera.filters"
        }
    }
}

struct HelpView: View {
    @State private var selectedSection: HelpSection = .appleII

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section("Systems") {
                    ForEach([HelpSection.appleII, .appleIIgs, .bbcMicro, .c64, .vic20, .zxSpectrum, .amstradCPC, .plus4, .atari800, .atariST, .amiga500, .amiga1200, .pc, .msx], id: \.self) { section in
                        Label(section.rawValue, systemImage: section.iconName)
                            .tag(section)
                    }
                }

                Section("Reference") {
                    ForEach([HelpSection.diskImages, .generalOptions, .filters], id: \.self) { section in
                        Label(section.rawValue, systemImage: section.iconName)
                            .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    detailContent(for: selectedSection)
                }
                .padding(30)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    @ViewBuilder
    func detailContent(for section: HelpSection) -> some View {
        switch section {
        case .appleII:
            AppleIIHelpContent()
        case .appleIIgs:
            AppleIIgsHelpContent()
        case .bbcMicro:
            BBCMicroHelpContent()
        case .c64:
            C64HelpContent()
        case .vic20:
            VIC20HelpContent()
        case .zxSpectrum:
            ZXSpectrumHelpContent()
        case .amstradCPC:
            AmstradCPCHelpContent()
        case .plus4:
            Plus4HelpContent()
        case .atari800:
            Atari800HelpContent()
        case .atariST:
            AtariSTHelpContent()
        case .amiga500:
            Amiga500HelpContent()
        case .amiga1200:
            Amiga1200HelpContent()
        case .pc:
            PCHelpContent()
        case .msx:
            MSXHelpContent()
        case .diskImages:
            DiskImagesHelpContent()
        case .generalOptions:
            GeneralOptionsHelpContent()
        case .filters:
            FiltersHelpContent()
        }
    }
}

// MARK: - Apple II Help

struct AppleIIHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "Apple II", subtitle: "Classic 6-color high-resolution graphics")

            ModeHelpSection(
                title: "Hi-Res Mode (280×192)",
                fileFormat: ".BIN (8,192 bytes)",
                description: "The Apple II Hi-Res mode provides 280×192 resolution with 6 colors. Colors are determined by horizontal position and pixel patterns due to NTSC artifact coloring.",
                bestFor: "Classic Apple II graphics, games, and artwork that need authentic period look",
                options: [
                    OptionHelp(name: "Dithering", description: "Error diffusion works well. Floyd-Steinberg recommended for photos."),
                    OptionHelp(name: "Color Matching", description: "Perceptive matching gives best results with the limited palette.")
                ]
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Apple II Palette")
                    .font(.headline)
                Text("6 colors available: Black, White, Green, Purple (Violet), Orange, Blue")
                    .foregroundColor(.secondary)
                Text("Colors are created through NTSC artifact coloring, where the color depends on the horizontal pixel position (odd vs even columns).")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            FileFormatHelp(
                extension_: ".BIN",
                name: "Apple II Hi-Res",
                size: "8,192 bytes",
                description: "Raw Hi-Res screen data. Can be loaded directly into Apple II memory at $2000."
            )
        }
    }
}

// MARK: - Apple IIgs Help

struct AppleIIgsHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "Apple IIgs", subtitle: "Super Hi-Res graphics with up to 3200 colors")

            ModeHelpSection(
                title: "3200 Colors (Brooks)",
                fileFormat: ".3200 (38,400 bytes)",
                description: "True 3200-color mode using the Brooks format. Each of the 200 scanlines has its own independent 16-color palette, allowing up to 3,200 unique colors on screen.",
                bestFor: "Photographic images, gradients, images with many colors",
                options: [
                    OptionHelp(name: "Palette Merge Tolerance", description: "Controls palette reuse between similar scanlines. Higher values reduce banding but may lose color accuracy. Set to 0 for maximum color fidelity, 10-20 for balanced results."),
                    OptionHelp(name: "Dithering", description: "All dithering algorithms work well. Floyd-Steinberg is recommended for photos."),
                    OptionHelp(name: "Saturation Boost", description: "Increase to compensate for the IIgs's somewhat muted palette.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "256 Colors (16 Palettes)",
                fileFormat: ".SHR (32,768 bytes)",
                description: "Standard SHR format with 16 palette slots. Scanlines are grouped and share palettes. Maximum 256 unique colors (16 palettes × 16 colors).",
                bestFor: "Compatibility with standard SHR viewers, when file size matters",
                options: [
                    OptionHelp(name: "3200 Quantization", description: "Per-Scanline: Groups consecutive scanlines into 16 slots. Palette Reuse: Tries to reuse palettes between similar scanlines."),
                    OptionHelp(name: "Palette Merge Tolerance", description: "Only visible with 'Palette Reuse' quantization. Controls how similar scanlines must be to share a palette.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "320×200 (16 Colors)",
                fileFormat: ".SHR (32,768 bytes)",
                description: "Standard Super Hi-Res mode with a single 16-color palette for the entire image. Classic IIgs graphics mode.",
                bestFor: "Simple graphics, logos, images with limited color range",
                options: [
                    OptionHelp(name: "Dithering", description: "Essential for this mode. Atkinson gives a classic Mac look, Floyd-Steinberg for smoother results.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "640×200 (4 Colors)",
                fileFormat: ".SHR (32,768 bytes)",
                description: "High-resolution mode with 640 horizontal pixels but only 4 colors. Good for text and line art.",
                bestFor: "Screenshots, text-heavy images, technical drawings",
                options: [
                    OptionHelp(name: "Dithering", description: "Ordered (Bayer) dithering works well to avoid artifacts.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "640×200 Enhanced (16 Colors)",
                fileFormat: ".SHR (32,768 bytes)",
                description: "Enhanced 640 mode using column-aware dithering. Even columns use one 4-color sub-palette, odd columns use another, for 8 effective colors.",
                bestFor: "Higher resolution images that need more color variety",
                options: [
                    OptionHelp(name: "Dithering", description: "Floyd-Steinberg recommended for best results.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "640×200 Desktop (16 Colors)",
                fileFormat: ".SHR (32,768 bytes)",
                description: "Uses the GS/OS Finder palette with column-aware dithering. Even columns: Black, Blue, Yellow, White. Odd columns: Black, Red, Green, White.",
                bestFor: "Images that should match the GS/OS desktop aesthetic",
                options: [
                    OptionHelp(name: "Dithering", description: "All algorithms work, but results will be limited to the fixed Finder palette.")
                ]
            )
        }
    }
}

// MARK: - C64 Help

struct C64HelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "Commodore 64", subtitle: "VIC-II graphics with 16 colors")

            ModeHelpSection(
                title: "HiRes Mode (320×200)",
                fileFormat: ".art (9,009 bytes)",
                description: "Standard C64 bitmap mode with 320×200 resolution. Each 8×8 character cell can use 2 colors from the 16-color palette.",
                bestFor: "High detail images, line art, text",
                options: [
                    OptionHelp(name: "Dithering", description: "Error diffusion recommended. Floyd-Steinberg or Atkinson work well."),
                    OptionHelp(name: "Color Matching", description: "Perceptive gives natural results, Luma preserves brightness detail.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "Multicolor Mode (160×200)",
                fileFormat: ".kla (10,003 bytes)",
                description: "C64 multicolor bitmap with double-wide pixels. Each 4×8 character cell can use 4 colors: 3 from the palette + 1 shared background color.",
                bestFor: "Colorful images, photos, artwork with many color areas",
                options: [
                    OptionHelp(name: "Pixel Merge", description: "Average: Blends adjacent pixels for smoother results. Brightest: Picks the brighter pixel, preserves highlights."),
                    OptionHelp(name: "Dithering", description: "Ordered dithering (Bayer) often works better than error diffusion in multicolor mode.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "PETSCII Mode (40×25)",
                fileFormat: ".prg (executable)",
                description: "Character-based graphics using the C64's built-in PETSCII character set. 40×25 character cells (320×200 pixels). Each 8×8 cell displays one of 256 PETSCII characters with 2 colors: global background + per-cell foreground.",
                bestFor: "ASCII/ANSI-style art, BBS graphics, text-based imagery, retro terminal aesthetics",
                options: [
                    OptionHelp(name: "Pattern Matching", description: "XOR-based algorithm finds the best matching PETSCII character for each 8×8 tile."),
                    OptionHelp(name: "Color Selection", description: "Background: most common dark color. Foreground: most contrasting color per cell."),
                    OptionHelp(name: "Color Matching", description: "Perceptive matching recommended for best character/color selection.")
                ]
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("C64 Palette (VICE/Pepto)")
                    .font(.headline)
                Text("16 fixed colors: Black, White, Red, Cyan, Purple, Green, Blue, Yellow, Orange, Brown, Light Red, Dark Gray, Medium Gray, Light Green, Light Blue, Light Gray")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            HStack(spacing: 20) {
                FileFormatHelp(
                    extension_: ".art",
                    name: "Art Studio",
                    size: "9,009 bytes",
                    description: "HiRes bitmap format compatible with Art Studio and many C64 image viewers."
                )
                FileFormatHelp(
                    extension_: ".kla",
                    name: "Koala Painter",
                    size: "10,003 bytes",
                    description: "Multicolor bitmap format compatible with Koala Painter and most C64 tools."
                )
                FileFormatHelp(
                    extension_: ".prg",
                    name: "PETSCII Executable",
                    size: "~2,200 bytes",
                    description: "Self-displaying program with BASIC loader. Screen RAM (1000) + Color RAM (1000) + viewer code."
                )
            }
        }
    }
}

// MARK: - VIC-20 Help

struct VIC20HelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "VIC-20", subtitle: "Character-based graphics with 16 colors")

            ModeHelpSection(
                title: "HiRes Mode (176×184)",
                fileFormat: ".prg (executable)",
                description: "VIC-20 high-resolution mode using custom character set. 22×23 character cells, each 8×8 pixels with 2 colors per cell.",
                bestFor: "Detailed images, line art, higher resolution needs",
                options: [
                    OptionHelp(name: "Dithering", description: "Error diffusion works well with the limited 2 colors per cell."),
                    OptionHelp(name: "Color Matching", description: "Perceptive recommended for natural color selection.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "LowRes Mode (88×184)",
                fileFormat: ".prg (executable)",
                description: "VIC-20 multicolor mode with double-wide pixels. 22×23 cells, each 4×8 pixels with 4 colors: background, border, auxiliary + 1 per cell.",
                bestFor: "Colorful images, photos, artwork needing more colors per area",
                options: [
                    OptionHelp(name: "Pixel Merge", description: "Average: Blends pixels for smoother look. Brightest: Preserves highlight detail."),
                    OptionHelp(name: "Dithering", description: "Ordered dithering often works better than error diffusion.")
                ]
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("VIC-20 Palette")
                    .font(.headline)
                Text("16 colors: Black, White, Red, Cyan, Purple, Green, Blue, Yellow, Orange, Light Orange, Pink, Light Cyan, Light Purple, Light Green, Light Blue, Light Yellow")
                    .foregroundColor(.secondary)
                Text("Note: The VIC-20 palette is slightly different from the C64 palette.")
                    .foregroundColor(.secondary)
                    .italic()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            FileFormatHelp(
                extension_: ".prg",
                name: "VIC-20 Executable",
                size: "Variable",
                description: "Self-displaying program that can be loaded and run directly on a VIC-20."
            )
        }
    }
}

// MARK: - ZX Spectrum Help

struct ZXSpectrumHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "ZX Spectrum", subtitle: "Attribute-based graphics with 15 colors")

            ModeHelpSection(
                title: "Standard Mode (256×192)",
                fileFormat: ".scr (6,912 bytes)",
                description: "ZX Spectrum screen with 256×192 pixels. Each 8×8 attribute cell has 2 colors (ink + paper) from the 15-color palette. Famous for 'attribute clash' when colors cross cell boundaries.",
                bestFor: "Authentic Spectrum look, pixel art, images with clearly defined color regions",
                options: [
                    OptionHelp(name: "Dithering", description: "Works within attribute constraints. Floyd-Steinberg or Atkinson recommended."),
                    OptionHelp(name: "Contrast", description: "CLAHE or SWAHE can help improve detail in attribute-constrained images."),
                    OptionHelp(name: "Color Matching", description: "Perceptive gives natural results within the limited palette.")
                ]
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("ZX Spectrum Palette")
                    .font(.headline)
                Text("15 colors (8 colors × 2 brightness levels, with both blacks being identical):")
                    .foregroundColor(.secondary)
                Text("Normal: Black, Blue, Red, Magenta, Green, Cyan, Yellow, White")
                    .foregroundColor(.secondary)
                Text("Bright: Black, Bright Blue, Bright Red, Bright Magenta, Bright Green, Bright Cyan, Bright Yellow, Bright White")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Attribute System")
                    .font(.headline)
                Text("Each 8×8 pixel cell has one attribute byte that defines:")
                    .foregroundColor(.secondary)
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("INK (foreground color, bits 0-2)")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("PAPER (background color, bits 3-5)")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("BRIGHT (bit 6) - affects both ink and paper")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("FLASH (bit 7) - not used in static images")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            FileFormatHelp(
                extension_: ".scr",
                name: "Spectrum Screen",
                size: "6,912 bytes",
                description: "Native screen dump: 6,144 bytes bitmap + 768 bytes attributes. Compatible with all Spectrum emulators."
            )
        }
    }
}

// MARK: - Amstrad CPC Help

struct AmstradCPCHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "Amstrad CPC", subtitle: "Hardware palette graphics with 27 colors")

            ModeHelpSection(
                title: "Mode 1 (320×200, 4 colors)",
                fileFormat: ".scr (16,512 bytes)",
                description: "Standard CPC mode with 320×200 resolution and 4 colors selected from the 27-color hardware palette. Good balance of resolution and color.",
                bestFor: "General purpose graphics, games, detailed images",
                options: [
                    OptionHelp(name: "Dithering", description: "Error diffusion recommended. Floyd-Steinberg or Atkinson work well."),
                    OptionHelp(name: "Color Matching", description: "The converter automatically selects optimal 4 colors from 27.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "Mode 0 (160×200, 16 colors)",
                fileFormat: ".scr (16,512 bytes)",
                description: "Low-resolution CPC mode with double-wide pixels. Uses all 16 palette entries, selected from 27 hardware colors. Most colorful CPC mode.",
                bestFor: "Colorful images, photos, artwork needing many colors",
                options: [
                    OptionHelp(name: "Pixel Merge", description: "Average: Blends adjacent pixels. Brightest: Picks brighter pixel for highlights."),
                    OptionHelp(name: "Dithering", description: "Ordered dithering often gives better results than error diffusion in this mode.")
                ]
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Amstrad CPC Hardware Palette")
                    .font(.headline)
                Text("27 fixed colors generated by the Gate Array chip:")
                    .foregroundColor(.secondary)
                Text("3 levels each for R, G, B (0, 128, 255) giving 3×3×3 = 27 colors")
                    .foregroundColor(.secondary)
                Text("Mode 0 can use 16 of these, Mode 1 uses 4, Mode 2 uses 2.")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("CPC Memory Layout")
                    .font(.headline)
                Text("The CPC uses an interleaved memory format where screen lines are not stored sequentially. Each group of 8 lines is spread across 8 separate 2KB banks.")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            FileFormatHelp(
                extension_: ".scr",
                name: "CPC Screen + AMSDOS Header",
                size: "16,512 bytes",
                description: "128-byte AMSDOS header + 16,384 bytes screen data. Compatible with CPC emulators and tools."
            )
        }
    }
}

// MARK: - Plus/4 Help

struct Plus4HelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "Commodore Plus/4", subtitle: "TED graphics with 128 colors")

            ModeHelpSection(
                title: "HiRes Mode (320×200)",
                fileFormat: ".prg (10,000 bytes)",
                description: "Plus/4 high-resolution bitmap mode with 320×200 pixels. Each 8×8 character cell can use 2 colors from the 128-color TED palette.",
                bestFor: "Detailed images, line art, high resolution needs",
                options: [
                    OptionHelp(name: "Dithering", description: "Error diffusion works well. Floyd-Steinberg recommended."),
                    OptionHelp(name: "Color Matching", description: "The large 128-color palette provides excellent color matching. Perceptive recommended.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "Multicolor Mode (160×200)",
                fileFormat: ".prg (10,000 bytes)",
                description: "Plus/4 multicolor bitmap with double-wide pixels. Each 4×8 character cell can use 4 colors: 2 global colors + 2 per cell from the 128-color palette.",
                bestFor: "Colorful photos, artwork with smooth gradients",
                options: [
                    OptionHelp(name: "Pixel Merge", description: "Average: Blends adjacent pixels smoothly. Brightest: Preserves highlight detail."),
                    OptionHelp(name: "Dithering", description: "Both error diffusion and ordered dithering work well with the large palette.")
                ]
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("TED 128-Color Palette")
                    .font(.headline)
                Text("The Plus/4's TED chip provides 128 colors:")
                    .foregroundColor(.secondary)
                Text("• 16 hues (including black and white)")
                    .foregroundColor(.secondary)
                Text("• 8 luminance levels per hue")
                    .foregroundColor(.secondary)
                Text("This gives much better color reproduction than the C64's fixed 16 colors.")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Plus/4 vs C64")
                    .font(.headline)
                Text("Key differences from Commodore 64:")
                    .foregroundColor(.secondary)
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("128 colors vs 16 colors")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("No hardware sprites")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("TED chip handles both video and sound")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("Same screen resolutions (320×200 / 160×200)")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            FileFormatHelp(
                extension_: ".prg",
                name: "Plus/4 Executable",
                size: "10,000 bytes",
                description: "Native format: nibble (1000) + screen (1000) + bitmap (8000) bytes. Self-displaying program."
            )
        }
    }
}

// MARK: - Atari ST Help

struct AtariSTHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "Atari ST", subtitle: "16 colors from 512-color palette")

            ModeHelpSection(
                title: "Low-Res Mode (320×200)",
                fileFormat: ".pi1 (32,034 bytes)",
                description: "Atari ST low-resolution mode with 320×200 pixels and 16 colors selected from the 512-color hardware palette. Uses DEGAS Elite format.",
                bestFor: "General graphics, photos, colorful images",
                options: [
                    OptionHelp(name: "Dithering", description: "Bayer 4×4 is default. Error diffusion (Floyd-Steinberg, Atkinson) also works well."),
                    OptionHelp(name: "Color Matching", description: "Perceptive recommended. The converter automatically selects optimal 16 colors from 512.")
                ]
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Atari ST 512-Color Palette")
                    .font(.headline)
                Text("The ST's Shifter chip provides 512 colors:")
                    .foregroundColor(.secondary)
                Text("• 8 levels each for Red, Green, Blue (3 bits per channel)")
                    .foregroundColor(.secondary)
                Text("• 8 × 8 × 8 = 512 total colors")
                    .foregroundColor(.secondary)
                Text("• 16 colors can be displayed simultaneously")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("DEGAS Format")
                    .font(.headline)
                Text("The PI1 file format (DEGAS Elite):")
                    .foregroundColor(.secondary)
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("2 bytes: Resolution (0x0000 = low-res)")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("32 bytes: Palette (16 colors × 2 bytes)")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("32,000 bytes: Bitplane data (4 interleaved planes)")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            FileFormatHelp(
                extension_: ".pi1",
                name: "DEGAS Elite",
                size: "32,034 bytes",
                description: "Standard Atari ST low-res image format. Compatible with DEGAS, NEOchrome, and ST emulators."
            )
        }
    }
}

// MARK: - Atari 800 Help

struct Atari800HelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "Atari 800", subtitle: "ANTIC/GTIA with 128-color palette")

            ModeHelpSection(
                title: "Graphics 8 (320×192, 2 colors)",
                fileFormat: ".gr8 (7,680 bytes)",
                description: "High-resolution monochrome mode. 320×192 pixels with 2 colors (background + foreground). Best for line art and high-contrast images.",
                bestFor: "Line art, text, high contrast images",
                options: [
                    OptionHelp(name: "Dithering", description: "Bayer dithering creates good patterns in monochrome."),
                    OptionHelp(name: "Contrast", description: "HE or CLAHE can improve detail in photos.")
                ]
            )

            ModeHelpSection(
                title: "Graphics 15 (160×192, 4 colors)",
                fileFormat: ".gr15 (7,680 bytes)",
                description: "Medium-resolution mode with 160×192 pixels and 4 colors from the 128-color palette. Double-wide pixels. Most versatile mode for general images.",
                bestFor: "General graphics, photos, colorful images",
                options: [
                    OptionHelp(name: "Dithering", description: "Bayer 4×4 is default. Floyd-Steinberg also works well."),
                    OptionHelp(name: "Color Matching", description: "Perceptive recommended for photos.")
                ]
            )

            ModeHelpSection(
                title: "Graphics 9 (80×192, 16 shades)",
                fileFormat: ".gr9 (7,680 bytes)",
                description: "GTIA mode with 80×192 pixels and 16 shades of grayscale. Quad-wide pixels. Excellent for photographic images.",
                bestFor: "Photos, portraits, grayscale images",
                options: [
                    OptionHelp(name: "Dithering", description: "Minimal dithering often best. Try Floyd-Steinberg for smoother gradients."),
                    OptionHelp(name: "Contrast", description: "CLAHE can enhance detail in low-contrast photos.")
                ]
            )

            ModeHelpSection(
                title: "Graphics 10 (80×192, 9 colors)",
                fileFormat: ".gr10 (7,680 bytes)",
                description: "GTIA color mode with 80×192 pixels and 9 colors selected from the 128-color palette. Quad-wide pixels. Good for colorful images with limited detail needs.",
                bestFor: "Colorful low-res images, artistic graphics",
                options: [
                    OptionHelp(name: "Dithering", description: "Bayer dithering recommended. Error diffusion may produce visible artifacts."),
                    OptionHelp(name: "Color Matching", description: "Perceptive recommended for natural color selection from the 128-color palette.")
                ]
            )

            ModeHelpSection(
                title: "Graphics 11 (80×192, 16 hues)",
                fileFormat: ".gr11 (7,680 bytes)",
                description: "GTIA hue mode with 80×192 pixels and 16 different hues at one luminance level. Quad-wide pixels. All colors have the same brightness.",
                bestFor: "Images with many different colors but uniform brightness, artistic effects",
                options: [
                    OptionHelp(name: "Dithering", description: "Bayer dithering works well. Hue-based dithering preserves color variety."),
                    OptionHelp(name: "Note", description: "All 16 colors share the same luminance, so contrast comes from hue differences only.")
                ]
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Atari 800 128-Color Palette")
                    .font(.headline)
                Text("The GTIA chip provides 128 colors:")
                    .foregroundColor(.secondary)
                Text("• 16 hues (0 = grayscale, 1-15 = colors)")
                    .foregroundColor(.secondary)
                Text("• 8 luminance levels per hue")
                    .foregroundColor(.secondary)
                Text("• NTSC color generation via phase shifts")
                    .foregroundColor(.secondary)
                Text("GTIA modes (9, 10, 11) use different subsets:")
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                Text("• Graphics 9: 16 shades of one hue (grayscale)")
                    .foregroundColor(.secondary)
                Text("• Graphics 10: 9 colors from full 128-color palette")
                    .foregroundColor(.secondary)
                Text("• Graphics 11: 16 hues at one luminance level")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            FileFormatHelp(
                extension_: ".gr8, .gr9, .gr10, .gr11, .gr15",
                name: "Raw Graphics",
                size: "7,680 bytes",
                description: "Raw bitmap data for Atari 800 graphics modes. Compatible with Atari emulators and graphics programs."
            )
        }
    }
}

// MARK: - BBC Micro Help

struct BBCMicroHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "BBC Micro", subtitle: "6845 CRTC with 8-color palette")

            ModeHelpSection(
                title: "Mode 0 (640×256, 2 colors)",
                fileFormat: ".bbc (20,480 bytes)",
                description: "High-resolution monochrome mode with 640×256 pixels. 2 colors selected from the 8-color palette. 80 bytes per line.",
                bestFor: "Text, line art, high-resolution graphics",
                options: [
                    OptionHelp(name: "Dithering", description: "Bayer dithering creates good patterns in 2-color mode."),
                    OptionHelp(name: "Contrast", description: "HE or CLAHE can improve detail in photos.")
                ]
            )

            ModeHelpSection(
                title: "Mode 1 (320×256, 4 colors)",
                fileFormat: ".bbc (20,480 bytes)",
                description: "Medium-resolution mode with 320×256 pixels. 4 colors selected from the 8-color palette. Good balance of resolution and color.",
                bestFor: "General graphics, games, colorful images",
                options: [
                    OptionHelp(name: "Dithering", description: "Floyd-Steinberg or Bayer 4×4 recommended."),
                    OptionHelp(name: "Color Matching", description: "Perceptive recommended for natural color selection.")
                ]
            )

            ModeHelpSection(
                title: "Mode 2 (160×256, 8 colors)",
                fileFormat: ".bbc (20,480 bytes)",
                description: "Low-resolution mode with 160×256 pixels and all 8 colors available. Quad-wide pixels. Most colorful BBC Micro mode.",
                bestFor: "Colorful images, photos, artwork needing full palette",
                options: [
                    OptionHelp(name: "Dithering", description: "Often not needed with 8 colors. Light dithering can help gradients."),
                    OptionHelp(name: "Color Matching", description: "Hue matching preserves colors well with this saturated palette.")
                ]
            )

            ModeHelpSection(
                title: "Mode 4 (320×256, 2 colors)",
                fileFormat: ".bbc (10,240 bytes)",
                description: "Medium-resolution monochrome mode. Same resolution as Mode 1 but with only 2 colors, using half the memory.",
                bestFor: "Line art, text, when memory is limited",
                options: [
                    OptionHelp(name: "Dithering", description: "Bayer dithering recommended for photos.")
                ]
            )

            ModeHelpSection(
                title: "Mode 5 (160×256, 4 colors)",
                fileFormat: ".bbc (10,240 bytes)",
                description: "Low-resolution mode with 4 colors. Same resolution as Mode 2 but with fewer colors, using half the memory.",
                bestFor: "Colorful graphics when memory is limited",
                options: [
                    OptionHelp(name: "Dithering", description: "Floyd-Steinberg recommended for photos.")
                ]
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("BBC Micro 8-Color Palette")
                    .font(.headline)
                Text("The BBC Micro has a fixed 8-color palette:")
                    .foregroundColor(.secondary)
                Text("• 0: Black, 1: Red, 2: Green, 3: Yellow")
                    .foregroundColor(.secondary)
                Text("• 4: Blue, 5: Magenta, 6: Cyan, 7: White")
                    .foregroundColor(.secondary)
                Text("Modes with fewer colors select from this palette.")
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                Text("Note: Flashing colors (8-15) are not supported in static images.")
                    .foregroundColor(.secondary)
                    .italic()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            FileFormatHelp(
                extension_: ".bbc",
                name: "Raw Screen",
                size: "10,240-20,480 bytes",
                description: "Raw screen memory dump. Compatible with BBC Micro emulators like BeebEm and b-em."
            )
        }
    }
}

// MARK: - Amiga 500 Help

struct Amiga500HelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "Amiga 500", subtitle: "OCS/ECS chipset with 4096-color palette")

            ModeHelpSection(
                title: "Standard Mode (32 colors)",
                fileFormat: ".iff (IFF ILBM)",
                description: "Standard Amiga OCS mode with 32 colors selected from the 4096-color hardware palette. Uses 5 bitplanes for 32 simultaneous colors.",
                bestFor: "General graphics, games, images with limited color range",
                options: [
                    OptionHelp(name: "Resolution", description: "320×256 (PAL standard) or 320×512 (interlaced)"),
                    OptionHelp(name: "Dithering", description: "Bayer 4×4 is default. Error diffusion also works well."),
                    OptionHelp(name: "Color Matching", description: "Perceptive recommended. Automatically selects optimal 32 colors.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "HAM6 Mode (4096 colors)",
                fileFormat: ".iff (IFF ILBM)",
                description: "Hold-And-Modify mode allows up to 4096 colors on screen. Each pixel can either use a palette color or modify one RGB channel from the previous pixel. Uses 6 bitplanes.",
                bestFor: "Photographs, gradients, images requiring many colors",
                options: [
                    OptionHelp(name: "Resolution", description: "320×256 (PAL standard) or 320×512 (interlaced)"),
                    OptionHelp(name: "Dithering", description: "Usually not needed due to high color count. Subtle dithering can help with gradients.")
                ]
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Amiga OCS 4096-Color Palette")
                    .font(.headline)
                Text("The Original Chip Set provides 4096 colors:")
                    .foregroundColor(.secondary)
                Text("• 4 bits each for Red, Green, Blue (12-bit color)")
                    .foregroundColor(.secondary)
                Text("• 16 × 16 × 16 = 4096 total colors")
                    .foregroundColor(.secondary)
                Text("• Standard: 32 colors displayed simultaneously (5 bitplanes)")
                    .foregroundColor(.secondary)
                Text("• HAM6: Up to 4096 colors with hold-and-modify (6 bitplanes)")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("IFF ILBM Format")
                    .font(.headline)
                Text("Interchange File Format - Interleaved Bitmap:")
                    .foregroundColor(.secondary)
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("BMHD chunk: Bitmap header (dimensions, depth, compression)")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("CMAP chunk: Color map (palette)")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("CAMG chunk: Amiga viewport mode")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("BODY chunk: Interleaved bitplane data")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            FileFormatHelp(
                extension_: ".iff",
                name: "IFF ILBM",
                size: "Variable",
                description: "Standard Amiga image format. Compatible with Deluxe Paint, Personal Paint, and all Amiga software."
            )
        }
    }
}

// MARK: - Amiga 1200 Help

struct Amiga1200HelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "Amiga 1200", subtitle: "AGA chipset with 16.7 million colors")

            ModeHelpSection(
                title: "Standard Mode (256 colors)",
                fileFormat: ".iff (IFF ILBM)",
                description: "AGA mode with 256 colors selected from the full 24-bit palette. Uses 8 bitplanes for 256 simultaneous colors.",
                bestFor: "General graphics, games, images with moderate color range",
                options: [
                    OptionHelp(name: "Resolution", description: "320×256, 320×512 (interlaced), or 640×512 (hi-res interlaced)"),
                    OptionHelp(name: "Dithering", description: "Bayer 4×4 is default. With 256 colors, less dithering is usually needed."),
                    OptionHelp(name: "Color Matching", description: "Perceptive recommended. Automatically selects optimal 256 colors.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "HAM8 Mode (262144 colors)",
                fileFormat: ".iff (IFF ILBM)",
                description: "AGA Hold-And-Modify mode allows up to 262,144 colors on screen. Each pixel can either use a palette color or modify one RGB channel (6 bits per channel) from the previous pixel. Uses 8 bitplanes.",
                bestFor: "Photographs, photorealistic images, gradients",
                options: [
                    OptionHelp(name: "Resolution", description: "320×256, 320×512 (interlaced), or 640×512 (hi-res interlaced)"),
                    OptionHelp(name: "Dithering", description: "Rarely needed. HAM8 provides excellent color reproduction.")
                ]
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Amiga AGA 24-bit Palette")
                    .font(.headline)
                Text("The Advanced Graphics Architecture provides 16.7 million colors:")
                    .foregroundColor(.secondary)
                Text("• 8 bits each for Red, Green, Blue (24-bit color)")
                    .foregroundColor(.secondary)
                Text("• 256 × 256 × 256 = 16,777,216 total colors")
                    .foregroundColor(.secondary)
                Text("• Standard: 256 colors displayed simultaneously (8 bitplanes)")
                    .foregroundColor(.secondary)
                Text("• HAM8: Up to 262,144 colors with 6 bits per channel modification")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("IFF ILBM Format")
                    .font(.headline)
                Text("Interchange File Format - Interleaved Bitmap:")
                    .foregroundColor(.secondary)
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("BMHD chunk: Bitmap header (dimensions, depth, compression)")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("CMAP chunk: Color map (palette)")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("CAMG chunk: Amiga viewport mode (AGA modes)")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("BODY chunk: Interleaved bitplane data (8 planes)")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            FileFormatHelp(
                extension_: ".iff",
                name: "IFF ILBM",
                size: "Variable",
                description: "Standard Amiga image format. Compatible with all AGA-capable Amiga software including Personal Paint and ADPro."
            )
        }
    }
}

// MARK: - PC Help

struct PCHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "PC", subtitle: "CGA, EGA, VGA and text modes")

            ModeHelpSection(
                title: "CGA Mode (320×200, 4 colors)",
                fileFormat: ".pcx (PC Paintbrush)",
                description: "Color Graphics Adapter mode with 4 colors from fixed palettes. The iconic PC graphics standard from 1981.",
                bestFor: "Classic PC game graphics, retro DOS aesthetics",
                options: [
                    OptionHelp(name: "CGA Palette", description: "Cyan/Magenta/White (high intensity), Cyan/Magenta/Gray (low), Green/Red/Yellow (high), Green/Red/Brown (low)"),
                    OptionHelp(name: "Dithering", description: "Floyd-Steinberg strongly recommended due to limited 4-color palette.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "EGA Mode (320×200, 16 colors)",
                fileFormat: ".pcx (PC Paintbrush)",
                description: "Enhanced Graphics Adapter mode using the standard fixed 16-color EGA palette. The same colors as CGA's 16-color text mode palette.",
                bestFor: "Authentic EGA look, classic DOS game graphics",
                options: [
                    OptionHelp(name: "Dithering", description: "Ordered dithering (Bayer) often produces good results. 16 colors allow reasonable color reproduction."),
                    OptionHelp(name: "Color Matching", description: "Hue or Chroma recommended to preserve colors with this fixed palette. Perceptive may map saturated colors to grays.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "EGA 64 Mode (320×200, 16 from 64)",
                fileFormat: ".pcx (PC Paintbrush)",
                description: "Enhanced Graphics Adapter mode with 16 colors selected from the full 64-color EGA palette. Allows optimal color selection per image.",
                bestFor: "Images that benefit from custom color selection, Sierra adventure games aesthetic",
                options: [
                    OptionHelp(name: "Dithering", description: "Ordered dithering (Bayer) often produces good results."),
                    OptionHelp(name: "Color Matching", description: "Perceptive recommended. Optimal 16 colors are automatically selected from the 64-color EGA palette.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "VGA Mode 13h (320×200, 256 colors)",
                fileFormat: ".pcx (PC Paintbrush)",
                description: "The legendary VGA Mode 13h with 256 colors from the full 262,144-color VGA palette. The standard for DOS games from 1987-1997.",
                bestFor: "DOS game graphics, pixel art, photographs",
                options: [
                    OptionHelp(name: "Dithering", description: "Often not needed with 256 colors. Use sparingly for photographs."),
                    OptionHelp(name: "Color Matching", description: "Uses adaptive palette generation (median cut) for optimal 256-color palette.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "CGA 80×25 Text Mode",
                fileFormat: ".ans (ANSI art)",
                description: "Classic DOS text mode using 8×8 character cells. 80 columns × 25 rows with 16 foreground and 8 background colors. Resolution: 640×200 pixels.",
                bestFor: "ASCII art, BBS graphics, ANSI art aesthetics",
                options: [
                    OptionHelp(name: "Characters", description: "Uses block characters and shading patterns to approximate image content"),
                    OptionHelp(name: "Colors", description: "16 foreground colors, 8 background colors per character cell")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "VESA 132×50 Text Mode",
                fileFormat: ".ans (ANSI art)",
                description: "Extended VESA text mode with 132 columns × 50 rows. Higher resolution text display (1056×400 pixels) for more detailed ASCII art.",
                bestFor: "High-detail ASCII art, detailed text mode graphics",
                options: [
                    OptionHelp(name: "Characters", description: "Same block characters as CGA text mode but with more cells for finer detail"),
                    OptionHelp(name: "Resolution", description: "132×50 characters = 1056×400 pixels")
                ]
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("PC Graphics Evolution")
                    .font(.headline)
                Text("CGA (1981): 4 colors from fixed palettes, 320×200")
                    .foregroundColor(.secondary)
                Text("EGA (1984): 16 from 64 colors, 320×200 or 640×350")
                    .foregroundColor(.secondary)
                Text("VGA (1987): 256 from 262,144 colors, 320×200 Mode 13h")
                    .foregroundColor(.secondary)
                Text("Text modes: Character-based display using 8×8 font cells")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            HStack(spacing: 20) {
                FileFormatHelp(
                    extension_: ".pcx",
                    name: "PC Paintbrush",
                    size: "Variable (RLE compressed)",
                    description: "Standard DOS graphics format from 1985. Compatible with Deluxe Paint, PC Paintbrush, and all DOS image viewers."
                )
                FileFormatHelp(
                    extension_: ".ans",
                    name: "ANSI Art",
                    size: "Variable",
                    description: "BBS-standard text art format using ANSI escape codes. Compatible with all ANSI viewers and terminals."
                )
            }
        }
    }
}

// MARK: - MSX Help

struct MSXHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "MSX", subtitle: "TMS9918 and V9938 video modes")

            ModeHelpSection(
                title: "Screen 2 (256×192, MSX1)",
                fileFormat: ".sc2 (BSAVE)",
                description: "MSX1 graphics mode using the TMS9918 video chip. 2 colors per 8×1 horizontal line from the fixed 16-color palette. Each 8-pixel horizontal segment has its own foreground and background color.",
                bestFor: "MSX1 game graphics, colorful images with horizontal color variation",
                options: [
                    OptionHelp(name: "Dithering", description: "Error diffusion works well within the 8×1 color constraints."),
                    OptionHelp(name: "Color Matching", description: "Hue or Chroma recommended to preserve colors with the fixed TMS9918 palette.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "Screen 5 (256×212, MSX2)",
                fileFormat: ".sc5 (BSAVE)",
                description: "MSX2 graphics mode using the V9938 video chip. 16 colors selected from a 512-color palette (3 bits per channel). Similar to Atari ST graphics.",
                bestFor: "MSX2 game graphics, detailed images with custom palette",
                options: [
                    OptionHelp(name: "Dithering", description: "Floyd-Steinberg recommended for photos. Bayer for pixel art."),
                    OptionHelp(name: "Color Matching", description: "Perceptive recommended. Optimal 16 colors are automatically selected from 512.")
                ]
            )

            Divider()

            ModeHelpSection(
                title: "Screen 8 (256×212, MSX2)",
                fileFormat: ".sc8 (BSAVE)",
                description: "MSX2 256-color mode with fixed 3-3-2 RGB palette (3 bits red, 3 bits green, 2 bits blue). No palette selection needed - colors are directly mapped.",
                bestFor: "Photographs, images with smooth gradients",
                options: [
                    OptionHelp(name: "Dithering", description: "Often not needed with 256 colors. Light dithering can help with banding."),
                    OptionHelp(name: "Note", description: "Blue channel has only 4 levels (2 bits), so blue gradients may show more banding.")
                ]
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("MSX Graphics Evolution")
                    .font(.headline)
                Text("MSX1 (1983): TMS9918 - 256×192, 2 colors per 8×1 line from 16")
                    .foregroundColor(.secondary)
                Text("MSX2 (1985): V9938 - Multiple modes, 512-color palette")
                    .foregroundColor(.secondary)
                Text("MSX2+ (1988): V9958 - Enhanced YJK modes, 19268 colors")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            HStack(spacing: 20) {
                FileFormatHelp(
                    extension_: ".sc2",
                    name: "Screen 2 BSAVE",
                    size: "~14KB",
                    description: "MSX BSAVE format with pattern and color tables. Load with BLOAD command."
                )
                FileFormatHelp(
                    extension_: ".sc5",
                    name: "Screen 5 BSAVE",
                    size: "~27KB",
                    description: "MSX2 BSAVE format with palette and 4bpp image data."
                )
                FileFormatHelp(
                    extension_: ".sc8",
                    name: "Screen 8 BSAVE",
                    size: "~54KB",
                    description: "MSX2 BSAVE format with 8bpp image data (3-3-2 RGB)."
                )
            }
        }
    }
}

// MARK: - Disk Images Help

struct DiskImagesHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "Disk Images", subtitle: "Create virtual disk images for all supported systems")

            VStack(alignment: .leading, spacing: 12) {
                Text("Overview")
                    .font(.headline)
                Text("BitPast can create authentic virtual disk images containing your converted files. These disk images can be loaded directly into emulators or transferred to real hardware via flash devices.")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Divider()

            DiskFormatHelpSection(
                system: "Apple II / Apple IIgs",
                formats: ".PO, .2MG, .HDV",
                sizes: "140KB, 800KB, 32MB",
                filesystem: "ProDOS",
                description: "Apple ProDOS disk images. 140KB for 5.25\" floppy, 800KB for 3.5\" floppy, 32MB for hard disk images.",
                emulators: "AppleWin, KEGS, GSport, Virtual II"
            )

            DiskFormatHelpSection(
                system: "Commodore 64 / VIC-20 / Plus4",
                formats: ".D64, .D71, .D81",
                sizes: "170KB, 340KB, 800KB",
                filesystem: "CBM DOS",
                description: "Commodore disk images. D64 (1541 drive, 35 tracks), D71 (1571 drive, 70 tracks), D81 (1581 drive, 80 tracks). Files are stored as PRG type.",
                emulators: "VICE (x64, x128, xvic, xplus4)"
            )

            DiskFormatHelpSection(
                system: "Amiga 500 / Amiga 1200",
                formats: ".ADF",
                sizes: "880KB, 1.76MB",
                filesystem: "OFS (Original File System)",
                description: "Amiga Disk File format. 880KB for standard DD disks, 1.76MB for HD disks. Uses Amiga OFS filesystem with hash table directory.",
                emulators: "FS-UAE, WinUAE, Amiberry"
            )

            DiskFormatHelpSection(
                system: "Atari 800",
                formats: ".ATR",
                sizes: "90KB, 130KB, 180KB, 360KB",
                filesystem: "Atari DOS 2.0S",
                description: "ATR format with 16-byte header. Supports single density (90KB), enhanced density (130KB), and double density (180KB, 360KB).",
                emulators: "Altirra, Atari800"
            )

            DiskFormatHelpSection(
                system: "Atari ST",
                formats: ".ST",
                sizes: "360KB, 720KB, 1.44MB",
                filesystem: "FAT12",
                description: "Raw sector disk images with FAT12 filesystem. Compatible with TOS/GEM desktop. Standard PC floppy geometry.",
                emulators: "Hatari, Steem"
            )

            DiskFormatHelpSection(
                system: "BBC Micro",
                formats: ".SSD, .DSD",
                sizes: "100KB, 200KB, 400KB",
                filesystem: "Acorn DFS",
                description: "SSD (Single-Sided Disk) and DSD (Double-Sided Disk). Uses Acorn Disc Filing System with catalog in sectors 0-1. Maximum 31 files per disk.",
                emulators: "BeebEm, b-em, JSBeeb"
            )

            DiskFormatHelpSection(
                system: "MSX",
                formats: ".DSK",
                sizes: "360KB, 720KB",
                filesystem: "MSX-DOS (FAT12)",
                description: "MSX disk images using FAT12 filesystem compatible with MSX-DOS. Standard PC-compatible 3.5\" floppy format.",
                emulators: "openMSX, blueMSX, fMSX"
            )

            DiskFormatHelpSection(
                system: "Amstrad CPC",
                formats: ".DSK",
                sizes: "180KB, 360KB",
                filesystem: "AMSDOS",
                description: "CPCEMU extended DSK format with track headers. Uses AMSDOS filesystem with CP/M-style directory entries.",
                emulators: "WinAPE, Arnold, Caprice32"
            )

            DiskFormatHelpSection(
                system: "ZX Spectrum",
                formats: ".TRD, .DSK",
                sizes: "640KB, 180KB",
                filesystem: "TR-DOS",
                description: "TR-DOS format for Beta Disk interface. 640KB uses 80 tracks, double-sided. File types: B (BASIC), C (Code), D (Data), # (Screen).",
                emulators: "Fuse, ZX Spin, SpecEmu"
            )

            DiskFormatHelpSection(
                system: "PC",
                formats: ".IMG",
                sizes: "360KB, 720KB, 1.2MB, 1.44MB",
                filesystem: "FAT12/FAT16",
                description: "Raw sector disk images with DOS FAT filesystem. Compatible with MS-DOS, PC-DOS, and FreeDOS. Standard PC floppy formats.",
                emulators: "DOSBox, PCem, 86Box"
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("How to Use")
                    .font(.headline)
                HStack(alignment: .top, spacing: 8) {
                    Text("1.")
                        .fontWeight(.medium)
                    Text("Convert an image to your target system format")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("2.")
                        .fontWeight(.medium)
                    Text("Click the \"Create Disk\" button in the export area")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("3.")
                        .fontWeight(.medium)
                    Text("Select the target system from the icon bar (pre-selected to match current conversion)")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("4.")
                        .fontWeight(.medium)
                    Text("Enter a volume name and choose disk format/size")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("5.")
                        .fontWeight(.medium)
                    Text("Click \"Create Disk Image\" to save the disk file")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 12) {
                Text("Volume Name Rules")
                    .font(.headline)
                Text("Each system has specific rules for volume names:")
                    .foregroundColor(.secondary)
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("Apple II/IIgs: 15 chars, A-Z 0-9 period, must start with letter")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("Commodore: 16 chars, most printable PETSCII characters")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("Amiga: 30 chars, most ASCII except : and /")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("Atari/PC/MSX: 8-11 chars, A-Z 0-9 only")
                        .foregroundColor(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("BBC Micro: 12 chars, alphanumeric")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct DiskFormatHelpSection: View {
    let system: String
    let formats: String
    let sizes: String
    let filesystem: String
    let description: String
    let emulators: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(system)
                    .font(.headline)
                Spacer()
                Text(formats)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
            }

            Text(description)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                HStack {
                    Text("Sizes:")
                        .fontWeight(.medium)
                    Text(sizes)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Filesystem:")
                        .fontWeight(.medium)
                    Text(filesystem)
                        .foregroundColor(.secondary)
                }
            }

            HStack(alignment: .top) {
                Text("Emulators:")
                    .fontWeight(.medium)
                Text(emulators)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - General Options Help

struct GeneralOptionsHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "General Options", subtitle: "Common settings across all converters")

            GeneralOptionHelp(
                name: "Dithering Algorithm",
                options: [
                    "Floyd-Steinberg: Classic error diffusion, good all-around choice",
                    "Atkinson: Less error diffusion, gives a classic Macintosh look",
                    "Jarvis-Judice-Ninke: Spreads error further, smoother gradients",
                    "Stucki: Similar to JJN, slightly different character",
                    "Burkes: Faster variant of Stucki",
                    "Noise: Random dither, adds film grain texture",
                    "Bayer (2×2 to 16×16): Ordered pattern dither, good for animations",
                    "Blue Noise (8×8, 16×16): Random-looking with pleasing texture",
                    "None: No dithering, direct color mapping"
                ]
            )

            Divider()

            GeneralOptionHelp(
                name: "Dither Strength",
                options: [
                    "0.0: No dithering effect",
                    "0.5: Subtle dithering (default for most systems)",
                    "1.0: Full dithering strength",
                    "Values > 1.0 may cause artifacts"
                ]
            )

            Divider()

            GeneralOptionHelp(
                name: "Contrast Enhancement",
                options: [
                    "None: No contrast adjustment",
                    "HE (Histogram Equalization): Global contrast stretch",
                    "CLAHE: Local adaptive contrast, good for photos",
                    "SWAHE: Sliding window adaptive, smooth results"
                ]
            )

            Divider()

            GeneralOptionHelp(
                name: "Color Matching",
                options: [
                    "Euclidean: Simple RGB distance, fast",
                    "Perceptive: Weighted for human perception, recommended",
                    "Luma: Prioritizes brightness matching",
                    "Chroma: Prioritizes color/saturation matching",
                    "Hue: Preserves color hue, best for saturated images",
                    "Mahalanobis: Statistical color distance"
                ]
            )

            Divider()

            GeneralOptionHelp(
                name: "Saturation",
                options: [
                    "1.0: Original saturation",
                    "1.1-1.2: Slight boost, recommended for most images",
                    "1.5+: Very saturated, may cause color clipping"
                ]
            )

            Divider()

            GeneralOptionHelp(
                name: "Gamma",
                options: [
                    "1.0: No gamma adjustment",
                    "< 1.0: Brightens midtones",
                    "> 1.0: Darkens midtones",
                    "0.8-1.2: Typical useful range"
                ]
            )
        }
    }
}

// MARK: - Filters Help

struct FiltersHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpHeader(title: "Preprocessing Filters", subtitle: "Apply before color conversion to improve results")

            FilterHelpSection(
                name: "Median",
                parameter: "Kernel Size",
                values: "3×3, 5×5, 7×7",
                description: "Removes noise while preserving edges. Replaces each pixel with the median value of neighboring pixels.",
                bestFor: "Noisy images, scanned photos, JPEG artifacts",
                tips: [
                    "3×3: Light noise reduction, preserves detail",
                    "5×5: Moderate smoothing, good for most noisy images",
                    "7×7: Strong smoothing, may lose fine detail"
                ]
            )

            FilterHelpSection(
                name: "Sharpen",
                parameter: "Sharpen Amount",
                values: "0.2 – 2.5",
                description: "Enhances edges and detail by increasing local contrast. Uses unsharp masking technique.",
                bestFor: "Soft or blurry images, enhancing texture detail",
                tips: [
                    "0.5: Subtle sharpening",
                    "1.0: Standard sharpening (default)",
                    "1.5–2.0: Strong sharpening for very soft images",
                    "Above 2.0: May create halos around edges"
                ]
            )

            FilterHelpSection(
                name: "Sigma",
                parameter: "Sigma Range",
                values: "5 – 50",
                description: "Edge-preserving blur that smooths similar pixels while maintaining sharp boundaries. Also known as bilateral filter.",
                bestFor: "Reducing color banding, smoothing gradients, noise reduction that preserves edges",
                tips: [
                    "10–15: Light smoothing, good for subtle noise",
                    "20–30: Moderate smoothing, balances detail and smoothness",
                    "40–50: Strong smoothing, good for heavily compressed images"
                ]
            )

            FilterHelpSection(
                name: "Solarize",
                parameter: "Threshold",
                values: "32 – 224",
                description: "Inverts tones above the threshold, creating a partial negative effect. Named after the darkroom technique.",
                bestFor: "Artistic effects, psychedelic looks, special image treatments",
                tips: [
                    "64: Inverts most of the image (only darkest tones preserved)",
                    "128: Inverts the brighter half (middle threshold)",
                    "192: Only inverts the brightest highlights"
                ]
            )

            FilterHelpSection(
                name: "Emboss",
                parameter: "Emboss Depth",
                values: "0.3 – 2.0",
                description: "Creates a raised, 3D relief effect by highlighting edges with directional lighting.",
                bestFor: "Artistic effects, texture visualization, creating metallic looks",
                tips: [
                    "0.5: Subtle emboss, light texture",
                    "1.0: Standard emboss effect",
                    "1.5–2.0: Deep emboss, very pronounced 3D effect"
                ]
            )

            FilterHelpSection(
                name: "Find Edges",
                parameter: "Edge Sensitivity",
                values: "10 – 100",
                description: "Detects and highlights edges using Sobel operator. Creates a line-art style output.",
                bestFor: "Line art extraction, edge detection visualization, artistic outlines",
                tips: [
                    "20–30: Detects many edges including subtle ones",
                    "50: Balanced edge detection (default)",
                    "70–100: Only detects strong, prominent edges"
                ]
            )

            FilterHelpSection(
                name: "Lowpass",
                parameter: "—",
                values: "No parameters",
                description: "Simple blur filter that smooths the image by averaging neighboring pixels.",
                bestFor: "Reducing high-frequency noise, softening harsh details before conversion",
                tips: [
                    "Apply before other processing for best noise reduction",
                    "Can help reduce dither artifacts in source images"
                ]
            )

            FilterHelpSection(
                name: "Edge",
                parameter: "—",
                values: "No parameters",
                description: "Sobel edge detection blended with original image. Enhances edges while preserving some original detail.",
                bestFor: "Increasing perceived sharpness, emphasizing outlines",
                tips: [
                    "Different from Find Edges - this blends with original",
                    "Good for images that appear flat or lack definition"
                ]
            )
        }
    }
}

// MARK: - Helper Views

struct HelpHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 8)
    }
}

struct ModeHelpSection: View {
    let title: String
    let fileFormat: String
    let description: String
    let bestFor: String
    let options: [OptionHelp]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(fileFormat)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
            }

            Text(description)
                .foregroundColor(.secondary)

            HStack(alignment: .top) {
                Text("Best for:")
                    .fontWeight(.medium)
                Text(bestFor)
                    .foregroundColor(.secondary)
            }

            if !options.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Options:")
                        .fontWeight(.medium)
                    ForEach(options, id: \.name) { opt in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(opt.name)
                                    .fontWeight(.medium)
                                Text(opt.description)
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.leading, 8)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct OptionHelp: Hashable {
    let name: String
    let description: String
}

struct GeneralOptionHelp: View {
    let name: String
    let options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.headline)
            ForEach(options, id: \.self) { opt in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text(opt)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct FileFormatHelp: View {
    let extension_: String
    let name: String
    let size: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(extension_)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .fontWeight(.medium)
                    Text("(\(size))")
                        .foregroundColor(.secondary)
                }
                Text(description)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct FilterHelpSection: View {
    let name: String
    let parameter: String
    let values: String
    let description: String
    let bestFor: String
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(name)
                    .font(.headline)
                Spacer()
                if parameter != "—" {
                    HStack(spacing: 4) {
                        Text(parameter + ":")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(values)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
                }
            }

            Text(description)
                .foregroundColor(.secondary)

            HStack(alignment: .top) {
                Text("Best for:")
                    .fontWeight(.medium)
                Text(bestFor)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Tips:")
                    .fontWeight(.medium)
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.accentColor)
                        Text(tip)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 8)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    HelpView()
}
