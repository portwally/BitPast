import SwiftUI

extension ContentView {
    /// Right side of the split view: the converted image preview and its toolbar.
    var previewPane: some View {
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
                        convertingIndicator
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

                    // While a new image is calculated, show the indicator over the old one
                    if viewModel.convertedImage != nil && viewModel.isConverting {
                        DelayedAppearance {
                            convertingIndicator
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(RoundedRectangle(cornerRadius: isRetro ? 0 : 12).fill(Color.black.opacity(0.65)))
                        }
                        .allowsHitTesting(false)
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

    /// Spinner and "Converting..." label, in the current theme.
    var convertingIndicator: some View {
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
    }
}
