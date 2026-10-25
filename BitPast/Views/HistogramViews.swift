import SwiftUI

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
