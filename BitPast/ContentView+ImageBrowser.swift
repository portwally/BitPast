import SwiftUI
import UniformTypeIdentifiers

extension ContentView {
    /// Left side of the split view: the loaded images, with drag and drop.
    var imageBrowserPane: some View {
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
    }
}
