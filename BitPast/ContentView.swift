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
    
    // Layout Konstante für Symmetrie
    let sideColumnWidth: CGFloat = 170
    
    // Keys für die Anzeige
    let topRowKeys = ["mode", "colortype", "dither", "palette", "saturation"]
    let bottomRowKeys = ["resolution", "crosshatch", "z_threshold", "error_matrix", "gamma", "dither_amount", "threshold"]
    
    var body: some View {
        VStack(spacing: 0) {
            
            // 1. OBERER BEREICH: SPLIT VIEW
            HSplitView {
                // LINKER BEREICH: IMAGE BROWSER
                VStack(spacing: 0) {
                    HStack {
                        Text("Image Browser").font(.headline).foregroundColor(.secondary)
                        Spacer()
                        if viewModel.selectedImageId != nil {
                            Button(action: { viewModel.removeSelectedImage() }) { Image(systemName: "trash") }.buttonStyle(.plain)
                        }
                        Button(action: { viewModel.selectImagesFromFinder() }) { Image(systemName: "plus") }
                    }
                    .padding(8).background(Color(NSColor.controlBackgroundColor))
                    
                    if viewModel.inputImages.isEmpty {
                        ZStack {
                            Color(NSColor.controlBackgroundColor)
                            VStack(spacing: 15) {
                                Image(systemName: "photo.stack").resizable().aspectRatio(contentMode: .fit).frame(width: 50, height: 50).symbolRenderingMode(.hierarchical).foregroundColor(.secondary)
                                Text("Drag Images Here").font(.headline).foregroundColor(.secondary)
                            }
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
                        Text("Preview").font(.headline).foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 0) {
                            Button(action: { if zoomLevel > 0.2 { zoomLevel -= 0.2 } }) { Image(systemName: "minus.magnifyingglass") }.buttonStyle(.bordered)
                            Text("\(Int(zoomLevel * 100))%").monospacedDigit().font(.caption).frame(width: 45)
                            Button(action: { if zoomLevel < 5.0 { zoomLevel += 0.2 } }) { Image(systemName: "plus.magnifyingglass") }.buttonStyle(.bordered)
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .border(Color(NSColor.separatorColor), width: 0.5)
                    
                    ZStack {
                        Color.black
                        if let img = viewModel.convertedImage {
                            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                                Image(nsImage: img).resizable().interpolation(.none).aspectRatio(contentMode: .fit)
                                    .frame(width: img.size.width * zoomLevel, height: img.size.height * zoomLevel)
                            }
                        } else if viewModel.isConverting {
                            ProgressView("Converting...").colorScheme(.dark)
                        } else {
                            Text("Ready").foregroundColor(.gray)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }.frame(minWidth: 350)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // 2. UNTERER BEREICH: FIXED HEIGHT
            VStack(spacing: 0) {
                if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red).font(.caption).frame(maxWidth: .infinity).background(Color.black.opacity(0.1))
                }
                
                HStack(spacing: 0) {
                    
                    // A. LINKS: SYSTEM (Feste Breite, Symmetrisch zu Rechts)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SYSTEM").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 8) {
                            SystemSelectButton(
                                iconName: "cpu",
                                machineName: viewModel.machines[0].name,
                                isSelected: viewModel.selectedMachineIndex == 0
                            ) {
                                if viewModel.selectedMachineIndex != 0 {
                                    viewModel.selectedMachineIndex = 0
                                    viewModel.triggerLivePreview()
                                }
                            }
                            
                            if viewModel.machines.count > 1 {
                                SystemSelectButton(
                                    iconName: "display.2",
                                    machineName: viewModel.machines[1].name,
                                    isSelected: viewModel.selectedMachineIndex == 1
                                ) {
                                    if viewModel.selectedMachineIndex != 1 {
                                        viewModel.selectedMachineIndex = 1
                                        viewModel.triggerLivePreview()
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .frame(width: sideColumnWidth) // SYMMETRIE LINKS
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    
                    Divider()
                    
                    // B. MITTE: SLIDER (Scrollbar)
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            // OBERE REIHE
                            HStack(spacing: 15) {
                                ForEach(viewModel.currentMachine.options.indices, id: \.self) { index in
                                    let opt = viewModel.currentMachine.options[index]
                                    if topRowKeys.contains(opt.key) {
                                        ControlView(opt: opt, index: index, viewModel: viewModel)
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // UNTERE REIHE
                            HStack(spacing: 15) {
                                ForEach(viewModel.currentMachine.options.indices, id: \.self) { index in
                                    let opt = viewModel.currentMachine.options[index]
                                    if bottomRowKeys.contains(opt.key) {
                                        ControlView(opt: opt, index: index, viewModel: viewModel)
                                    }
                                }
                            }
                        }
                        .padding(12)
                    }
                    
                    Divider()
                    
                    // C. RECHTS: ACTIONS (Feste Breite, Symmetrisch zu Links)
                    VStack(spacing: 10) {
                        Text("ACTIONS").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                        
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
                        }
                        .menuStyle(.borderedButton)
                        .frame(maxWidth: .infinity)
                        .disabled(viewModel.convertedImage == nil)
                        
                        Button(action: { showDiskSheet = true }) {
                            Label("ProDOS Disk", systemImage: "externaldrive")
                        }
                        .frame(maxWidth: .infinity)
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
                    .frame(width: sideColumnWidth) // SYMMETRIE RECHTS
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
            .frame(height: 150)
            
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
        VStack(spacing: 20) {
            Text("Create ProDOS Disk").font(.headline)
            Form {
                TextField("Volume Name:", text: $volumeName).frame(width: 200).help("Max 15 characters")
                Picker("Disk Size:", selection: $selectedSize) { ForEach(ConverterViewModel.DiskSize.allCases) { size in Text(size.rawValue).tag(size) } }
                Picker("Format:", selection: $selectedFormat) { ForEach(ConverterViewModel.DiskFormat.allCases) { format in Text(format.rawValue.uppercased()).tag(format) } }
            }.padding(.horizontal)
            HStack {
                Button("Cancel") { isPresented = false }.keyboardShortcut(.cancelAction)
                Button("Create Disk Image") { isPresented = false; onExport() }.keyboardShortcut(.defaultAction)
            }
        }.padding().frame(width: 350)
    }
}

struct ImageGridItem: View {
    let item: InputImage; let isSelected: Bool
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Color(NSColor.controlBackgroundColor)
                Image(nsImage: item.image).resizable().aspectRatio(contentMode: .fit).frame(height: 70)
            }.frame(height: 80).cornerRadius(6).padding(4).overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3))
            Text(item.name).font(.caption).lineLimit(1).truncationMode(.middle)
        }.padding(4).background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear).cornerRadius(8)
    }
}

struct ControlView: View {
    let opt: ConversionOption
    let index: Int
    @ObservedObject var viewModel: ConverterViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(opt.label.uppercased()).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
            
            if opt.type == .slider {
                HStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { Double(opt.selectedValue) ?? 0.0 },
                            set: { val in
                                let isFloat = ["gamma", "saturation", "dither_amount"].contains(opt.key)
                                viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = isFloat ? String(format: "%.2f", val) : String(format: "%.0f", val)
                                viewModel.triggerLivePreview()
                            }
                        ),
                        in: opt.range
                    ).frame(width: 90)
                    Text(opt.selectedValue).monospacedDigit().font(.caption2).frame(width: 30, alignment: .trailing)
                }
            } else if opt.type == .picker {
                Picker("", selection: Binding(
                    get: { viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue },
                    set: { val in
                        viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = val
                        viewModel.triggerLivePreview()
                    }
                )) {
                    ForEach(opt.values, id: \.self) { val in Text(val).tag(val) }
                }.frame(minWidth: 100).controlSize(.small)
            }
        }
        .id(opt.key)
    }
}

// System Button - angepasst auf variable Breite
struct SystemSelectButton: View {
    let iconName: String
    let machineName: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) { // HStack statt VStack für breiteres Layout
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 18)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Text(machineName)
                    .font(.system(size: 11))
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer() // Schiebt Inhalt nach links
            }
            .padding(.horizontal, 10) // Innenabstand
            .frame(maxWidth: .infinity) // Nimmt die ganze Breite der Spalte ein
            .frame(height: 36) // Feste Höhe pro Button
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
