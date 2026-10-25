import SwiftUI

// MARK: - Image Info Panel

struct ImageInfoPanel: View {
    @ObservedObject var viewModel: ConverterViewModel
    var isRetro: Bool
    var isAppleII: Bool
    var isC64: Bool

    var themeBgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        return RetroTheme.contentGray
    }
    var themeTextColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return RetroTheme.textColor
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 9) }
        if isAppleII { return AppleIITheme.font(size: 9) }
        return .custom("Shaston 640", size: 10)  // Smaller Shaston for compact display
    }
    var themeBoldFont: Font {
        if isC64 { return C64Theme.boldFont(size: 9) }
        if isAppleII { return AppleIITheme.boldFont(size: 9) }
        return .custom("Shaston 640", size: 10)
    }

    var selectedImage: InputImage? {
        guard let id = viewModel.selectedImageId else { return nil }
        return viewModel.inputImages.first(where: { $0.id == id })
    }

    // Get current mode from machine options
    var currentMode: String? {
        viewModel.currentMachine.options.first(where: { $0.key == "mode" })?.selectedValue
    }

    // Get color count from mode name or palette
    var colorCount: String? {
        if let result = viewModel.currentResult, !result.palettes.isEmpty {
            let count = result.palettes.first?.count ?? 0
            return "\(count)"
        }
        // Try to parse from mode name (e.g., "Mode 2 (8 colors)")
        if let mode = currentMode {
            if let range = mode.range(of: #"(\d+)\s*colors?"#, options: .regularExpression) {
                let match = mode[range]
                if let numRange = match.range(of: #"\d+"#, options: .regularExpression) {
                    return String(match[numRange])
                }
            }
            // Check for common patterns
            if mode.contains("2 colors") || mode.contains("Mono") || mode.contains("HiRes") { return "2" }
            if mode.contains("4 colors") { return "4" }
            if mode.contains("8 colors") { return "8" }
            if mode.contains("16 colors") || mode.contains("16 shades") || mode.contains("16 hues") { return "16" }
            if mode.contains("256") { return "256" }
        }
        return nil
    }

    // Format output file size
    func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) bytes"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }

    // Get output file size
    var outputFileSize: String? {
        guard let fileUrl = viewModel.currentResult?.fileAssets.first,
              let attrs = try? FileManager.default.attributesOfItem(atPath: fileUrl.path),
              let size = attrs[.size] as? Int64 else { return nil }
        return formatFileSize(size)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // INPUT SECTION
            Text(isRetro ? "INPUT" : "INPUT")
                .font(isRetro ? themeFont : .system(size: 9, weight: .semibold))
                .foregroundColor(isRetro ? themeTextColor : .secondary)
                .tracking(0.5)

            if let img = selectedImage {
                VStack(alignment: .leading, spacing: 2) {
                    InfoRow(label: "File", value: img.name, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                    InfoRow(label: "Size", value: "\(Int(img.image.size.width))×\(Int(img.image.size.height))", isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                    if let fileSize = img.formattedFileSize {
                        InfoRow(label: "FileSize", value: fileSize, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                    }
                    InfoRow(label: "Format", value: img.format, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                    if let bpp = img.bitsPerPixel {
                        let alphaStr = img.hasAlpha ? " (α)" : ""
                        InfoRow(label: "Depth", value: "\(bpp)-bit\(alphaStr)", isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                    }
                }

                // OUTPUT SECTION
                if let result = viewModel.currentResult {
                    if isRetro {
                        Rectangle().fill(themeTextColor.opacity(0.3)).frame(height: 1).padding(.vertical, 2)
                    } else {
                        Divider().padding(.vertical, 2)
                    }

                    Text(isRetro ? "OUTPUT" : "OUTPUT")
                        .font(isRetro ? themeFont : .system(size: 9, weight: .semibold))
                        .foregroundColor(isRetro ? themeTextColor : .secondary)
                        .tracking(0.5)

                    VStack(alignment: .leading, spacing: 2) {
                        InfoRow(label: "System", value: viewModel.currentMachine.name, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                        if let mode = currentMode {
                            // Shorten mode name for display
                            let shortMode = mode.replacingOccurrences(of: " (", with: "\n(").components(separatedBy: "\n").first ?? mode
                            InfoRow(label: "Mode", value: shortMode, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                        }
                        InfoRow(label: "Size", value: "\(result.imageWidth)×\(result.imageHeight)", isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                        if let colors = colorCount {
                            InfoRow(label: "Colors", value: colors, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                        }
                        if let fileUrl = result.fileAssets.first {
                            InfoRow(label: "Format", value: ".\(fileUrl.pathExtension)", isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                        }
                        if let fileSize = outputFileSize {
                            InfoRow(label: "FileSize", value: fileSize, isRetro: isRetro, isAppleII: isAppleII, isC64: isC64)
                        }
                    }
                }
            } else {
                Text(isRetro ? "NO IMAGE" : "No image selected")
                    .font(isRetro ? themeFont : .system(size: 9))
                    .foregroundColor(isRetro ? themeTextColor.opacity(0.5) : .secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var isC64: Bool = false

    var themeTextColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return RetroTheme.textColor
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 8) }
        if isAppleII { return AppleIITheme.font(size: 8) }
        return .custom("Shaston 640", size: 9)  // Smaller Shaston for compact display
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(isRetro ? "\(label.uppercased()):" : "\(label):")
                .font(isRetro ? themeFont : .system(size: 9))
                .foregroundColor(isRetro ? themeTextColor.opacity(0.6) : .secondary)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(isRetro ? themeFont : .system(size: 9, weight: .medium))
                .foregroundColor(isRetro ? themeTextColor : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
