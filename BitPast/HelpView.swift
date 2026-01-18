import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("BitPast Graphics Mode Guide")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Understanding Apple IIgs display modes and conversion options")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)

                Divider()

                // Apple IIgs Modes
                VStack(alignment: .leading, spacing: 16) {
                    Text("Apple IIgs Display Modes")
                        .font(.title2)
                        .fontWeight(.semibold)

                    // 3200 Colors (Brooks)
                    ModeHelpSection(
                        title: "3200 Colors (Brooks)",
                        fileFormat: ".3200 (38,400 bytes)",
                        description: "True 3200-color mode using the Brooks format. Each of the 200 scanlines has its own independent 16-color palette, allowing up to 3,200 unique colors on screen.",
                        bestFor: "Photographic images, gradients, images with many colors",
                        options: [
                            OptionHelp(name: "Palette Merge Tolerance", description: "Controls palette reuse between similar scanlines. Higher values reduce banding but may lose color accuracy. Set to 0 for maximum color fidelity, 10-20 for balanced results, up to 50 for smoother transitions."),
                            OptionHelp(name: "Dithering", description: "All dithering algorithms work well. Floyd-Steinberg is recommended for photos."),
                            OptionHelp(name: "Saturation Boost", description: "Increase to compensate for the IIgs's somewhat muted palette.")
                        ]
                    )

                    Divider()

                    // 256 Colors
                    ModeHelpSection(
                        title: "256 Colors (16 Palettes)",
                        fileFormat: ".SHR (32,768 bytes)",
                        description: "Standard SHR format with 16 palette slots. Scanlines are grouped and share palettes. Maximum 256 unique colors (16 palettes × 16 colors).",
                        bestFor: "Compatibility with standard SHR viewers, when file size matters",
                        options: [
                            OptionHelp(name: "3200 Quantization", description: "Per-Scanline: Groups consecutive scanlines into 16 slots. Palette Reuse: Tries to reuse palettes between similar scanlines for smoother results."),
                            OptionHelp(name: "Palette Merge Tolerance", description: "Only visible with 'Palette Reuse' quantization. Controls how similar scanlines must be to share a palette.")
                        ]
                    )

                    Divider()

                    // 320x200 (16 Colors)
                    ModeHelpSection(
                        title: "320x200 (16 Colors)",
                        fileFormat: ".SHR (32,768 bytes)",
                        description: "Standard Super Hi-Res mode with a single 16-color palette for the entire image. Classic IIgs graphics mode.",
                        bestFor: "Simple graphics, logos, images with limited color range",
                        options: [
                            OptionHelp(name: "Dithering", description: "Essential for this mode. Atkinson gives a classic Mac look, Floyd-Steinberg for smoother results.")
                        ]
                    )

                    Divider()

                    // 640x200 (4 Colors)
                    ModeHelpSection(
                        title: "640x200 (4 Colors)",
                        fileFormat: ".SHR (32,768 bytes)",
                        description: "High-resolution mode with 640 horizontal pixels but only 4 colors. Good for text and line art.",
                        bestFor: "Screenshots, text-heavy images, technical drawings",
                        options: [
                            OptionHelp(name: "Dithering", description: "Ordered (Bayer) dithering works well for this mode to avoid artifacts.")
                        ]
                    )

                    Divider()

                    // 640x200 Enhanced
                    ModeHelpSection(
                        title: "640x200 Enhanced (16 Colors)",
                        fileFormat: ".SHR (32,768 bytes)",
                        description: "Enhanced 640 mode using column-aware dithering. Even columns use one 4-color sub-palette, odd columns use another, for 8 effective colors with better color range.",
                        bestFor: "Higher resolution images that need more color variety than standard 640 mode",
                        options: [
                            OptionHelp(name: "Dithering", description: "Floyd-Steinberg recommended for best results.")
                        ]
                    )

                    Divider()

                    // 640x200 Desktop
                    ModeHelpSection(
                        title: "640x200 Desktop (16 Colors)",
                        fileFormat: ".SHR (32,768 bytes)",
                        description: "Uses the GS/OS Finder palette with column-aware dithering. Even columns: Black, Blue, Yellow, White. Odd columns: Black, Red, Green, White.",
                        bestFor: "Images that should match the GS/OS desktop aesthetic",
                        options: [
                            OptionHelp(name: "Dithering", description: "All algorithms work, but results will be limited to the fixed Finder palette.")
                        ]
                    )
                }

                Divider()

                // General Options
                VStack(alignment: .leading, spacing: 16) {
                    Text("General Options")
                        .font(.title2)
                        .fontWeight(.semibold)

                    GeneralOptionHelp(
                        name: "Dithering Algorithm",
                        options: [
                            "Floyd-Steinberg: Classic error diffusion, good all-around choice",
                            "Atkinson: Less error diffusion, gives a classic Macintosh look",
                            "Jarvis-Judice-Ninke: Spreads error further, smoother gradients",
                            "Stucki: Similar to JJN, slightly different character",
                            "Burkes: Faster variant of Stucki",
                            "Ordered (Bayer 4x4): Pattern-based, good for animations",
                            "None: No dithering, direct color mapping"
                        ]
                    )

                    GeneralOptionHelp(
                        name: "Dither Strength",
                        options: [
                            "0.0: No dithering effect",
                            "0.5: Subtle dithering",
                            "1.0: Full dithering (default)",
                            "Values > 1.0 may cause artifacts"
                        ]
                    )

                    GeneralOptionHelp(
                        name: "Saturation Boost",
                        options: [
                            "1.0: Original saturation",
                            "1.1-1.2: Recommended for most images",
                            "1.5+: Very saturated, may cause clipping"
                        ]
                    )
                }

                Divider()

                // File Formats
                VStack(alignment: .leading, spacing: 16) {
                    Text("Output File Formats")
                        .font(.title2)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 12) {
                        FileFormatHelp(
                            extension_: ".3200",
                            name: "Brooks Format",
                            size: "38,400 bytes",
                            description: "True 3200-color format with 200 palettes. Compatible with Convert3200, DreamGrafix, and emulators that support this format."
                        )

                        FileFormatHelp(
                            extension_: ".SHR",
                            name: "Standard Super Hi-Res",
                            size: "32,768 bytes",
                            description: "Standard Apple IIgs SHR format with 16 palette slots. Compatible with all SHR viewers and paint programs."
                        )
                    }
                }

                Divider()

                // Quick Reference
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Reference")
                        .font(.title2)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recommended Settings by Image Type:")
                            .font(.headline)

                        QuickRefRow(imageType: "Photographs", mode: "3200 Colors (Brooks)", dither: "Floyd-Steinberg", notes: "Tolerance 10-15")
                        QuickRefRow(imageType: "Pixel Art", mode: "320x200 (16 Colors)", dither: "None", notes: "Or Ordered for larger palettes")
                        QuickRefRow(imageType: "Screenshots", mode: "640x200 (4 Colors)", dither: "Ordered", notes: "Best for text")
                        QuickRefRow(imageType: "Gradients", mode: "3200 Colors (Brooks)", dither: "Jarvis-Judice-Ninke", notes: "Tolerance 0-5")
                        QuickRefRow(imageType: "Logos", mode: "320x200 (16 Colors)", dither: "Atkinson", notes: "Classic look")
                    }
                    .font(.system(.body, design: .monospaced))
                }

                Spacer(minLength: 20)
            }
            .padding(30)
        }
        .frame(minWidth: 700, minHeight: 600)
    }
}

// MARK: - Helper Views

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
    }
}

struct QuickRefRow: View {
    let imageType: String
    let mode: String
    let dither: String
    let notes: String

    var body: some View {
        HStack(spacing: 0) {
            Text(imageType)
                .frame(width: 100, alignment: .leading)
            Text(mode)
                .frame(width: 200, alignment: .leading)
                .foregroundColor(.accentColor)
            Text(dither)
                .frame(width: 150, alignment: .leading)
            Text(notes)
                .foregroundColor(.secondary)
        }
        .font(.system(.caption, design: .monospaced))
    }
}

#Preview {
    HelpView()
}
