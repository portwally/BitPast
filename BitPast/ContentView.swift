import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel = ConverterViewModel.shared
    @ObservedObject var settings = AppSettings.shared
    @State var isDropTarget = false
    @State var zoomLevel: CGFloat = 1.0

    // Create Disk Sheet State
    @State var showDiskSheet = false
    @State var selectedDiskSystemIndex: Int = 0
    @State var diskConfiguration = DiskConfiguration(system: .appleII)

    // Palette Editor State
    @State var editablePalettes: [[PaletteColor]] = []

    // Image Tools State
    @State var showHistogram = false

    let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    // Layout Konstante: Von 190 auf 195 erhöht (+5px)
    let sideColumnWidth: CGFloat = 195

    // Keys für die Anzeige
    // Control groups for vertical pairing layout
    // Each group: [dropdown(s), slider(s)] displayed vertically
    let controlGroups: [[String]] = [
        ["mode", "resolution", "quantization_method", "threshold"],  // Mode + 3200-specific options
        ["dither", "error_matrix", "dither_amount"],  // Dithering controls
        ["palette"],                          // Palette selection
        ["preprocess", "median_size", "sharpen_strength", "sigma_range", "solarize_threshold", "emboss_depth", "edge_threshold"], // Preprocessing filter + filter-specific params
        ["contrast", "filter"],               // C64: Contrast + Filter
        ["pixel_merge", "color_match"],       // C64: Pixel merge + Color matching
        ["saturation"],                       // Saturation adjustment
        ["gamma"],                            // Gamma correction
        ["crosshatch", "z_threshold"]         // Crosshatch pattern
    ]

    // Retro mode helpers
    var isRetro: Bool { settings.isRetroMode }
    var isAppleIIgs: Bool { settings.isAppleIIgsMode }
    var isAppleII: Bool { settings.isAppleIIMode }
    var isC64: Bool { settings.isC64Mode }

    // Theme-aware fonts
    var retroFont: Font {
        if isC64 { return C64Theme.font(size: 14) }
        if isAppleII { return AppleIITheme.font(size: 14) }
        return RetroTheme.font(size: 12)
    }
    var retroSmallFont: Font {
        if isC64 { return C64Theme.font(size: 12) }
        if isAppleII { return AppleIITheme.font(size: 12) }
        return RetroTheme.font(size: 11)
    }
    var retroBoldFont: Font {
        if isC64 { return C64Theme.boldFont(size: 14) }
        if isAppleII { return AppleIITheme.boldFont(size: 14) }
        return RetroTheme.boldFont(size: 13)
    }

    // Theme-aware colors
    var retroBgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        return RetroTheme.contentGray
    }
    var retroTextColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return RetroTheme.textColor
    }
    var retroBorderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        return RetroTheme.borderColor
    }
    var retroWindowBg: Color {
        if isC64 { return C64Theme.windowBackground }
        if isAppleII { return AppleIITheme.windowBackground }
        return RetroTheme.windowBackground
    }

    var body: some View {
        if isAppleIIgs {
            // GS/OS Window Frame wrapper for Apple IIgs mode
            GSOSWindowFrame(
                title: "BitPast",
                infoText: "Blast from the Past  •  \(viewModel.inputImages.count) images"
            ) {
                mainContent
            }
            .frame(minWidth: 1000, minHeight: 650)
            .id(settings.appearanceMode)
        } else if isAppleII {
            // Apple II Green Phosphor mode
            AppleIIWindowFrame(
                title: "BITPAST",
                infoText: "\(viewModel.inputImages.count) IMAGES LOADED"
            ) {
                mainContent
            }
            .frame(minWidth: 1000, minHeight: 650)
            .id(settings.appearanceMode)
        } else if isC64 {
            // Commodore 64 mode
            C64WindowFrame(
                title: "BITPAST",
                infoText: "\(viewModel.inputImages.count) IMAGES"
            ) {
                mainContent
            }
            .frame(minWidth: 1000, minHeight: 650)
            .id(settings.appearanceMode)
        } else {
            mainContent
                .frame(minWidth: 1000, minHeight: 650)
                .background(Color(NSColor.windowBackgroundColor))
                .id(settings.appearanceMode)
        }
    }

    @ViewBuilder
    var mainContent: some View {
        VStack(spacing: 0) {

            // 0. SYSTEM BAR (Horizontal at top)
            HorizontalSystemBar(viewModel: viewModel, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                .padding(.bottom, 4)

            if isRetro {
                Rectangle().fill(retroBorderColor).frame(height: isAppleII ? AppleIITheme.dividerThickness : (isC64 ? C64Theme.dividerThickness : RetroTheme.dividerThickness))
            } else {
                Divider()
            }

            // 1. OBERER BEREICH: SPLIT VIEW
            HSplitView {
                // LINKER BEREICH: IMAGE BROWSER
                imageBrowserPane

                // RECHTER BEREICH: VORSCHAU
                previewPane
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 2. UNTERER BEREICH: FIXED HEIGHT
            bottomPanel

        }
        .background(isRetro ? retroBgColor : Color(NSColor.windowBackgroundColor))
        .overlay {
            // Disk creation progress overlay
            if viewModel.isDiskCreating {
                DiskProgressOverlay(
                    progress: viewModel.diskCreationProgress,
                    current: viewModel.diskCreationCurrent,
                    total: viewModel.diskCreationTotal,
                    status: viewModel.diskCreationStatus,
                    isRetro: isRetro,
                    isAppleII: isAppleII,
                    isC64: isC64
                )
            }
        }
    }
}
