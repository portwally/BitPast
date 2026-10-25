import SwiftUI

extension ContentView {
    /// Bottom panel: image info, option controls and actions.
    var bottomPanel: some View {
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
                optionControls

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
                actionsColumn
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

    /// Middle of the bottom panel: the converter's options, in vertical groups.
    var optionControls: some View {
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
    }

    /// Right of the bottom panel: convert, save and disk actions.
    var actionsColumn: some View {
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
