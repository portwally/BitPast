import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ConverterViewModel()
    @State private var isDropTarget = false
    @State private var zoomLevel: CGFloat = 1.0
    
    let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]
    let topRowKeys = ["mode", "colortype", "dither", "palette"]
    let bottomRowKeys = ["resolution", "crosshatch", "bleed"]
    
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
                // LEFT: BROWSER
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
                
                // RIGHT: PREVIEW
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
            
            // BOTTOM: OPTIONS
            VStack(spacing: 0) {
                if let error = viewModel.errorMessage { Text(error).foregroundColor(.red).font(.caption).frame(maxWidth: .infinity).padding(.top, 4) }
                VStack(alignment: .leading, spacing: 12) {
                    // ROW 1
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SYSTEM").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                            Picker("", selection: $viewModel.selectedMachineIndex) {
                                ForEach(0..<viewModel.machines.count, id: \.self) { i in Text(viewModel.machines[i].name) }
                            }.frame(width: 120).onChange(of: viewModel.selectedMachineIndex) { _ in viewModel.triggerLivePreview() }
                        }
                        Divider().frame(height: 20)
                        ForEach(viewModel.currentMachine.options.indices, id: \.self) { index in
                            let opt = viewModel.currentMachine.options[index]
                            if topRowKeys.contains(opt.key) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(opt.label.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                                    if opt.type == .picker {
                                        Picker("", selection: binding(for: index)) {
                                            ForEach(opt.values, id: \.self) { val in Text(val).tag(val) }
                                        }.frame(minWidth: 110)
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    // ROW 2
                    HStack(spacing: 20) {
                        ForEach(viewModel.currentMachine.options.indices, id: \.self) { index in
                            let opt = viewModel.currentMachine.options[index]
                            if bottomRowKeys.contains(opt.key) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(opt.label.uppercased()).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                                    if opt.type == .picker {
                                        Picker("", selection: binding(for: index)) {
                                            ForEach(opt.values, id: \.self) { val in Text(val).tag(val) }
                                        }.frame(width: 150)
                                    } else {
                                        HStack {
                                            Slider(value: Binding(get: { Double(opt.selectedValue) ?? 0.0 }, set: { viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = String(Int($0)); viewModel.triggerLivePreview() }), in: opt.range).frame(width: 100)
                                            Text(opt.selectedValue).monospacedDigit().font(.caption).frame(width: 25, alignment: .trailing)
                                        }
                                    }
                                }
                            }
                        }
                        Divider().frame(height: 20)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("EXPORT").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                            HStack {
                                Picker("", selection: $viewModel.selectedExportFormat) {
                                    ForEach(ConverterViewModel.ExportFormat.allCases) { fmt in Text(fmt.rawValue).tag(fmt) }
                                }.frame(width: 120)
                                Button(action: { viewModel.saveResult() }) { Label("Save", systemImage: "square.and.arrow.up") }.disabled(viewModel.convertedImage == nil)
                            }
                        }
                        Spacer()
                    }
                }.padding(15)
            }.background(Color(NSColor.windowBackgroundColor)).frame(height: 130)
        }.frame(minWidth: 1000, minHeight: 700)
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
