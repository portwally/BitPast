import SwiftUI
import UniformTypeIdentifiers

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
                        // Lock/Unlock per-image settings button
                        if viewModel.selectedImageId != nil {
                            Button(action: {
                                if viewModel.selectedImageIsLocked {
                                    viewModel.unlockSettings()
                                } else {
                                    viewModel.lockCurrentSettings()
                                }
                            }) {
                                Image(systemName: viewModel.selectedImageIsLocked ? "lock.fill" : "lock.open")
                                    .foregroundStyle(viewModel.selectedImageIsLocked ? .orange : (isRetro ? retroTextColor : .secondary))
                            }
                            .buttonStyle(.plain)
                            .help(viewModel.selectedImageIsLocked ? "Unlock settings (use global)" : "Lock current settings for this image")
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
                                        isLocked: item.isLocked,
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
