import SwiftUI

// MARK: - Disk Progress Overlay

struct DiskProgressOverlay: View {
    let progress: Double
    let current: Int
    let total: Int
    let status: String
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var isC64: Bool = false

    var bgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        if isRetro { return RetroTheme.backgroundColor }
        return Color(NSColor.windowBackgroundColor)
    }

    var textColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        if isRetro { return RetroTheme.textColor }
        return .primary
    }

    var borderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        if isRetro { return RetroTheme.borderColor }
        return Color.gray.opacity(0.5)
    }

    var accentColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        if isRetro { return Color.blue }
        return Color.accentColor
    }

    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 12) }
        if isAppleII { return AppleIITheme.font(size: 12) }
        if isRetro { return RetroTheme.font(size: 12) }
        return .system(size: 12)
    }

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Progress panel
            VStack(spacing: 16) {
                Text("Creating Disk Image")
                    .font(isRetro || isAppleII || isC64 ? themeFont : .headline)
                    .foregroundColor(textColor)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 12)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(accentColor)
                            .frame(width: max(0, geometry.size.width * progress), height: 12)
                    }
                }
                .frame(height: 12)

                // Status text
                Text(status)
                    .font(isRetro || isAppleII || isC64 ? themeFont : .system(size: 11))
                    .foregroundColor(textColor.opacity(0.8))
                    .lineLimit(1)

                // Counter
                if total > 0 {
                    Text("\(current) of \(total)")
                        .font(isRetro || isAppleII || isC64 ? themeFont : .system(size: 11, weight: .medium))
                        .foregroundColor(textColor.opacity(0.7))
                }
            }
            .padding(24)
            .frame(width: 300)
            .background(bgColor)
            .cornerRadius(isRetro || isAppleII || isC64 ? 0 : 12)
            .overlay(
                RoundedRectangle(cornerRadius: isRetro || isAppleII || isC64 ? 0 : 12)
                    .stroke(borderColor, lineWidth: isRetro || isAppleII || isC64 ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }
}
