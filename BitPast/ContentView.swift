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
    
    // Keys für die Anzeige
    // Keys für die Anzeige
        let topRowKeys = ["mode", "colortype", "dither", "palette", "saturation"]
        
        // UPDATE HIER: Neue Keys hinzufügen (z_threshold, error_matrix, hue_tweak)
        let bottomRowKeys = ["resolution", "crosshatch", "z_threshold", "error_matrix", "hue_tweak", "bleed", "gamma", "dither_amount", "threshold"]
    
    func binding(for index: Int) -> Binding<String> {
        Binding(
            get: {
                if index < viewModel.machines[viewModel.selectedMachineIndex].options.count {
                    return viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue
                }
                return ""
            },
            set: { newValue in
                if index < viewModel.machines[viewModel.selectedMachineIndex].options.count {
                    viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = newValue
                    viewModel.triggerLivePreview()
                }
            }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
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
                    .padding(10).background(Color(NSColor.controlBackgroundColor))
                    
                    if viewModel.inputImages.isEmpty {
                        ZStack {
                            Color(NSColor.controlBackgroundColor)
                            VStack(spacing: 15) {
                                Image(systemName: "photo.stack").resizable().aspectRatio(contentMode: .fit).frame(width: 60, height: 60).symbolRenderingMode(.hierarchical).foregroundColor(.secondary)
                                Text("Drag Images Here").font(.headline).foregroundColor(.secondary)
                            }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 15) {
                                ForEach(viewModel.inputImages) { item in
                                    ImageGridItem(item: item, isSelected: viewModel.selectedImageId == item.id)
                                        .onTapGesture {
                                            viewModel.selectedImageId = item.id
                                            viewModel.convertImmediately()
                                        }
                                }
                            }.padding()
                        }.background(Color(NSColor.controlBackgroundColor))
                    }
                }
                .frame(minWidth: 220, maxWidth: 500)
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
                    }.padding(8).background(Color(NSColor.controlBackgroundColor)).border(Color(NSColor.separatorColor), width: 0.5)
                    
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
                }.frame(minWidth: 400)
            }
            Divider()
            
            // UNTERER BEREICH: OPTIONEN & EXPORT
            VStack(spacing: 0) {
                if let error = viewModel.errorMessage { Text(error).foregroundColor(.red).font(.caption).frame(maxWidth: .infinity).padding(.top, 4) }
                
                VStack(alignment: .leading, spacing: 12) {
                    
                    // ZEILE 1: System + Top Keys
                    HStack(spacing: 20) {
                        // SYSTEM AUSWAHL
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SYSTEM").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                            Picker("", selection: $viewModel.selectedMachineIndex) {
                                ForEach(0..<viewModel.machines.count, id: \.self) { i in Text(viewModel.machines[i].name) }
                            }.frame(width: 140).onChange(of: viewModel.selectedMachineIndex) { _ in viewModel.triggerLivePreview() }
                        }
                        Divider().frame(height: 20)
                        
                        // OBERE REIHE OPTIONEN
                        ForEach(viewModel.currentMachine.options.indices, id: \.self) { index in
                            let opt = viewModel.currentMachine.options[index]
                            
                            if topRowKeys.contains(opt.key) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(opt.label.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                                    
                                    if opt.type == .slider {
                                                                            HStack {
                                                                                Slider(
                                                                                    value: Binding(
                                                                                        get: { Double(opt.selectedValue) ?? 0.0 },
                                                                                        set: { newValue in
                                                                                            // HIER: Intelligente Formatierung
                                                                                            let isFloatParams = ["gamma", "saturation", "dither_amount"].contains(opt.key)
                                                                                            let fmt = isFloatParams ? String(format: "%.2f", newValue) : String(format: "%.0f", newValue)
                                                                                            
                                                                                            viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = fmt
                                                                                            viewModel.triggerLivePreview()
                                                                                        }
                                                                                    ),
                                                                                    in: opt.range
                                                                                ).frame(width: 100)
                                                                                Text(opt.selectedValue).monospacedDigit().font(.caption).frame(width: 35, alignment: .trailing)
                                                                            }
                                    } else if opt.type == .picker { // FIX: Strikte Prüfung statt "else"
                                        Picker("", selection: binding(for: index)) {
                                            ForEach(opt.values, id: \.self) { val in Text(val).tag(val) }
                                        }.frame(minWidth: 110)
                                    }
                                }
                                .id(opt.key) // FIX: Zwingt SwiftUI zum Neubau bei Wechsel
                            }
                        }
                        Spacer()
                    }
                    
                    // ZEILE 2: Bottom Keys + Export
                    HStack(spacing: 20) {
                        // UNTERE REIHE OPTIONEN
                        ForEach(viewModel.currentMachine.options.indices, id: \.self) { index in
                            let opt = viewModel.currentMachine.options[index]
                            
                            if bottomRowKeys.contains(opt.key) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(opt.label.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                                    
                                    if opt.type == .slider {
                                                                            HStack {
                                                                                Slider(
                                                                                    value: Binding(
                                                                                        get: { Double(opt.selectedValue) ?? 0.0 },
                                                                                        set: { newValue in
                                                                                            // HIER: Intelligente Formatierung
                                                                                            let isFloatParams = ["gamma", "saturation", "dither_amount"].contains(opt.key)
                                                                                            let fmt = isFloatParams ? String(format: "%.2f", newValue) : String(format: "%.0f", newValue)
                                                                                            
                                                                                            viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = fmt
                                                                                            viewModel.triggerLivePreview()
                                                                                        }
                                                                                    ),
                                                                                    in: opt.range
                                                                                ).frame(width: 100)
                                                                                Text(opt.selectedValue).monospacedDigit().font(.caption).frame(width: 35, alignment: .trailing)
                                                                            }
                                    } else if opt.type == .picker { // FIX: Strikte Prüfung
                                        Picker("", selection: binding(for: index)) {
                                            ForEach(opt.values, id: \.self) { val in Text(val).tag(val) }
                                        }.frame(width: 150)
                                    }
                                }
                                .id(opt.key) // FIX: Unique Identity
                            }
                        }
                        
                        Divider().frame(height: 20)
                        
                        // EXPORT BUTTONS
                        VStack(alignment: .leading, spacing: 8) {
                            Text("EXPORT").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                            HStack {
                                Menu {
                                                                    // Standard Bild-Formate
                                                                    Button("PNG") { viewModel.saveImage(as: .png) }
                                                                    Button("JPG") { viewModel.saveImage(as: .jpg) }
                                                                    Button("GIF") { viewModel.saveImage(as: .gif) }
                                                                    Button("TIFF") { viewModel.saveImage(as: .tiff) }
                                                                    
                                                                    Divider()
                                                                    
                                                                    // Native Retro-Formate
                                                                    // Wir prüfen dynamisch, welche Datei verfügbar ist
                                                                    if let asset = viewModel.currentResult?.fileAssets.first {
                                                                        let ext = asset.pathExtension.uppercased()
                                                                        Button("Native Apple II (.\(ext))") {
                                                                            viewModel.saveNativeFile()
                                                                        }
                                                                    } else {
                                                                        Button("Native Format") { }.disabled(true)
                                                                    }
                                                                    
                                                                } label: {
                                                                    Label("Save Image...", systemImage: "photo")
                                                                }
                                                                .fixedSize()
                                                                .disabled(viewModel.convertedImage == nil)
                                .fixedSize()
                                .disabled(viewModel.convertedImage == nil)
                                
                                Button(action: { showDiskSheet = true }) {
                                    Label("Create ProDOS Disk", systemImage: "externaldrive")
                                }
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
                        }
                        Spacer()
                    }
                }.padding(15)
            }.background(Color(NSColor.windowBackgroundColor)).frame(height: 140)
        }.frame(minWidth: 1000, minHeight: 700)
    }
}

// Sub-Views bleiben gleich
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
        VStack(spacing: 6) {
            ZStack {
                Color(NSColor.controlBackgroundColor)
                Image(nsImage: item.image).resizable().aspectRatio(contentMode: .fit).frame(height: 80)
            }.frame(height: 90).cornerRadius(6).padding(4).overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3))
            Text(item.name).font(.subheadline).lineLimit(1).truncationMode(.middle)
            Text(item.details).font(.caption2).foregroundColor(.secondary)
        }.padding(6).background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear).cornerRadius(8)
    }
}
