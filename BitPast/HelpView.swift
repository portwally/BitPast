import SwiftUI

enum HelpSection: String, CaseIterable, Identifiable {
    case appleII = "Apple II"
    case appleIIgs = "Apple IIgs"
    case c64 = "Commodore 64"
    case vic20 = "VIC-20"
    case zxSpectrum = "ZX Spectrum"
    case amstradCPC = "Amstrad CPC"
    case plus4 = "Plus/4"
    case atariST = "Atari ST"
    case amiga500 = "Amiga 500"
    case amiga1200 = "Amiga 1200"
    case pc = "PC"
    case generalOptions = "General Options"
    case filters = "Preprocessing Filters"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .appleII: return "desktopcomputer"
        case .appleIIgs: return "desktopcomputer"
        case .c64: return "tv"
        case .vic20: return "tv"
        case .zxSpectrum: return "tv"
        case .amstradCPC: return "tv"
        case .plus4: return "tv"
        case .atariST: return "desktopcomputer"
        case .amiga500: return "desktopcomputer"
        case .amiga1200: return "desktopcomputer"
        case .pc: return "desktopcomputer"
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
                    ForEach([HelpSection.appleII, .appleIIgs, .c64, .vic20, .zxSpectrum, .amstradCPC, .plus4, .atariST, .amiga500, .amiga1200, .pc], id: \.self) { section in
                        Label(section.rawValue, systemImage: section.iconName)
                            .tag(section)
                    }
                }

                Section("Reference") {
                    ForEach([HelpSection.generalOptions, .filters], id: \.self) { section in
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
        case .atariST:
            AtariSTHelpContent()
        case .amiga500:
            Amiga500HelpContent()
        case .amiga1200:
            Amiga1200HelpContent()
        case .pc:
            PCHelpContent()
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
                description: "Enhanced Graphics Adapter mode with 16 colors selected from the 64-color EGA palette. Popular from 1984-1990.",
                bestFor: "DOS game graphics, Sierra adventure games aesthetic",
                options: [
                    OptionHelp(name: "Dithering", description: "Ordered dithering (Bayer) often produces good results. 16 colors allow reasonable color reproduction."),
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
                    "Ordered (Bayer): Pattern-based, good for animations, no crawling",
                    "Blue Noise: Random-looking dither with pleasing texture",
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
