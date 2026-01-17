import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ConverterViewModel()
    @ObservedObject private var settings = AppSettings.shared
    @State private var isDropTarget = false
    @State private var zoomLevel: CGFloat = 1.0

    // ProDOS Sheet State
    @State private var showDiskSheet = false
    @State private var selectedDiskSize: ConverterViewModel.DiskSize = .kb140
    @State private var selectedDiskFormat: ConverterViewModel.DiskFormat = .po
    @State private var diskVolumeName: String = "BITPAST"

    let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    // Layout Konstante: Von 190 auf 195 erhöht (+5px)
    let sideColumnWidth: CGFloat = 195

    // Keys für die Anzeige
    let topRowKeys = ["mode", "dither", "quantization_method", "palette", "saturation"]
    let bottomRowKeys = ["resolution", "crosshatch", "z_threshold", "error_matrix", "gamma", "dither_amount", "threshold"]

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

            // 1. OBERER BEREICH: SPLIT VIEW
            HSplitView {
                // LINKER BEREICH: IMAGE BROWSER
                VStack(spacing: 0) {
                    HStack {
                        Text("Image Browser")
                            .font(isRetro ? retroBoldFont : .system(size: 13, weight: .semibold))
                            .foregroundColor(isRetro ? retroTextColor : .secondary)
                        Spacer()
                        if viewModel.selectedImageId != nil {
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
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Add images")
                    }
                    .frame(height: 38)
                    .padding(.horizontal, 12)
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
                                    ImageGridItem(item: item, isSelected: viewModel.selectedImageId == item.id, isRetro: isRetro, isAppleII: isAppleII)
                                        .onTapGesture {
                                            viewModel.selectedImageId = item.id
                                            viewModel.convertImmediately()
                                        }
                                }
                            }.padding(10)
                        }.background(isRetro ? retroBgColor : Color(NSColor.controlBackgroundColor))
                    }
                }
                .frame(minWidth: 200, maxWidth: 450)
                .onDrop(of: [.fileURL], isTargeted: $isDropTarget) { providers in return viewModel.handleDrop(providers: providers) }

                // RECHTER BEREICH: VORSCHAU
                VStack(spacing: 0) {
                    HStack {
                        Text("Preview")
                            .font(isRetro ? retroBoldFont : .system(size: 13, weight: .semibold))
                            .foregroundColor(isRetro ? retroTextColor : .secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Button(action: { if zoomLevel > 0.2 { zoomLevel -= 0.2 } }) {
                                if isRetro {
                                    Text("-")
                                        .font(retroBoldFont)
                                        .foregroundColor(retroTextColor)
                                        .frame(width: 20)
                                } else {
                                    Image(systemName: "minus.magnifyingglass")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Zoom out")

                            Text("\(Int(zoomLevel * 100))%")
                                .monospacedDigit()
                                .font(isRetro ? retroSmallFont : .caption)
                                .foregroundColor(isRetro ? retroTextColor : .secondary)
                                .frame(width: 45)

                            Button(action: { if zoomLevel < 5.0 { zoomLevel += 0.2 } }) {
                                if isRetro {
                                    Text("+")
                                        .font(retroBoldFont)
                                        .foregroundColor(retroTextColor)
                                        .frame(width: 20)
                                } else {
                                    Image(systemName: "plus.magnifyingglass")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Zoom in")
                        }
                    }
                    .frame(height: 38)
                    .padding(.horizontal, 12)
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
                                let fitScale = min(
                                    geometry.size.width / img.size.width,
                                    geometry.size.height / img.size.height
                                )
                                let effectiveZoom = zoomLevel == 1.0 ? fitScale : zoomLevel

                                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                                    Image(nsImage: img)
                                        .resizable()
                                        .interpolation(.none)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(
                                            width: img.size.width * effectiveZoom,
                                            height: img.size.height * effectiveZoom
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

                    // A. LINKS: SYSTEM (Feste Breite, Symmetrisch zu Rechts)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SYSTEM")
                            .font(isRetro ? retroSmallFont : .system(size: 11, weight: .semibold))
                            .foregroundColor(isRetro ? retroTextColor : .secondary)
                            .tracking(0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 8) {
                            // BUTTON 1: Apple II
                            SystemSelectButton(
                                iconName: "icon_apple2",
                                machineName: viewModel.machines[0].name,
                                isSelected: viewModel.selectedMachineIndex == 0,
                                isRetro: isRetro,
                                isAppleII: isAppleII,
                                isC64: isC64
                            ) {
                                if viewModel.selectedMachineIndex != 0 {
                                    viewModel.selectedMachineIndex = 0
                                    viewModel.triggerLivePreview()
                                }
                            }

                            // BUTTON 2: Apple IIGS
                            if viewModel.machines.count > 1 {
                                SystemSelectButton(
                                    iconName: "icon_iigs",
                                    machineName: viewModel.machines[1].name,
                                    isSelected: viewModel.selectedMachineIndex == 1,
                                    isRetro: isRetro,
                                    isAppleII: isAppleII,
                                    isC64: isC64
                                ) {
                                    if viewModel.selectedMachineIndex != 1 {
                                        viewModel.selectedMachineIndex = 1
                                        viewModel.triggerLivePreview()
                                    }
                                }
                            }

                            // BUTTON 3: C64
                            if viewModel.machines.count > 2 {
                                SystemSelectButton(
                                    iconName: "gamecontroller.fill",
                                    machineName: viewModel.machines[2].name,
                                    isSelected: viewModel.selectedMachineIndex == 2,
                                    isRetro: isRetro,
                                    isAppleII: isAppleII,
                                    isC64: isC64
                                ) {
                                    if viewModel.selectedMachineIndex != 2 {
                                        viewModel.selectedMachineIndex = 2
                                        viewModel.triggerLivePreview()
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .frame(width: sideColumnWidth)
                    .background(isRetro ? retroWindowBg : Color(NSColor.controlBackgroundColor).opacity(0.5))

                    // Vertical divider after SYSTEM
                    if isRetro {
                        let dividerThickness: CGFloat = isC64 ? C64Theme.dividerThickness : (isAppleII ? AppleIITheme.dividerThickness : RetroTheme.dividerThickness)
                        // Bottom padding to align with bottom border
                        let bottomPadding: CGFloat = (isAppleII || isC64) ? 10 : 0
                        Rectangle().fill(retroBorderColor).frame(width: dividerThickness)
                            .padding(.bottom, bottomPadding)
                    } else {
                        Rectangle().fill(Color(NSColor.separatorColor)).frame(width: 1)
                    }

                    // B. MITTE: SLIDER (Scrollbar)
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .center, spacing: 16) {
                            // OBERE REIHE
                            HStack(spacing: 24) {
                                ForEach(viewModel.currentMachine.options.indices, id: \.self) { index in
                                    let opt = viewModel.currentMachine.options[index]
                                    if topRowKeys.contains(opt.key) {
                                        ControlView(opt: opt, index: index, viewModel: viewModel, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                                    }
                                }
                            }

                            // UNTERE REIHE
                            HStack(spacing: 24) {
                                ForEach(viewModel.currentMachine.options.indices, id: \.self) { index in
                                    let opt = viewModel.currentMachine.options[index]
                                    if bottomRowKeys.contains(opt.key) {
                                        ControlView(opt: opt, index: index, viewModel: viewModel, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
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
                                title: "Save Image...",
                                isAppleII: isAppleII,
                                isC64: isC64,
                                isDisabled: viewModel.convertedImage == nil,
                                menuItems: {
                                    Button("PNG") { viewModel.saveImage(as: .png) }
                                    Button("JPG") { viewModel.saveImage(as: .jpg) }
                                    Button("GIF") { viewModel.saveImage(as: .gif) }
                                    Button("TIFF") { viewModel.saveImage(as: .tiff) }
                                    Divider()
                                    if let asset = viewModel.currentResult?.fileAssets.first {
                                        let ext = asset.pathExtension.uppercased()
                                        Button("Native (.\(ext))") { viewModel.saveNativeFile() }
                                    } else {
                                        Button("Native Format") { }.disabled(true)
                                    }
                                }
                            )

                            // Retro-styled ProDOS Disk Button
                            RetroActionButton(
                                title: "ProDOS Disk",
                                isAppleII: isAppleII,
                                isC64: isC64,
                                isDisabled: viewModel.convertedImage == nil
                            ) {
                                showDiskSheet = true
                            }
                            .sheet(isPresented: $showDiskSheet) {
                                DiskExportSheet(
                                    isPresented: $showDiskSheet,
                                    selectedSize: $selectedDiskSize,
                                    selectedFormat: $selectedDiskFormat,
                                    volumeName: $diskVolumeName
                                ) {
                                    viewModel.createProDOSDisk(
                                        size: selectedDiskSize,
                                        format: selectedDiskFormat,
                                        volumeName: diskVolumeName
                                    )
                                }
                            }
                        } else {
                            // Standard macOS buttons
                            Menu {
                                Button("PNG") { viewModel.saveImage(as: .png) }
                                Button("JPG") { viewModel.saveImage(as: .jpg) }
                                Button("GIF") { viewModel.saveImage(as: .gif) }
                                Button("TIFF") { viewModel.saveImage(as: .tiff) }
                                Divider()
                                if let asset = viewModel.currentResult?.fileAssets.first {
                                    let ext = asset.pathExtension.uppercased()
                                    Button("Native Apple II (.\(ext))") { viewModel.saveNativeFile() }
                                } else {
                                    Button("Native Format") { }.disabled(true)
                                }
                            } label: {
                                Label("Save Image...", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                            .menuStyle(.borderedButton)
                            .controlSize(.regular)
                            .disabled(viewModel.convertedImage == nil)

                            Button(action: { showDiskSheet = true }) {
                                Label("ProDOS Disk", systemImage: "externaldrive")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(viewModel.convertedImage == nil)
                            .sheet(isPresented: $showDiskSheet) {
                                DiskExportSheet(
                                    isPresented: $showDiskSheet,
                                    selectedSize: $selectedDiskSize,
                                    selectedFormat: $selectedDiskFormat,
                                    volumeName: $diskVolumeName
                                ) {
                                    viewModel.createProDOSDisk(
                                        size: selectedDiskSize,
                                        format: selectedDiskFormat,
                                        volumeName: diskVolumeName
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
    var isRetro: Bool = false
    var isAppleII: Bool = false

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
            }
            .frame(height: 80)
            .overlay(
                Group {
                    if isRetro {
                        Rectangle()
                            .stroke(isSelected ? themeBorderColor : Color.clear, lineWidth: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
                    }
                }
            )

            Text(item.name)
                .font(isRetro ? (isAppleII ? AppleIITheme.font(size: 10) : RetroTheme.font(size: 10)) : .caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(isRetro ? themeTextColor : (isSelected ? .primary : .secondary))
        }
        .padding(6)
        .background(isSelected ? (isRetro ? themeBgColor : Color.accentColor.opacity(0.12)) : Color.clear)
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
                                    let isFloat = ["gamma", "saturation", "dither_amount"].contains(opt.key)
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
        let font = NSFont(name: "Shaston640", size: 16) ?? NSFont.systemFont(ofSize: 16)
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
        if let shastonFont = NSFont(name: "Shaston640", size: 16) {
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
            if let item = popup.lastItem, let shastonFont = NSFont(name: "Shaston640", size: 16) {
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
