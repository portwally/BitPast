import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ConverterViewModel()
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
    
    var body: some View {
        VStack(spacing: 0) {

            // 1. OBERER BEREICH: SPLIT VIEW
            HSplitView {
                // LINKER BEREICH: IMAGE BROWSER
                VStack(spacing: 0) {
                    HStack {
                        Text("Image Browser")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        if viewModel.selectedImageId != nil {
                            Button(action: { viewModel.removeSelectedImage() }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove selected image")
                        }
                        Button(action: { viewModel.selectImagesFromFinder() }) {
                            Image(systemName: "plus.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Add images")
                    }
                    .frame(height: 38)
                    .padding(.horizontal, 12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                    Divider()
                    
                    if viewModel.inputImages.isEmpty {
                        ZStack {
                            Color(NSColor.controlBackgroundColor).opacity(0.3)
                            VStack(spacing: 16) {
                                Image(systemName: "photo.stack")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 64, height: 64)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                                Text("Drag Images Here")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Text("or click + to add")
                                    .font(.subheadline)
                                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                            }
                            .padding()
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(viewModel.inputImages) { item in
                                    ImageGridItem(item: item, isSelected: viewModel.selectedImageId == item.id)
                                        .onTapGesture {
                                            viewModel.selectedImageId = item.id
                                            viewModel.convertImmediately()
                                        }
                                }
                            }.padding(10)
                        }.background(Color(NSColor.controlBackgroundColor))
                    }
                }
                .frame(minWidth: 200, maxWidth: 450)
                .onDrop(of: [.fileURL], isTargeted: $isDropTarget) { providers in return viewModel.handleDrop(providers: providers) }
                
                // RECHTER BEREICH: VORSCHAU
                VStack(spacing: 0) {
                    HStack {
                        Text("Preview")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Button(action: { if zoomLevel > 0.2 { zoomLevel -= 0.2 } }) {
                                Image(systemName: "minus.magnifyingglass")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Zoom out")

                            Text("\(Int(zoomLevel * 100))%")
                                .monospacedDigit()
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 45)

                            Button(action: { if zoomLevel < 5.0 { zoomLevel += 0.2 } }) {
                                Image(systemName: "plus.magnifyingglass")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Zoom in")
                        }
                    }
                    .frame(height: 38)
                    .padding(.horizontal, 12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                    Divider()
                    
                    ZStack {
                        Color(NSColor.black)
                        if let img = viewModel.convertedImage {
                            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                                Image(nsImage: img)
                                    .resizable()
                                    .interpolation(.none)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: img.size.width * zoomLevel, height: img.size.height * zoomLevel)
                                    .shadow(color: .black.opacity(0.3), radius: 10)
                            }
                        } else if viewModel.isConverting {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Converting...")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.arrow.down")
                                    .font(.system(size: 48))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.white.opacity(0.3))
                                Text("Select an image to preview")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }.frame(minWidth: 350)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // 2. UNTERER BEREICH: FIXED HEIGHT
            VStack(spacing: 0) {
                if let error = viewModel.errorMessage {
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
                    .background(Color.orange.opacity(0.1))
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                }
                
                HStack(spacing: 0) {
                    
                    // A. LINKS: SYSTEM (Feste Breite, Symmetrisch zu Rechts)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SYSTEM")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 8) {
                            // BUTTON 1: Apple II
                            SystemSelectButton(
                                iconName: "icon_apple2",
                                machineName: viewModel.machines[0].name,
                                isSelected: viewModel.selectedMachineIndex == 0
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
                                    isSelected: viewModel.selectedMachineIndex == 1
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
                                    isSelected: viewModel.selectedMachineIndex == 2
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
                    .frame(width: sideColumnWidth) // Breite erhöht
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    
                    Divider()
                    
                    // B. MITTE: SLIDER (Scrollbar)
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .center, spacing: 16) {
                            // OBERE REIHE
                            HStack(spacing: 24) {
                                ForEach(viewModel.currentMachine.options.indices, id: \.self) { index in
                                    let opt = viewModel.currentMachine.options[index]
                                    if topRowKeys.contains(opt.key) {
                                        ControlView(opt: opt, index: index, viewModel: viewModel)
                                    }
                                }
                            }

                            Divider()
                                .padding(.horizontal, 20)

                            // UNTERE REIHE
                            HStack(spacing: 24) {
                                ForEach(viewModel.currentMachine.options.indices, id: \.self) { index in
                                    let opt = viewModel.currentMachine.options[index]
                                    if bottomRowKeys.contains(opt.key) {
                                        ControlView(opt: opt, index: index, viewModel: viewModel)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .frame(minWidth: 300, maxWidth: .infinity)
                    }
                    
                    Divider()
                    
                    // C. RECHTS: ACTIONS (Feste Breite, Symmetrisch zu Links)
                    VStack(spacing: 12) {
                        Text("ACTIONS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
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
                        Spacer()
                    }
                    .padding(12)
                    .frame(width: sideColumnWidth) // Breite erhöht
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
            .frame(height: 180)
            
        }.frame(minWidth: 1000, minHeight: 650)
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

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

                Image(nsImage: item.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 70)
                    .padding(4)
            }
            .frame(height: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
            )

            Text(item.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .padding(6)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .cornerRadius(10)
    }
}

struct ControlView: View {
    let opt: ConversionOption
    let index: Int
    @ObservedObject var viewModel: ConverterViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(opt.label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(minWidth: 40)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(4)
                }
            } else if opt.type == .picker {
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
        .id(opt.id)
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
                value.contains("280x192 (HGR Native)") || value.contains("560x384 (DHGR Best)")
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
    let action: () -> Void

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
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                }

                Text(machineName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 4)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .imageScale(.medium)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.2) : Color.black.opacity(0.05), radius: isSelected ? 4 : 2, x: 0, y: isSelected ? 2 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color(NSColor.separatorColor).opacity(0.5), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
