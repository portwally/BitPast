import SwiftUI
import UniformTypeIdentifiers

// Helper class for managing the floating palette editor window
class PaletteEditorWindowController {
    static let shared = PaletteEditorWindowController()
    private var window: NSWindow?

    func openWindow(palettes: Binding<[[PaletteColor]]>, onApply: @escaping ([[PaletteColor]]) -> Void) {
        // Close existing window if open
        window?.close()

        // Create binding for isPresented that closes the window
        let isPresented = Binding<Bool>(
            get: { self.window != nil },
            set: { if !$0 { self.closeWindow() } }
        )

        let editorView = PaletteEditorView(
            isPresented: isPresented,
            palettes: palettes,
            onApply: onApply
        )

        let hostingView = NSHostingView(rootView: editorView)

        let newWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 550),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Palette Editor"
        newWindow.contentView = hostingView
        newWindow.isFloatingPanel = true
        newWindow.becomesKeyOnlyIfNeeded = true
        newWindow.level = .floating
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)

        self.window = newWindow
    }

    func closeWindow() {
        window?.close()
        window = nil
    }
}

struct ContentView: View {
    @ObservedObject private var viewModel = ConverterViewModel.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var isDropTarget = false
    @State private var zoomLevel: CGFloat = 1.0

    // Create Disk Sheet State
    @State private var showDiskSheet = false
    @State private var selectedDiskSystemIndex: Int = 0
    @State private var diskConfiguration = DiskConfiguration(system: .appleII)

    // Palette Editor State
    @State private var editablePalettes: [[PaletteColor]] = []

    // Image Tools State
    @State private var showHistogram = false

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
                VStack(spacing: 0) {
                    HStack {
                        Text("Image Browser")
                            .font(isRetro ? retroBoldFont : .system(size: 13, weight: .semibold))
                            .foregroundColor(isRetro ? retroTextColor : .secondary)
                        Spacer()
                        // Select all checkbox
                        if !viewModel.inputImages.isEmpty {
                            Button(action: { viewModel.toggleSelectAll() }) {
                                Image(systemName: viewModel.allImagesSelected ? "checkmark.square.fill" :
                                      (viewModel.someImagesSelected ? "minus.square.fill" : "square"))
                                    .foregroundStyle(isRetro ? retroTextColor : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help(viewModel.allImagesSelected ? "Deselect all" : "Select all")
                        }
                        if !viewModel.selectedImageIds.isEmpty {
                            Button(action: { viewModel.removeSelectedImages() }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(isRetro ? retroTextColor : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove selected images (\(viewModel.selectedImageIds.count))")
                        } else if viewModel.selectedImageId != nil {
                            Button(action: { viewModel.removeSelectedImage() }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(isRetro ? retroTextColor : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove selected image")
                        }
                        Button(action: { viewModel.selectImagesFromFinder() }) {
                            if isRetro {
                                Text("+")
                                    .font(retroBoldFont)
                                    .foregroundColor(retroTextColor)
                                    .frame(width: 28, height: 22)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(retroTextColor, lineWidth: 1)
                                    )
                            } else {
                                Text("+")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(width: 28, height: 22)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Add images")
                    }
                    .frame(height: 38)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(isRetro ? retroWindowBg : Color(NSColor.controlBackgroundColor).opacity(0.5))

                    if isRetro {
                        Rectangle().fill(retroBorderColor).frame(height: isAppleII ? AppleIITheme.dividerThickness : RetroTheme.dividerThickness)
                    } else {
                        Divider()
                    }

                    if viewModel.inputImages.isEmpty {
                        ZStack {
                            isRetro ? retroBgColor : Color(NSColor.controlBackgroundColor).opacity(0.3)
                            VStack(spacing: 16) {
                                if isRetro {
                                    // Retro ASCII-style icon
                                    VStack(spacing: 0) {
                                        Text("+--------+")
                                        Text("|  IMG   |")
                                        Text("|  IMG   |")
                                        Text("+--------+")
                                    }
                                    .font(retroFont)
                                    .foregroundColor(retroTextColor.opacity(0.6))
                                } else {
                                    Image(systemName: "photo.stack")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 64, height: 64)
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                                }
                                Text("Drag Images Here")
                                    .font(isRetro ? retroBoldFont : .title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(isRetro ? retroTextColor : .secondary)
                                Text("or click + to add")
                                    .font(isRetro ? retroSmallFont : .subheadline)
                                    .foregroundColor(isRetro ? retroTextColor.opacity(0.7) : Color(NSColor.tertiaryLabelColor))
                            }
                            .padding()
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(viewModel.inputImages) { item in
                                    ImageGridItem(
                                        item: item,
                                        isSelected: viewModel.selectedImageId == item.id,
                                        isMultiSelected: viewModel.selectedImageIds.contains(item.id),
                                        isRetro: isRetro,
                                        isAppleII: isAppleII,
                                        onToggleSelection: {
                                            viewModel.toggleImageSelection(item.id)
                                        }
                                    )
                                    .onTapGesture {
                                        viewModel.selectedImageId = item.id
                                        viewModel.lastClickedIndex = viewModel.inputImages.firstIndex(where: { $0.id == item.id })
                                        viewModel.convertImmediately()
                                    }
                                    .gesture(TapGesture().modifiers(.shift).onEnded {
                                        viewModel.selectRange(to: item.id)
                                    })
                                }
                            }.padding(10)
                        }.background(isRetro ? retroBgColor : Color(NSColor.controlBackgroundColor))
                    }
                }
                .frame(minWidth: 200, maxWidth: 450)
                .onDrop(of: [.fileURL], isTargeted: $isDropTarget) { providers in return viewModel.handleDrop(providers: providers) }
                .overlay(
                    Group {
                        if viewModel.isBatchExporting {
                            ZStack {
                                Color.black.opacity(0.6)
                                VStack(spacing: 16) {
                                    ProgressView(value: viewModel.batchExportProgress)
                                        .progressViewStyle(.linear)
                                        .frame(width: 200)
                                    Text("Exporting \(viewModel.batchExportCurrent)/\(viewModel.batchExportTotal)...")
                                        .font(isRetro ? retroSmallFont : .caption)
                                        .foregroundColor(.white)
                                }
                                .padding(24)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(NSColor.windowBackgroundColor))
                                )
                            }
                        }
                    }
                )

                // RECHTER BEREICH: VORSCHAU
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Text("Preview")
                            .font(isRetro ? retroBoldFont : .system(size: 13, weight: .semibold))
                            .foregroundColor(isRetro ? retroTextColor : .secondary)

                        Spacer()

                        // Image Tools Toolbar
                        HStack(spacing: 8) {
                            // Edit Palette (Apple IIgs only)
                            if viewModel.selectedMachineIndex == 1 {
                                ToolbarButton(
                                    icon: "paintpalette",
                                    label: "Palette",
                                    isRetro: isRetro,
                                    isAppleII: isAppleII,
                                    isC64: isC64,
                                    disabled: viewModel.currentResult?.palettes.isEmpty ?? true
                                ) {
                                    openPaletteEditor()
                                }
                            }

                            // Horizontal Flip
                            ToolbarButton(
                                icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                                label: "H-Flip",
                                isRetro: isRetro,
                                isAppleII: isAppleII,
                                isC64: isC64,
                                disabled: viewModel.convertedImage == nil
                            ) {
                                flipImageHorizontally()
                            }

                            // Vertical Flip
                            ToolbarButton(
                                icon: "arrow.up.and.down.righttriangle.up.righttriangle.down",
                                label: "V-Flip",
                                isRetro: isRetro,
                                isAppleII: isAppleII,
                                isC64: isC64,
                                disabled: viewModel.convertedImage == nil
                            ) {
                                flipImageVertically()
                            }

                            // Histogram
                            ToolbarButton(
                                icon: "chart.bar",
                                label: "Histogram",
                                isRetro: isRetro,
                                isAppleII: isAppleII,
                                isC64: isC64,
                                disabled: viewModel.convertedImage == nil,
                                isActive: showHistogram
                            ) {
                                showHistogram.toggle()
                            }
                        }

                        // Divider between tools and zoom
                        if !isRetro {
                            Divider()
                                .frame(height: 24)
                        }

                        // Zoom Controls
                        HStack(spacing: 6) {
                            Button(action: { if zoomLevel > 0.2 { zoomLevel -= 0.2 } }) {
                                if isRetro {
                                    Text("-")
                                        .font(retroBoldFont)
                                        .foregroundColor(retroTextColor)
                                        .frame(width: 24)
                                } else {
                                    Image(systemName: "minus.magnifyingglass")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .help("Zoom out")

                            Text("\(Int(zoomLevel * 100))%")
                                .monospacedDigit()
                                .font(isRetro ? retroSmallFont : .system(size: 12))
                                .foregroundColor(isRetro ? retroTextColor : .secondary)
                                .frame(width: 50)

                            Button(action: { if zoomLevel < 5.0 { zoomLevel += 0.2 } }) {
                                if isRetro {
                                    Text("+")
                                        .font(retroBoldFont)
                                        .foregroundColor(retroTextColor)
                                        .frame(width: 24)
                                } else {
                                    Image(systemName: "plus.magnifyingglass")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .help("Zoom in")
                        }
                    }
                    .frame(height: 38)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(isRetro ? retroWindowBg : Color(NSColor.controlBackgroundColor).opacity(0.5))

                    if isRetro {
                        Rectangle().fill(retroBorderColor).frame(height: isAppleII ? AppleIITheme.dividerThickness : RetroTheme.dividerThickness)
                    } else {
                        Divider()
                    }

                    GeometryReader { geometry in
                        ZStack {
                            Color(NSColor.black)
                            if let img = viewModel.convertedImage {
                                // Apply aspect ratio correction for 640x200 mode (IIgs 640 mode has non-square pixels)
                                let aspectCorrection: CGFloat = (img.size.width == 640 && img.size.height == 200) ? 2.0 : 1.0
                                let displayHeight = img.size.height * aspectCorrection

                                let fitScale = min(
                                    geometry.size.width / img.size.width,
                                    geometry.size.height / displayHeight
                                )
                                let effectiveZoom = zoomLevel == 1.0 ? fitScale : zoomLevel

                                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                                    Image(nsImage: img)
                                        .resizable()
                                        .interpolation(.none)
                                        .frame(
                                            width: img.size.width * effectiveZoom,
                                            height: displayHeight * effectiveZoom
                                        )
                                        .shadow(color: .black.opacity(0.3), radius: 10)
                                        .frame(
                                            minWidth: geometry.size.width,
                                            minHeight: geometry.size.height
                                        )
                                }
                            } else if viewModel.isConverting {
                                VStack(spacing: 12) {
                                    if isRetro {
                                        Text("[ ... ]")
                                            .font(retroBoldFont)
                                            .foregroundColor(isAppleII ? AppleIITheme.textColor : .white.opacity(0.8))
                                    } else {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                    }
                                    Text("Converting...")
                                        .font(isRetro ? retroSmallFont : .subheadline)
                                        .foregroundColor(isAppleII ? AppleIITheme.textColor : .white.opacity(0.8))
                                }
                            } else {
                                VStack(spacing: 12) {
                                    if isRetro {
                                        // Retro ASCII-style icon
                                        VStack(spacing: 0) {
                                            Text("+--------+")
                                            Text("|   ?    |")
                                            Text("|   v    |")
                                            Text("+--------+")
                                        }
                                        .font(retroFont)
                                        .foregroundColor(isAppleII ? AppleIITheme.dimTextColor : .white.opacity(0.4))
                                    } else {
                                        Image(systemName: "photo.badge.arrow.down")
                                            .font(.system(size: 48))
                                            .symbolRenderingMode(.hierarchical)
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                    Text("Select an image to preview")
                                        .font(isRetro ? retroSmallFont : .subheadline)
                                        .foregroundColor(isAppleII ? AppleIITheme.dimTextColor : .white.opacity(0.5))
                                }
                            }

                            // Histogram Overlay (top-right corner)
                            VStack {
                                HStack {
                                    Spacer()
                                    HistogramOverlay(image: viewModel.convertedImage, isShowing: $showHistogram, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                                }
                                Spacer()
                            }
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }.frame(minWidth: 350)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 2. UNTERER BEREICH: FIXED HEIGHT
            ZStack(alignment: .top) {
                // Main content
                VStack(spacing: 0) {
                    if let error = viewModel.errorMessage {
                        // Error bar (below the horizontal divider)
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .padding(.top, isRetro ? RetroTheme.dividerThickness : 1) // Space for horizontal divider
                        .background(Color.orange.opacity(0.1))
                        .overlay(alignment: .bottom) {
                            Divider()
                        }
                    }

                    HStack(spacing: 0) {

                    // A. LINKS: IMAGE INFO (Feste Breite, Symmetrisch zu Rechts)
                    ImageInfoPanel(viewModel: viewModel, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                        .padding(12)
                        .frame(width: sideColumnWidth)
                        .background(isRetro ? retroWindowBg : Color(NSColor.controlBackgroundColor).opacity(0.5))

                    // Vertical divider after IMAGE INFO
                    if isRetro {
                        let dividerThickness: CGFloat = isC64 ? C64Theme.dividerThickness : (isAppleII ? AppleIITheme.dividerThickness : RetroTheme.dividerThickness)
                        let bottomPadding: CGFloat = (isAppleII || isC64) ? 10 : 0
                        Rectangle().fill(retroBorderColor).frame(width: dividerThickness)
                            .padding(.bottom, bottomPadding)
                    } else {
                        Rectangle().fill(Color(NSColor.separatorColor)).frame(width: 1)
                    }

                    // B. MITTE: SLIDER (Scrollbar) - Vertical Groups Layout
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 20) {
                            ForEach(controlGroups.indices, id: \.self) { groupIndex in
                                let group = controlGroups[groupIndex]

                                // Filter out invisible controls for this group
                                let visibleControls = group.filter { key in
                                    // Check visibility conditions
                                    let modeOption = viewModel.currentMachine.options.first(where: { $0.key == "mode" })
                                    let quantOption = viewModel.currentMachine.options.first(where: { $0.key == "quantization_method" })
                                    let preprocessOption = viewModel.currentMachine.options.first(where: { $0.key == "preprocess" })
                                    let selectedFilter = preprocessOption?.selectedValue ?? "None"
                                    let is3200Brooks = modeOption?.selectedValue.contains("3200 Colors") == true
                                    let is256WithReuse = modeOption?.selectedValue.contains("256 Colors") == true && quantOption?.selectedValue.contains("Reuse") == true

                                    // Show quantization ONLY in 3200 mode
                                    if key == "quantization_method" && !is3200Brooks { return false }
                                    // Hide threshold unless 3200 or 256+Reuse
                                    if key == "threshold" && !(is3200Brooks || is256WithReuse) { return false }

                                    // Filter-specific parameter visibility
                                    if key == "median_size" && selectedFilter != "Median" { return false }
                                    if key == "sharpen_strength" && selectedFilter != "Sharpen" { return false }
                                    if key == "sigma_range" && selectedFilter != "Sigma" { return false }
                                    if key == "solarize_threshold" && selectedFilter != "Solarize" { return false }
                                    if key == "emboss_depth" && selectedFilter != "Emboss" { return false }
                                    if key == "edge_threshold" && selectedFilter != "Find Edges" { return false }

                                    // Pixel Merge only visible in modes that use it (Mode 0 for CPC, Multicolor/LowRes for C64/VIC-20)
                                    if key == "pixel_merge" {
                                        let mode = modeOption?.selectedValue ?? ""
                                        let isPixelMergeMode = mode.contains("Mode 0") || mode.contains("Multicolor") || mode.contains("LowRes")
                                        if !isPixelMergeMode { return false }
                                    }

                                    return viewModel.currentMachine.options.contains(where: { $0.key == key })
                                }

                                if !visibleControls.isEmpty {
                                    VStack(alignment: .center, spacing: 8) {
                                        ForEach(visibleControls, id: \.self) { key in
                                            if let optIndex = viewModel.currentMachine.options.firstIndex(where: { $0.key == key }) {
                                                let opt = viewModel.currentMachine.options[optIndex]
                                                ControlView(opt: opt, index: optIndex, viewModel: viewModel, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: isRetro ? 0 : 8)
                                            .fill(isRetro ? retroBgColor.opacity(0.3) : Color(NSColor.controlBackgroundColor).opacity(0.3))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: isRetro ? 0 : 8)
                                            .stroke(isRetro ? retroBorderColor.opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(minWidth: 300, maxWidth: .infinity)
                    }
                    .background(isRetro ? retroBgColor : Color.clear)

                    // Vertical divider before ACTIONS
                    if isRetro {
                        let dividerThickness: CGFloat = isC64 ? C64Theme.dividerThickness : (isAppleII ? AppleIITheme.dividerThickness : RetroTheme.dividerThickness)
                        // Bottom padding to align with bottom border
                        let bottomPadding: CGFloat = (isAppleII || isC64) ? 10 : 0
                        Rectangle().fill(retroBorderColor).frame(width: dividerThickness)
                            .padding(.bottom, bottomPadding)
                    } else {
                        Rectangle().fill(Color(NSColor.separatorColor)).frame(width: 1)
                    }

                    // C. RECHTS: ACTIONS (Feste Breite, Symmetrisch zu Links)
                    VStack(spacing: 12) {
                        Text("ACTIONS")
                            .font(isRetro ? retroSmallFont : .system(size: 11, weight: .semibold))
                            .foregroundColor(isRetro ? retroTextColor : .secondary)
                            .tracking(0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if isRetro {
                            // Retro-styled Save Menu
                            RetroActionMenu(
                                title: viewModel.selectedImageIds.isEmpty ? "Save Image..." : "Save \(viewModel.selectedImageIds.count) Images...",
                                isAppleII: isAppleII,
                                isC64: isC64,
                                isDisabled: viewModel.selectedImageIds.isEmpty && viewModel.convertedImage == nil,
                                menuItems: {
                                    if viewModel.selectedImageIds.isEmpty {
                                        Button("PNG") { viewModel.saveImage(as: .png) }
                                        Button("JPG") { viewModel.saveImage(as: .jpg) }
                                        Button("GIF") { viewModel.saveImage(as: .gif) }
                                        Button("TIFF") { viewModel.saveImage(as: .tiff) }
                                        Divider()
                                        if let asset = viewModel.currentResult?.fileAssets.first {
                                            let ext = asset.pathExtension.uppercased()
                                            Button("Native Format (.\(ext))") { viewModel.saveNativeFile() }
                                        } else {
                                            Button("Native Format") { }.disabled(true)
                                        }
                                    } else {
                                        Button("PNG") { viewModel.batchSaveImages(as: .png) }
                                        Button("JPG") { viewModel.batchSaveImages(as: .jpg) }
                                        Button("GIF") { viewModel.batchSaveImages(as: .gif) }
                                        Button("TIFF") { viewModel.batchSaveImages(as: .tiff) }
                                        Divider()
                                        Button("Native Format") { viewModel.batchSaveNativeFiles() }
                                    }
                                }
                            )

                            // Retro-styled Create Disk Button
                            RetroActionButton(
                                title: "Create Disk",
                                isAppleII: isAppleII,
                                isC64: isC64,
                                isDisabled: viewModel.convertedImage == nil
                            ) {
                                // Pre-select current system
                                selectedDiskSystemIndex = viewModel.selectedMachineIndex
                                if let system = DiskSystem(rawValue: viewModel.selectedMachineIndex) {
                                    diskConfiguration = DiskConfiguration(system: system)
                                }
                                showDiskSheet = true
                            }
                            .sheet(isPresented: $showDiskSheet) {
                                CreateDiskSheet(
                                    isPresented: $showDiskSheet,
                                    selectedSystemIndex: $selectedDiskSystemIndex,
                                    viewModel: viewModel
                                ) { config in
                                    viewModel.createDiskImage(configuration: config)
                                }
                            }
                        } else {
                            // Standard macOS buttons
                            Menu {
                                if viewModel.selectedImageIds.isEmpty {
                                    Button("PNG") { viewModel.saveImage(as: .png) }
                                    Button("JPG") { viewModel.saveImage(as: .jpg) }
                                    Button("GIF") { viewModel.saveImage(as: .gif) }
                                    Button("TIFF") { viewModel.saveImage(as: .tiff) }
                                    Divider()
                                    if let asset = viewModel.currentResult?.fileAssets.first {
                                        let ext = asset.pathExtension.uppercased()
                                        Button("Native Format (.\(ext))") { viewModel.saveNativeFile() }
                                    } else {
                                        Button("Native Format") { }.disabled(true)
                                    }
                                } else {
                                    Button("PNG") { viewModel.batchSaveImages(as: .png) }
                                    Button("JPG") { viewModel.batchSaveImages(as: .jpg) }
                                    Button("GIF") { viewModel.batchSaveImages(as: .gif) }
                                    Button("TIFF") { viewModel.batchSaveImages(as: .tiff) }
                                    Divider()
                                    Button("Native Format") { viewModel.batchSaveNativeFiles() }
                                }
                            } label: {
                                Label(viewModel.selectedImageIds.isEmpty ? "Save Image..." : "Save \(viewModel.selectedImageIds.count) Images...", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                            .menuStyle(.borderedButton)
                            .controlSize(.regular)
                            .disabled(viewModel.selectedImageIds.isEmpty && viewModel.convertedImage == nil)

                            Button(action: {
                                // Pre-select current system
                                selectedDiskSystemIndex = viewModel.selectedMachineIndex
                                if let system = DiskSystem(rawValue: viewModel.selectedMachineIndex) {
                                    diskConfiguration = DiskConfiguration(system: system)
                                }
                                showDiskSheet = true
                            }) {
                                Label("Create Disk", systemImage: "externaldrive")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(viewModel.convertedImage == nil)
                            .sheet(isPresented: $showDiskSheet) {
                                CreateDiskSheet(
                                    isPresented: $showDiskSheet,
                                    selectedSystemIndex: $selectedDiskSystemIndex,
                                    viewModel: viewModel
                                ) { config in
                                    viewModel.createDiskImage(configuration: config
                                    )
                                }
                            }

                        }
                        Spacer()
                    }
                    .padding(12)
                    .frame(width: sideColumnWidth)
                    .background(isRetro ? retroWindowBg : Color(NSColor.controlBackgroundColor).opacity(0.5))
                }
                }

                // Horizontal divider at the very top (always visible, on top of everything)
                Rectangle()
                    .fill(isRetro ? retroBorderColor : Color(NSColor.separatorColor))
                    .frame(height: isRetro ? (isAppleII ? AppleIITheme.dividerThickness : RetroTheme.dividerThickness) : 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .background(isRetro ? retroBgColor : Color(NSColor.windowBackgroundColor))
            .frame(height: 180)

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

    // MARK: - Palette Editor Helpers

    private func openPaletteEditor() {
        guard let result = viewModel.currentResult, !result.palettes.isEmpty else { return }

        // Convert PaletteRGB to PaletteColor for the editor
        editablePalettes = result.palettes.map { palette in
            palette.map { PaletteColor(r: $0.r, g: $0.g, b: $0.b) }
        }

        // Open floating window
        PaletteEditorWindowController.shared.openWindow(
            palettes: $editablePalettes
        ) { newPalettes in
            applyEditedPalettes(newPalettes)
        }
    }

    private func applyEditedPalettes(_ newPalettes: [[PaletteColor]]) {
        guard var result = viewModel.currentResult else { return }

        // Convert PaletteColor back to PaletteRGB
        result.palettes = newPalettes.map { palette in
            palette.map { PaletteRGB(r: $0.r, g: $0.g, b: $0.b) }
        }

        // Regenerate preview with edited palettes
        let preview = regeneratePreview(
            indices: result.pixelIndices,
            palettes: newPalettes,
            width: result.imageWidth,
            height: result.imageHeight
        )

        // Update the result
        viewModel.currentResult = ConversionResult(
            previewImage: preview,
            fileAssets: result.fileAssets,
            palettes: result.palettes,
            pixelIndices: result.pixelIndices,
            imageWidth: result.imageWidth,
            imageHeight: result.imageHeight
        )
    }

    private func regeneratePreview(indices: [Int], palettes: [[PaletteColor]], width: Int, height: Int) -> NSImage {
        guard !indices.isEmpty, !palettes.isEmpty else {
            return NSImage(size: NSSize(width: width, height: height))
        }

        var bytes = [UInt8](repeating: 255, count: width * height * 4)

        for y in 0..<height {
            let paletteIndex: Int
            if palettes.count == 200 {
                // Brooks 3200 mode - one palette per scanline
                paletteIndex = y
            } else {
                paletteIndex = min(y % palettes.count, palettes.count - 1)
            }

            let palette = palettes[paletteIndex]

            for x in 0..<width {
                let idx = y * width + x
                if idx >= indices.count { continue }

                let colorIdx = indices[idx]
                if colorIdx >= palette.count { continue }

                let color = palette[colorIdx]
                let pixelOffset = idx * 4

                bytes[pixelOffset + 0] = UInt8(max(0, min(255, color.r)))
                bytes[pixelOffset + 1] = UInt8(max(0, min(255, color.g)))
                bytes[pixelOffset + 2] = UInt8(max(0, min(255, color.b)))
                bytes[pixelOffset + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            return NSImage(size: NSSize(width: width, height: height))
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    // MARK: - Image Flip Functions

    private func flipImageHorizontally() {
        guard let currentImage = viewModel.convertedImage else { return }
        let flipped = flipImage(currentImage, horizontal: true)
        updatePreviewWithFlippedImage(flipped)
    }

    private func flipImageVertically() {
        guard let currentImage = viewModel.convertedImage else { return }
        let flipped = flipImage(currentImage, horizontal: false)
        updatePreviewWithFlippedImage(flipped)
    }

    private func flipImage(_ image: NSImage, horizontal: Bool) -> NSImage {
        let size = image.size
        let flippedImage = NSImage(size: size)

        flippedImage.lockFocus()

        let transform = NSAffineTransform()
        if horizontal {
            transform.translateX(by: size.width, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
        } else {
            transform.translateX(by: 0, yBy: size.height)
            transform.scaleX(by: 1, yBy: -1)
        }
        transform.concat()

        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)

        flippedImage.unlockFocus()

        return flippedImage
    }

    private func updatePreviewWithFlippedImage(_ flipped: NSImage) {
        guard let result = viewModel.currentResult else { return }

        viewModel.currentResult = ConversionResult(
            previewImage: flipped,
            fileAssets: result.fileAssets,
            palettes: result.palettes,
            pixelIndices: result.pixelIndices,
            imageWidth: result.imageWidth,
            imageHeight: result.imageHeight
        )
    }
}

// MARK: - Disk Progress Overlay

struct DiskProgressOverlay: View {
    let progress: Double
    let current: Int
    let total: Int
    let status: String
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var isC64: Bool = false

    var bgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        if isRetro { return RetroTheme.backgroundColor }
        return Color(NSColor.windowBackgroundColor)
    }

    var textColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        if isRetro { return RetroTheme.textColor }
        return .primary
    }

    var borderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        if isRetro { return RetroTheme.borderColor }
        return Color.gray.opacity(0.5)
    }

    var accentColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        if isRetro { return Color.blue }
        return Color.accentColor
    }

    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 12) }
        if isAppleII { return AppleIITheme.font(size: 12) }
        if isRetro { return RetroTheme.font(size: 12) }
        return .system(size: 12)
    }

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Progress panel
            VStack(spacing: 16) {
                Text("Creating Disk Image")
                    .font(isRetro || isAppleII || isC64 ? themeFont : .headline)
                    .foregroundColor(textColor)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 12)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(accentColor)
                            .frame(width: max(0, geometry.size.width * progress), height: 12)
                    }
                }
                .frame(height: 12)

                // Status text
                Text(status)
                    .font(isRetro || isAppleII || isC64 ? themeFont : .system(size: 11))
                    .foregroundColor(textColor.opacity(0.8))
                    .lineLimit(1)

                // Counter
                if total > 0 {
                    Text("\(current) of \(total)")
                        .font(isRetro || isAppleII || isC64 ? themeFont : .system(size: 11, weight: .medium))
                        .foregroundColor(textColor.opacity(0.7))
                }
            }
            .padding(24)
            .frame(width: 300)
            .background(bgColor)
            .cornerRadius(isRetro || isAppleII || isC64 ? 0 : 12)
            .overlay(
                RoundedRectangle(cornerRadius: isRetro || isAppleII || isC64 ? 0 : 12)
                    .stroke(borderColor, lineWidth: isRetro || isAppleII || isC64 ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let label: String
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var isC64: Bool = false
    var disabled: Bool = false
    var isActive: Bool = false
    let action: () -> Void

    // Theme-aware colors
    var themeTextColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        if isRetro { return RetroTheme.textColor }
        return .primary
    }
    var themeBgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        if isRetro { return RetroTheme.contentGray }
        return Color.clear
    }
    var themeBorderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        if isRetro { return RetroTheme.borderColor }
        return Color.gray.opacity(0.3)
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 9) }
        if isAppleII { return AppleIITheme.font(size: 9) }
        if isRetro { return .system(size: 8) }  // Smaller text for IIgs buttons
        return .system(size: 9)
    }
    var activeColor: Color {
        if isC64 { return C64Theme.textColor.opacity(0.3) }
        if isAppleII { return AppleIITheme.textColor.opacity(0.3) }
        if isRetro { return Color.blue.opacity(0.2) }
        return Color.accentColor.opacity(0.2)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isRetro || isAppleII || isC64 ? themeTextColor : nil)
                    .frame(width: 20, height: 16)
                Text(label)
                    .font(themeFont)
                    .foregroundColor(isRetro || isAppleII || isC64 ? themeTextColor : nil)
                    .lineLimit(1)
            }
            .frame(width: 50, height: 34)
            .background(isActive ? activeColor : (isRetro || isAppleII || isC64 ? themeBgColor : Color.clear))
            .cornerRadius(isRetro || isAppleII || isC64 ? 0 : 4)
            .overlay(
                (isRetro || isAppleII || isC64) ?
                Rectangle().stroke(themeBorderColor, lineWidth: 1) : nil
            )
        }
        .buttonStyle(.plain)
        .background(
            Group {
                if !(isRetro || isAppleII || isC64) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                }
            }
        )
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1.0)
        .help(label)
    }
}

// MARK: - Histogram View

struct HistogramOverlay: View {
    let image: NSImage?
    @Binding var isShowing: Bool
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var isC64: Bool = false
    @State private var showRed = true
    @State private var showGreen = true
    @State private var showBlue = true
    @State private var showLuma = false

    // Theme-aware colors
    var themeTextColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        if isRetro { return RetroTheme.textColor }
        return .primary
    }
    var themeBgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        if isRetro { return RetroTheme.contentGray }
        return Color(NSColor.windowBackgroundColor)
    }
    var themeBorderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        if isRetro { return RetroTheme.borderColor }
        return Color.clear
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 12) }
        if isAppleII { return AppleIITheme.font(size: 12) }
        if isRetro { return RetroTheme.font(size: 12) }
        return .caption
    }

    var body: some View {
        if isShowing, let img = image {
            VStack(spacing: 0) {
                // Header with title and close button
                HStack {
                    Text("Histogram")
                        .font(isRetro || isAppleII || isC64 ? themeFont : .caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isRetro || isAppleII || isC64 ? themeTextColor : .primary)
                    Spacer()
                    Button(action: { isShowing = false }) {
                        Image(systemName: isAppleII || isC64 ? "xmark" : "xmark.circle.fill")
                            .foregroundColor(isRetro || isAppleII || isC64 ? themeTextColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

                // Channel toggle buttons
                HStack(spacing: 4) {
                    ChannelToggleButton(label: "R", color: .red, isOn: $showRed, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                    ChannelToggleButton(label: "G", color: .green, isOn: $showGreen, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                    ChannelToggleButton(label: "B", color: .blue, isOn: $showBlue, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                    ChannelToggleButton(label: "L", color: .gray, isOn: $showLuma, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

                // Histogram chart
                HistogramChart(
                    image: img,
                    showRed: showRed,
                    showGreen: showGreen,
                    showBlue: showBlue,
                    showLuma: showLuma,
                    isRetro: isRetro,
                    isAppleII: isAppleII,
                    isC64: isC64
                )
                .frame(height: 100)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .background(themeBgColor.opacity(0.95))
            .cornerRadius(isRetro || isAppleII || isC64 ? 0 : 8)
            .overlay(
                (isRetro || isAppleII || isC64) ?
                Rectangle().stroke(themeBorderColor, lineWidth: 2) : nil
            )
            .shadow(radius: isRetro || isAppleII || isC64 ? 0 : 4)
            .frame(width: 260)
            .padding(12)
        }
    }
}

struct ChannelToggleButton: View {
    let label: String
    let color: Color
    @Binding var isOn: Bool
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var isC64: Bool = false

    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 11) }
        if isAppleII { return AppleIITheme.font(size: 11) }
        if isRetro { return RetroTheme.font(size: 11) }
        return .system(size: 11, weight: .bold, design: .monospaced)
    }
    var themeBorderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        if isRetro { return RetroTheme.borderColor }
        return Color.clear
    }

    var body: some View {
        Button(action: { isOn.toggle() }) {
            Text(label)
                .font(themeFont)
                .foregroundColor(isOn ? .white : color)
                .frame(width: 28, height: 20)
                .background(isOn ? color : color.opacity(0.2))
                .cornerRadius(isRetro || isAppleII || isC64 ? 0 : 4)
                .overlay(
                    (isRetro || isAppleII || isC64) ?
                    Rectangle().stroke(themeBorderColor, lineWidth: 1) : nil
                )
        }
        .buttonStyle(.plain)
    }
}

struct HistogramChart: View {
    let image: NSImage
    var showRed: Bool = true
    var showGreen: Bool = true
    var showBlue: Bool = true
    var showLuma: Bool = false
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var isC64: Bool = false

    @State private var redData: [CGFloat] = []
    @State private var greenData: [CGFloat] = []
    @State private var blueData: [CGFloat] = []
    @State private var lumaData: [CGFloat] = []

    var themeBgColor: Color {
        if isC64 { return Color.black }
        if isAppleII { return Color.black }
        if isRetro { return Color.black.opacity(0.5) }
        return Color.black.opacity(0.3)
    }
    var themeBorderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        if isRetro { return RetroTheme.borderColor }
        return Color.clear
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Luma channel (behind colors)
                if showLuma {
                    HistogramPath(data: lumaData, width: geometry.size.width, height: geometry.size.height)
                        .fill(Color.white.opacity(0.5))
                }
                // Red channel
                if showRed {
                    HistogramPath(data: redData, width: geometry.size.width, height: geometry.size.height)
                        .fill(Color.red.opacity(0.4))
                }
                // Green channel
                if showGreen {
                    HistogramPath(data: greenData, width: geometry.size.width, height: geometry.size.height)
                        .fill(Color.green.opacity(0.4))
                }
                // Blue channel
                if showBlue {
                    HistogramPath(data: blueData, width: geometry.size.width, height: geometry.size.height)
                        .fill(Color.blue.opacity(0.4))
                }
            }
            .background(themeBgColor)
            .cornerRadius(isRetro || isAppleII || isC64 ? 0 : 4)
            .overlay(
                (isRetro || isAppleII || isC64) ?
                Rectangle().stroke(themeBorderColor, lineWidth: 1) : nil
            )
        }
        .onAppear {
            calculateHistogram()
        }
    }

    private func calculateHistogram() {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        let width = cgImage.width
        let height = cgImage.height

        var redHist = [Int](repeating: 0, count: 256)
        var greenHist = [Int](repeating: 0, count: 256)
        var blueHist = [Int](repeating: 0, count: 256)
        var lumaHist = [Int](repeating: 0, count: 256)

        guard let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = Int(bytes[offset])
                let g = Int(bytes[offset + 1])
                let b = Int(bytes[offset + 2])

                // Calculate luma using standard BT.601 coefficients
                let luma = Int(0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))

                redHist[r] += 1
                greenHist[g] += 1
                blueHist[b] += 1
                lumaHist[min(255, luma)] += 1
            }
        }

        let maxVal = CGFloat(max(
            redHist.max() ?? 1,
            greenHist.max() ?? 1,
            blueHist.max() ?? 1,
            lumaHist.max() ?? 1
        ))

        redData = redHist.map { CGFloat($0) / maxVal }
        greenData = greenHist.map { CGFloat($0) / maxVal }
        blueData = blueHist.map { CGFloat($0) / maxVal }
        lumaData = lumaHist.map { CGFloat($0) / maxVal }
    }
}

struct HistogramPath: Shape {
    let data: [CGFloat]
    let width: CGFloat
    let height: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !data.isEmpty else { return path }

        let stepWidth = width / CGFloat(data.count)

        path.move(to: CGPoint(x: 0, y: height))

        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * stepWidth
            let y = height - (value * height)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()

        return path
    }
}

// MARK: - SUB VIEWS

struct DiskExportSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedSize: ConverterViewModel.DiskSize
    @Binding var selectedFormat: ConverterViewModel.DiskFormat
    @Binding var volumeName: String
    let onExport: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 48))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)

                Text("Create ProDOS Disk")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Configure your Apple II disk image")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Form {
                TextField("Volume Name:", text: $volumeName)
                    .textFieldStyle(.roundedBorder)
                    .help("Max 15 characters")

                Picker("Disk Size:", selection: $selectedSize) {
                    ForEach(ConverterViewModel.DiskSize.allCases) { size in
                        Text(size.rawValue).tag(size)
                    }
                }

                Picker("Format:", selection: $selectedFormat) {
                    ForEach(ConverterViewModel.DiskFormat.allCases) { format in
                        Text(format.rawValue.uppercased()).tag(format)
                    }
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)

                Button("Create Disk Image") {
                    isPresented = false
                    onExport()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(30)
        .frame(width: 420)
    }
}

struct ImageGridItem: View {
    let item: InputImage
    let isSelected: Bool
    var isMultiSelected: Bool = false
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var onToggleSelection: (() -> Void)? = nil

    // Theme-aware colors
    var themeBgColor: Color { isAppleII ? AppleIITheme.windowBackground : RetroTheme.windowBackground }
    var themeBorderColor: Color { isAppleII ? AppleIITheme.borderColor : RetroTheme.borderColor }
    var themeTextColor: Color { isAppleII ? AppleIITheme.textColor : RetroTheme.textColor }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if isRetro {
                    Rectangle()
                        .fill(themeBgColor)
                        .border(themeBorderColor, width: 1)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }

                Image(nsImage: item.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 70)
                    .padding(4)

                // Selection circle overlay (top-right corner)
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { onToggleSelection?() }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 20, height: 20)
                                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                if isMultiSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.accentColor)
                                } else {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
                                        .frame(width: 16, height: 16)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                    }
                    Spacer()
                }
            }
            .frame(height: 80)
            .overlay(
                Group {
                    if isRetro {
                        Rectangle()
                            .stroke(isSelected || isMultiSelected ? themeBorderColor : Color.clear, lineWidth: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : (isMultiSelected ? Color.accentColor.opacity(0.7) : Color.clear), lineWidth: 2.5)
                    }
                }
            )

            Text(item.name)
                .font(isRetro ? (isAppleII ? AppleIITheme.font(size: 10) : RetroTheme.font(size: 10)) : .caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(isRetro ? themeTextColor : (isSelected || isMultiSelected ? .primary : .secondary))
        }
        .padding(6)
        .background(isSelected ? (isRetro ? themeBgColor : Color.accentColor.opacity(0.12)) : (isMultiSelected ? Color.accentColor.opacity(0.08) : Color.clear))
        .cornerRadius(isRetro ? 0 : 10)
    }
}

struct ControlView: View {
    let opt: ConversionOption
    let index: Int
    @ObservedObject var viewModel: ConverterViewModel
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var isC64: Bool = false

    // Theme-aware colors
    var themeTextColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return isRetro ? RetroTheme.textColor : .secondary
    }
    var themeBgColor: Color {
        if isC64 { return C64Theme.windowBackground }
        if isAppleII { return AppleIITheme.windowBackground }
        return isRetro ? RetroTheme.windowBackground : Color(NSColor.controlBackgroundColor).opacity(0.5)
    }
    var themeBorderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        return RetroTheme.borderColor
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 12) }
        if isAppleII { return AppleIITheme.font(size: 12) }
        return isRetro ? RetroTheme.font(size: 11) : .system(size: 11, weight: .semibold)
    }
    var themeValueFont: Font {
        if isC64 { return C64Theme.font(size: 14) }
        if isAppleII { return AppleIITheme.font(size: 14) }
        return isRetro ? RetroTheme.font(size: 13) : .system(size: 13, weight: .medium)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(opt.label.uppercased())
                .font(themeFont)
                .foregroundColor(themeTextColor)
                .tracking(0.3)
            
            if opt.type == .slider {
                VStack(spacing: 6) {
                    Slider(
                        value: Binding(
                            get: {
                                let currentOptions = viewModel.machines[viewModel.selectedMachineIndex].options
                                if index < currentOptions.count {
                                    return Double(currentOptions[index].selectedValue) ?? 0.0
                                }
                                return 0.0
                            },
                            set: { val in
                                if index < viewModel.machines[viewModel.selectedMachineIndex].options.count {
                                    let isFloat = ["gamma", "saturation", "dither_amount", "sharpen_strength", "emboss_depth"].contains(opt.key)
                                    viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = isFloat ? String(format: "%.2f", val) : String(format: "%.0f", val)
                                    viewModel.triggerLivePreview()
                                }
                            }
                        ),
                        in: opt.range
                    )
                    .frame(width: 100)
                    .tint(.accentColor)

                    Text(safeValueDisplay)
                        .monospacedDigit()
                        .font(themeValueFont)
                        .foregroundColor(themeTextColor)
                        .frame(minWidth: 40)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(themeBgColor)
                        .cornerRadius((isRetro || isAppleII || isC64) ? 0 : 4)
                        .overlay((isRetro || isAppleII || isC64) ? Rectangle().stroke(themeBorderColor, lineWidth: 1) : nil)
                }
            } else if opt.type == .picker {
                if isC64 {
                    // C64-style popup picker with PetMe64 font
                    C64PopupPicker(
                        values: filteredValues,
                        selectedValue: Binding(
                            get: {
                                let currentOptions = viewModel.machines[viewModel.selectedMachineIndex].options
                                if index < currentOptions.count {
                                    return currentOptions[index].selectedValue
                                }
                                return ""
                            },
                            set: { val in
                                if index < viewModel.machines[viewModel.selectedMachineIndex].options.count {
                                    viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = val
                                }
                            }
                        ),
                        onChange: {
                            viewModel.triggerLivePreview()
                        }
                    )
                } else if isAppleII {
                    // Apple II-style popup picker with green phosphor look
                    AppleIIPopupPicker(
                        values: filteredValues,
                        selectedValue: Binding(
                            get: {
                                let currentOptions = viewModel.machines[viewModel.selectedMachineIndex].options
                                if index < currentOptions.count {
                                    return currentOptions[index].selectedValue
                                }
                                return ""
                            },
                            set: { val in
                                if index < viewModel.machines[viewModel.selectedMachineIndex].options.count {
                                    viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = val
                                }
                            }
                        ),
                        onChange: {
                            viewModel.triggerLivePreview()
                        }
                    )
                } else if isRetro {
                    // GS/OS-style popup picker with Shaston font
                    GSOSPopupPicker(
                        values: filteredValues,
                        selectedValue: Binding(
                            get: {
                                let currentOptions = viewModel.machines[viewModel.selectedMachineIndex].options
                                if index < currentOptions.count {
                                    return currentOptions[index].selectedValue
                                }
                                return ""
                            },
                            set: { val in
                                if index < viewModel.machines[viewModel.selectedMachineIndex].options.count {
                                    viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = val
                                }
                            }
                        ),
                        onChange: {
                            viewModel.triggerLivePreview()
                        }
                    )
                } else {
                    Picker("", selection: Binding(
                        get: {
                            let currentOptions = viewModel.machines[viewModel.selectedMachineIndex].options
                            if index < currentOptions.count {
                                return currentOptions[index].selectedValue
                            }
                            return ""
                        },
                        set: { val in
                            if index < viewModel.machines[viewModel.selectedMachineIndex].options.count {
                                viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = val
                                viewModel.triggerLivePreview()
                            }
                        }
                    )) {
                        ForEach(filteredValues, id: \.self) { val in
                            Text(val).tag(val)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minWidth: 110)
                    .controlSize(.regular)
                }
            }
        }
        .id("\(opt.id)_\(isAppleII)_\(isC64)_\(isRetro)")  // Force rebuild when theme changes
    }

    // Filter resolution values when Mono mode is selected
    var filteredValues: [String] {
        // Only filter for resolution picker
        guard opt.key == "resolution" else {
            return opt.values
        }
        
        // Check if current mode is "Mono"
        let currentOptions = viewModel.machines[viewModel.selectedMachineIndex].options
        if let modeOption = currentOptions.first(where: { $0.key == "mode" }),
           modeOption.selectedValue == "Mono" {
            // Only allow these two resolutions for Mono mode
            return opt.values.filter { value in
                value.contains("280x192") || value.contains("560x384")
            }
        }
        
        return opt.values
    }
    
    var safeValueDisplay: String {
        let currentOptions = viewModel.machines[viewModel.selectedMachineIndex].options
        if index < currentOptions.count {
            return currentOptions[index].selectedValue
        }
        return "-"
    }
}

struct SystemSelectButton: View {
    let iconName: String
    let machineName: String
    let isSelected: Bool
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var isC64: Bool = false
    let action: () -> Void

    // Theme-aware colors
    var themeBgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        return RetroTheme.backgroundColor
    }
    var themeWindowBg: Color {
        if isC64 { return C64Theme.windowBackground }
        if isAppleII { return AppleIITheme.windowBackground }
        return RetroTheme.windowBackground
    }
    var themeBorderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        return RetroTheme.borderColor
    }
    var themeTextColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return RetroTheme.textColor
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 14) }
        if isAppleII { return AppleIITheme.font(size: 14) }
        return RetroTheme.font(size: 14)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if iconName.starts(with: "icon_") {
                    Image(iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 38)
                        .opacity(isSelected ? 1.0 : 0.6)
                } else {
                    Image(systemName: iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 38)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isRetro ? themeTextColor : (isSelected ? Color.accentColor : Color.secondary))
                }

                Text(machineName)
                    .font(isRetro ? themeFont : .system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isRetro ? themeTextColor : (isSelected ? .primary : .secondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                Group {
                    if isRetro {
                        Rectangle()
                            .fill(isSelected ? themeWindowBg : themeBgColor)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                            .shadow(color: isSelected ? Color.accentColor.opacity(0.2) : Color.black.opacity(0.05), radius: isSelected ? 4 : 2, x: 0, y: isSelected ? 2 : 1)
                    }
                }
            )
            .overlay(
                Group {
                    if isRetro {
                        Rectangle()
                            .strokeBorder(themeBorderColor, lineWidth: isSelected ? 2 : 1)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color(NSColor.separatorColor).opacity(0.5), lineWidth: isSelected ? 1.5 : 0.5)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Horizontal System Bar

struct HorizontalSystemBar: View {
    @ObservedObject var viewModel: ConverterViewModel
    var isRetro: Bool
    var isAppleII: Bool
    var isC64: Bool

    var themeBgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        return RetroTheme.contentGray
    }
    var themeTextColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return RetroTheme.textColor
    }
    var themeBorderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        return RetroTheme.borderColor
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 11) }
        if isAppleII { return AppleIITheme.font(size: 11) }
        return RetroTheme.font(size: 10)
    }

    private let systemIcons = ["icon_apple2", "icon_iigs", "icon_Amiga500", "icon_Amiga1200", "icon_AmstradCPC", "icon_Atari800", "icon_AtariST", "icon_BBCmicro", "icon_C64", "icon_MSX", "icon_PC", "icon_commodoreplus4", "icon_vic20", "icon_ZXSpectrum"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.machines.indices, id: \.self) { index in
                if index < systemIcons.count {
                    HorizontalSystemButton(
                        iconName: systemIcons[index],
                        machineName: viewModel.machines[index].name,
                        isSelected: viewModel.selectedMachineIndex == index,
                        isRetro: isRetro,
                        isAppleII: isAppleII,
                        isC64: isC64
                    ) {
                        if viewModel.selectedMachineIndex != index {
                            viewModel.selectedMachineIndex = index
                            viewModel.triggerLivePreview()
                        }
                    }

                    if index < viewModel.machines.count - 1 {
                        if isRetro {
                            Rectangle().fill(themeBorderColor).frame(width: 1)
                        } else {
                            Rectangle().fill(Color(NSColor.separatorColor).opacity(0.3)).frame(width: 1)
                        }
                    }
                }
            }
            Spacer()
        }
        .frame(height: 64)
        .background(isRetro ? themeBgColor : Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

struct HorizontalSystemButton: View {
    let iconName: String
    let machineName: String
    let isSelected: Bool
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var isC64: Bool = false
    let action: () -> Void

    var themeBgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        return RetroTheme.contentGray
    }
    var themeWindowBg: Color {
        if isC64 { return C64Theme.windowBackground }
        if isAppleII { return AppleIITheme.windowBackground }
        return RetroTheme.windowBackground
    }
    var themeBorderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        return RetroTheme.borderColor
    }
    var themeTextColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return RetroTheme.textColor
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 11) }
        if isAppleII { return AppleIITheme.font(size: 11) }
        return RetroTheme.font(size: 10)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 46)

                Text(machineName)
                    .font(isRetro ? themeFont : .system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isRetro ? themeTextColor : (isSelected ? .primary : .secondary))
                    .lineLimit(1)
            }
            .frame(width: 90)
            .padding(.vertical, 4)
            .background(
                Group {
                    if isRetro {
                        Rectangle().fill(isSelected ? themeWindowBg : Color.clear)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Image Info Panel

struct ImageInfoPanel: View {
    @ObservedObject var viewModel: ConverterViewModel
    var isRetro: Bool
    var isAppleII: Bool
    var isC64: Bool

    var themeBgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        return RetroTheme.contentGray
    }
    var themeTextColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return RetroTheme.textColor
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 9) }
        if isAppleII { return AppleIITheme.font(size: 9) }
        return .custom("Shaston 640", size: 10)  // Smaller Shaston for compact display
    }
    var themeBoldFont: Font {
        if isC64 { return C64Theme.boldFont(size: 9) }
        if isAppleII { return AppleIITheme.boldFont(size: 9) }
        return .custom("Shaston 640", size: 10)
    }

    var selectedImage: InputImage? {
        guard let id = viewModel.selectedImageId else { return nil }
        return viewModel.inputImages.first(where: { $0.id == id })
    }

    // Get current mode from machine options
    var currentMode: String? {
        viewModel.currentMachine.options.first(where: { $0.key == "mode" })?.selectedValue
    }

    // Get color count from mode name or palette
    var colorCount: String? {
        if let result = viewModel.currentResult, !result.palettes.isEmpty {
            let count = result.palettes.first?.count ?? 0
            return "\(count)"
        }
        // Try to parse from mode name (e.g., "Mode 2 (8 colors)")
        if let mode = currentMode {
            if let range = mode.range(of: #"(\d+)\s*colors?"#, options: .regularExpression) {
                let match = mode[range]
                if let numRange = match.range(of: #"\d+"#, options: .regularExpression) {
                    return String(match[numRange])
                }
            }
            // Check for common patterns
            if mode.contains("2 colors") || mode.contains("Mono") || mode.contains("HiRes") { return "2" }
            if mode.contains("4 colors") { return "4" }
            if mode.contains("8 colors") { return "8" }
            if mode.contains("16 colors") || mode.contains("16 shades") || mode.contains("16 hues") { return "16" }
            if mode.contains("256") { return "256" }
        }
        return nil
    }

    // Format output file size
    func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) bytes"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }

    // Get output file size
    var outputFileSize: String? {
        guard let fileUrl = viewModel.currentResult?.fileAssets.first,
              let attrs = try? FileManager.default.attributesOfItem(atPath: fileUrl.path),
              let size = attrs[.size] as? Int64 else { return nil }
        return formatFileSize(size)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // INPUT SECTION
            Text(isRetro ? "INPUT" : "INPUT")
                .font(isRetro ? themeFont : .system(size: 9, weight: .semibold))
                .foregroundColor(isRetro ? themeTextColor : .secondary)
                .tracking(0.5)

            if let img = selectedImage {
                VStack(alignment: .leading, spacing: 2) {
                    InfoRow(label: "File", value: img.name, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                    InfoRow(label: "Size", value: "\(Int(img.image.size.width))×\(Int(img.image.size.height))", isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                    if let fileSize = img.formattedFileSize {
                        InfoRow(label: "FileSize", value: fileSize, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                    }
                    InfoRow(label: "Format", value: img.format, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                    if let bpp = img.bitsPerPixel {
                        let alphaStr = img.hasAlpha ? " (α)" : ""
                        InfoRow(label: "Depth", value: "\(bpp)-bit\(alphaStr)", isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                    }
                }

                // OUTPUT SECTION
                if let result = viewModel.currentResult {
                    if isRetro {
                        Rectangle().fill(themeTextColor.opacity(0.3)).frame(height: 1).padding(.vertical, 2)
                    } else {
                        Divider().padding(.vertical, 2)
                    }

                    Text(isRetro ? "OUTPUT" : "OUTPUT")
                        .font(isRetro ? themeFont : .system(size: 9, weight: .semibold))
                        .foregroundColor(isRetro ? themeTextColor : .secondary)
                        .tracking(0.5)

                    VStack(alignment: .leading, spacing: 2) {
                        InfoRow(label: "System", value: viewModel.currentMachine.name, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                        if let mode = currentMode {
                            // Shorten mode name for display
                            let shortMode = mode.replacingOccurrences(of: " (", with: "\n(").components(separatedBy: "\n").first ?? mode
                            InfoRow(label: "Mode", value: shortMode, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                        }
                        InfoRow(label: "Size", value: "\(result.imageWidth)×\(result.imageHeight)", isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                        if let colors = colorCount {
                            InfoRow(label: "Colors", value: colors, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                        }
                        if let fileUrl = result.fileAssets.first {
                            InfoRow(label: "Format", value: ".\(fileUrl.pathExtension)", isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                        }
                        if let fileSize = outputFileSize {
                            InfoRow(label: "FileSize", value: fileSize, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                        }
                    }
                }
            } else {
                Text(isRetro ? "NO IMAGE" : "No image selected")
                    .font(isRetro ? themeFont : .system(size: 9))
                    .foregroundColor(isRetro ? themeTextColor.opacity(0.5) : .secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var isC64: Bool = false

    var themeTextColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return RetroTheme.textColor
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 8) }
        if isAppleII { return AppleIITheme.font(size: 8) }
        return .custom("Shaston 640", size: 9)  // Smaller Shaston for compact display
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(isRetro ? "\(label.uppercased()):" : "\(label):")
                .font(isRetro ? themeFont : .system(size: 9))
                .foregroundColor(isRetro ? themeTextColor.opacity(0.6) : .secondary)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(isRetro ? themeFont : .system(size: 9, weight: .medium))
                .foregroundColor(isRetro ? themeTextColor : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - GS/OS Popup Picker

/// GS/OS-style popup menu picker with Shaston font
struct GSOSPopupPicker: View {
    let values: [String]
    @Binding var selectedValue: String
    let onChange: () -> Void

    // Calculate width based on longest value
    private var calculatedWidth: CGFloat {
        let longestValue = values.max(by: { $0.count < $1.count }) ?? ""
        // Measure actual text width with Shaston font
        let font = NSFont(name: "Shaston 640", size: 16) ?? NSFont.systemFont(ofSize: 16)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (longestValue as NSString).size(withAttributes: attributes)
        return max(140, textSize.width + 40)  // Add padding for dropdown arrow and borders
    }

    var body: some View {
        GSOSPopupButtonRepresentable(
            values: values,
            selectedValue: $selectedValue,
            onChange: onChange,
            width: calculatedWidth
        )
        .frame(width: calculatedWidth, height: 22)
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(RetroTheme.borderColor, lineWidth: 1)
        )
    }
}

/// NSViewRepresentable wrapper for NSPopUpButton with Shaston font
struct GSOSPopupButtonRepresentable: NSViewRepresentable {
    let values: [String]
    @Binding var selectedValue: String
    let onChange: () -> Void
    let width: CGFloat

    func makeNSView(context: Context) -> NSView {
        // Create clipping container view to enforce width
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 22))
        container.wantsLayer = true
        container.layer?.masksToBounds = true

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: width, height: 22), pullsDown: false)
        popup.bezelStyle = .smallSquare
        popup.isBordered = false  // Remove default border, we draw our own

        // Set Shaston font for the button title
        if let shastonFont = NSFont(name: "Shaston 640", size: 16) {
            popup.font = shastonFont
        }

        // Configure cell for text truncation
        if let cell = popup.cell as? NSPopUpButtonCell {
            cell.lineBreakMode = .byTruncatingTail
            cell.truncatesLastVisibleLine = true
        }

        popup.target = context.coordinator
        popup.action = #selector(Coordinator.selectionChanged(_:))

        container.addSubview(popup)
        context.coordinator.popup = popup

        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let popup = context.coordinator.popup else { return }

        popup.removeAllItems()

        // Add items with Shaston font
        for value in values {
            popup.addItem(withTitle: value)
            if let item = popup.lastItem, let shastonFont = NSFont(name: "Shaston 640", size: 16) {
                let attributes: [NSAttributedString.Key: Any] = [.font: shastonFont]
                item.attributedTitle = NSAttributedString(string: value, attributes: attributes)
            }
        }

        // Select current value
        if let index = values.firstIndex(of: selectedValue) {
            popup.selectItem(at: index)
        }

        // Update frames
        container.frame = NSRect(x: 0, y: 0, width: width, height: 22)
        popup.frame = NSRect(x: 0, y: 0, width: width, height: 22)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: GSOSPopupButtonRepresentable
        var popup: NSPopUpButton?

        init(_ parent: GSOSPopupButtonRepresentable) {
            self.parent = parent
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            if let title = sender.selectedItem?.title {
                parent.selectedValue = title
                parent.onChange()
            }
        }
    }
}

// MARK: - GS/OS Window Frame

/// GS/OS-style striped title bar pattern (4 lines, 2px each like real Apple IIgs)
struct GSOSTitleBarPattern: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // 4 horizontal black lines with 2px thickness, evenly spaced
                // Start at y=3 to leave 2px padding at top (avoid connecting with border)
                let lineHeight: CGFloat = 2
                let linePositions: [CGFloat] = [3, 7, 11, 15]

                // Fill background with white first
                context.fill(
                    Path(CGRect(x: 0, y: 0, width: size.width, height: size.height)),
                    with: .color(.white)
                )

                // Draw 4 black lines
                for y in linePositions {
                    context.fill(
                        Path(CGRect(x: 0, y: y, width: size.width, height: lineHeight)),
                        with: .color(.black)
                    )
                }
            }
        }
    }
}

/// GS/OS close box (small square with X pattern)
struct GSOSCloseBox: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(width: 12, height: 10)
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
                .frame(width: 12, height: 10)
        }
    }
}

/// GS/OS zoom box (small square)
struct GSOSZoomBox: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(width: 12, height: 10)
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
                .frame(width: 12, height: 10)
            // Inner square for zoom icon
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
                .frame(width: 6, height: 5)
        }
    }
}

/// GS/OS-style window frame that wraps content
struct GSOSWindowFrame<Content: View>: View {
    let title: String
    let infoText: String
    let content: Content

    init(title: String, infoText: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.infoText = infoText
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar with stripes
            ZStack {
                GSOSTitleBarPattern()

                HStack {
                    // Close box
                    GSOSCloseBox()
                        .padding(.leading, 6)

                    Spacer()

                    // Title
                    Text(title)
                        .font(RetroTheme.font(size: 12))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .background(Color.white)

                    Spacer()

                    // Zoom box
                    GSOSZoomBox()
                        .padding(.trailing, 6)
                }
            }
            .frame(height: RetroTheme.titleBarHeight)

            // Black line under title bar
            Rectangle()
                .fill(Color.black)
                .frame(height: 1)

            // Info bar (like "ProDOS  3 items  11.1 MB used  20.8 MB free")
            HStack {
                Text(infoText)
                    .font(RetroTheme.font(size: 12))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: RetroTheme.infoBarHeight)
            .background(Color.white)

            // Black line under info bar
            Rectangle()
                .fill(Color.black)
                .frame(height: 1)

            // Content area with gray background
            content
                .background(RetroTheme.contentGray)
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(Color.black, lineWidth: 2)
        )
    }
}

// MARK: - Apple II Green Phosphor Window Frame

/// Apple II-style window frame with green phosphor look
struct AppleIIWindowFrame<Content: View>: View {
    let title: String
    let infoText: String
    let content: Content

    init(title: String, infoText: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.infoText = infoText
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar - simple green text on black
            HStack {
                Text("*")
                    .font(AppleIITheme.font(size: 16))
                    .foregroundColor(AppleIITheme.textColor)

                Text(title)
                    .font(AppleIITheme.font(size: 16))
                    .foregroundColor(AppleIITheme.textColor)

                Spacer()

                Text(infoText)
                    .font(AppleIITheme.font(size: 14))
                    .foregroundColor(AppleIITheme.dimTextColor)

                Text("*")
                    .font(AppleIITheme.font(size: 16))
                    .foregroundColor(AppleIITheme.textColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppleIITheme.backgroundColor)

            // Green divider line
            Rectangle()
                .fill(AppleIITheme.borderColor)
                .frame(height: AppleIITheme.dividerThickness)

            // Content area
            content
                .background(AppleIITheme.backgroundColor)
        }
        .background(AppleIITheme.backgroundColor)
        .overlay(
            Rectangle()
                .stroke(AppleIITheme.borderColor, lineWidth: 2)
        )
        .padding(.bottom, 12)  // Move border up so macOS window doesn't clip corners
    }
}

// MARK: - Commodore 64 Window Frame

struct C64WindowFrame<Content: View>: View {
    let title: String
    let infoText: String
    let content: Content

    init(title: String, infoText: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.infoText = infoText
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar - C64 style with PETSCII border
            HStack {
                Text("*")
                    .font(C64Theme.font(size: 16))
                    .foregroundColor(C64Theme.textColor)

                Text(title)
                    .font(C64Theme.font(size: 16))
                    .foregroundColor(C64Theme.textColor)
                    .textCase(.uppercase)

                Spacer()

                Text(infoText)
                    .font(C64Theme.font(size: 14))
                    .foregroundColor(C64Theme.textColor)

                Text("*")
                    .font(C64Theme.font(size: 16))
                    .foregroundColor(C64Theme.textColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(C64Theme.backgroundColor)

            // C64 blue divider line
            Rectangle()
                .fill(C64Theme.borderColor)
                .frame(height: C64Theme.dividerThickness)

            // Content area
            content
                .background(C64Theme.backgroundColor)
        }
        .background(C64Theme.backgroundColor)
        .overlay(
            Rectangle()
                .stroke(C64Theme.borderColor, lineWidth: 2)
        )
        .padding(.bottom, 12)  // Move border up so macOS window doesn't clip corners
    }
}

// MARK: - Apple II Popup Picker

/// Apple II-style popup picker with green phosphor look
struct AppleIIPopupPicker: View {
    let values: [String]
    @Binding var selectedValue: String
    let onChange: () -> Void

    // Calculate width based on longest value
    private var calculatedWidth: CGFloat {
        let longestValue = values.max(by: { $0.count < $1.count }) ?? ""
        // Print Char 21 at size 14 - measure actual text width
        let font = AppleIITheme.nsFont(size: 14)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (longestValue as NSString).size(withAttributes: attributes)
        return max(140, textSize.width + 40)  // Add padding for dropdown arrow and borders
    }

    var body: some View {
        AppleIIPopupButtonRepresentable(
            values: values,
            selectedValue: $selectedValue,
            onChange: onChange,
            width: calculatedWidth
        )
        .frame(width: calculatedWidth, height: 22)
        .background(AppleIITheme.backgroundColor)
        .overlay(
            Rectangle()
                .stroke(AppleIITheme.borderColor, lineWidth: 1)
        )
    }
}

/// NSViewRepresentable wrapper for Apple II style popup
struct AppleIIPopupButtonRepresentable: NSViewRepresentable {
    let values: [String]
    @Binding var selectedValue: String
    let onChange: () -> Void
    let width: CGFloat

    func makeNSView(context: Context) -> NSView {
        // Create clipping container view to enforce width
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 22))
        container.wantsLayer = true
        container.layer?.masksToBounds = true

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: width, height: 22), pullsDown: false)
        popup.bezelStyle = .smallSquare
        popup.isBordered = false

        // Set Apple II font
        popup.font = AppleIITheme.nsFont(size: 14)

        // Configure cell for text truncation
        if let cell = popup.cell as? NSPopUpButtonCell {
            cell.lineBreakMode = .byTruncatingTail
            cell.truncatesLastVisibleLine = true
        }

        popup.target = context.coordinator
        popup.action = #selector(Coordinator.selectionChanged(_:))

        container.addSubview(popup)
        context.coordinator.popup = popup

        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let popup = context.coordinator.popup else { return }

        popup.removeAllItems()

        // Add items with Apple II font
        let font = AppleIITheme.nsFont(size: 14)
        for value in values {
            popup.addItem(withTitle: value)
            if let item = popup.lastItem {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor(AppleIITheme.textColor)
                ]
                item.attributedTitle = NSAttributedString(string: value, attributes: attributes)
            }
        }

        if let index = values.firstIndex(of: selectedValue) {
            popup.selectItem(at: index)
        }

        // Update frames
        container.frame = NSRect(x: 0, y: 0, width: width, height: 22)
        popup.frame = NSRect(x: 0, y: 0, width: width, height: 22)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: AppleIIPopupButtonRepresentable
        var popup: NSPopUpButton?

        init(_ parent: AppleIIPopupButtonRepresentable) {
            self.parent = parent
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            if let title = sender.selectedItem?.title {
                parent.selectedValue = title
                parent.onChange()
            }
        }
    }
}

// MARK: - C64 Popup Picker

struct C64PopupPicker: View {
    let values: [String]
    @Binding var selectedValue: String
    let onChange: () -> Void

    // Calculate width based on longest value
    private var calculatedWidth: CGFloat {
        let longestValue = values.max(by: { $0.count < $1.count }) ?? ""
        // PetMe64 at size 14 - measure actual text width
        let font = C64Theme.nsFont(size: 14)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (longestValue as NSString).size(withAttributes: attributes)
        return max(140, textSize.width + 40)  // Add padding for dropdown arrow and borders
    }

    var body: some View {
        C64PopupButtonRepresentable(
            values: values,
            selectedValue: $selectedValue,
            onChange: onChange,
            width: calculatedWidth
        )
        .frame(width: calculatedWidth, height: 22)
        .background(C64Theme.backgroundColor)
        .overlay(
            Rectangle()
                .stroke(C64Theme.borderColor, lineWidth: 1)
        )
    }
}

/// NSViewRepresentable wrapper for C64 style popup
struct C64PopupButtonRepresentable: NSViewRepresentable {
    let values: [String]
    @Binding var selectedValue: String
    let onChange: () -> Void
    let width: CGFloat

    func makeNSView(context: Context) -> NSView {
        // Create clipping container view to enforce width
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 22))
        container.wantsLayer = true
        container.layer?.masksToBounds = true

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: width, height: 22), pullsDown: false)
        popup.bezelStyle = .smallSquare
        popup.isBordered = false

        // Set C64 font
        popup.font = C64Theme.nsFont(size: 14)

        // Configure cell for text truncation
        if let cell = popup.cell as? NSPopUpButtonCell {
            cell.lineBreakMode = .byTruncatingTail
            cell.truncatesLastVisibleLine = true
        }

        popup.target = context.coordinator
        popup.action = #selector(Coordinator.selectionChanged(_:))

        container.addSubview(popup)
        context.coordinator.popup = popup

        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let popup = context.coordinator.popup else { return }

        popup.removeAllItems()

        // Add items with C64 font
        let font = C64Theme.nsFont(size: 14)
        for value in values {
            popup.addItem(withTitle: value)
            if let item = popup.lastItem {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor(C64Theme.textColor)
                ]
                item.attributedTitle = NSAttributedString(string: value, attributes: attributes)
            }
        }

        if let index = values.firstIndex(of: selectedValue) {
            popup.selectItem(at: index)
        }

        // Update frames
        container.frame = NSRect(x: 0, y: 0, width: width, height: 22)
        popup.frame = NSRect(x: 0, y: 0, width: width, height: 22)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: C64PopupButtonRepresentable
        var popup: NSPopUpButton?

        init(_ parent: C64PopupButtonRepresentable) {
            self.parent = parent
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            if let title = sender.selectedItem?.title {
                parent.selectedValue = title
                parent.onChange()
            }
        }
    }
}

// MARK: - Retro Action Button

/// Retro-styled action button for Apple II, C64, and IIgs themes
struct RetroActionButton: View {
    let title: String
    let isAppleII: Bool
    var isC64: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    // Theme colors
    var bgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        return RetroTheme.windowBackground
    }
    var textColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return RetroTheme.textColor
    }
    var borderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        return RetroTheme.borderColor
    }
    var disabledColor: Color {
        if isC64 { return C64Theme.textColor.opacity(0.4) }
        if isAppleII { return AppleIITheme.dimTextColor }
        return RetroTheme.textColor.opacity(0.4)
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 12) }
        if isAppleII { return AppleIITheme.font(size: 12) }
        return RetroTheme.font(size: 12)
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if isAppleII {
                    Text("[ \(title) ]")
                        .font(themeFont)
                        .foregroundColor(isDisabled ? disabledColor : textColor)
                } else if isC64 {
                    Text("[ \(title) ]")
                        .font(themeFont)
                        .foregroundColor(isDisabled ? disabledColor : textColor)
                        .textCase(.uppercase)
                } else {
                    Text(title)
                        .font(themeFont)
                        .foregroundColor(isDisabled ? disabledColor : textColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background(bgColor)
        .overlay(
            Rectangle()
                .stroke(isDisabled ? disabledColor : borderColor, lineWidth: 2)
        )
    }
}

// MARK: - Retro Action Menu

/// Retro-styled dropdown menu for Apple II, C64, and IIgs themes
struct RetroActionMenu<MenuItems: View>: View {
    let title: String
    let isAppleII: Bool
    var isC64: Bool = false
    var isDisabled: Bool = false
    @ViewBuilder let menuItems: () -> MenuItems

    // Theme colors
    var bgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        return RetroTheme.windowBackground
    }
    var textColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return RetroTheme.textColor
    }
    var borderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        return RetroTheme.borderColor
    }
    var disabledColor: Color {
        if isC64 { return C64Theme.textColor.opacity(0.4) }
        if isAppleII { return AppleIITheme.dimTextColor }
        return RetroTheme.textColor.opacity(0.4)
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 12) }
        if isAppleII { return AppleIITheme.font(size: 12) }
        return RetroTheme.font(size: 12)
    }
    var themeSmallFont: Font {
        if isC64 { return C64Theme.font(size: 10) }
        if isAppleII { return AppleIITheme.font(size: 10) }
        return RetroTheme.font(size: 8)
    }

    var body: some View {
        Menu {
            menuItems()
        } label: {
            HStack {
                if isAppleII {
                    Text("[ \(title) ]")
                        .font(themeFont)
                        .foregroundColor(isDisabled ? disabledColor : textColor)
                } else if isC64 {
                    Text("[ \(title) ]")
                        .font(themeFont)
                        .foregroundColor(isDisabled ? disabledColor : textColor)
                        .textCase(.uppercase)
                } else {
                    Text(title)
                        .font(themeFont)
                        .foregroundColor(isDisabled ? disabledColor : textColor)
                }
                Spacer()
                Text(isAppleII || isC64 ? "v" : "▼")
                    .font(themeSmallFont)
                    .foregroundColor(isDisabled ? disabledColor : textColor)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .menuStyle(.borderlessButton)
        .disabled(isDisabled)
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background(bgColor)
        .overlay(
            Rectangle()
                .stroke(isDisabled ? disabledColor : borderColor, lineWidth: 2)
        )
    }
}
