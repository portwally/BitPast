import SwiftUI

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let label: String
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var isC64: Bool = false
    var disabled: Bool = false
    var isActive: Bool = false
    let action: () -> Void

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
        return Color.clear
    }
    var themeBorderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        if isRetro { return RetroTheme.borderColor }
        return Color.gray.opacity(0.3)
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 9) }
        if isAppleII { return AppleIITheme.font(size: 9) }
        if isRetro { return .system(size: 8) }  // Smaller text for IIgs buttons
        return .system(size: 9)
    }
    var activeColor: Color {
        if isC64 { return C64Theme.textColor.opacity(0.3) }
        if isAppleII { return AppleIITheme.textColor.opacity(0.3) }
        if isRetro { return Color.blue.opacity(0.2) }
        return Color.accentColor.opacity(0.2)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isRetro || isAppleII || isC64 ? themeTextColor : nil)
                    .frame(width: 20, height: 16)
                Text(label)
                    .font(themeFont)
                    .foregroundColor(isRetro || isAppleII || isC64 ? themeTextColor : nil)
                    .lineLimit(1)
            }
            .frame(width: 50, height: 34)
            .background(isActive ? activeColor : (isRetro || isAppleII || isC64 ? themeBgColor : Color.clear))
            .cornerRadius(isRetro || isAppleII || isC64 ? 0 : 4)
            .overlay(
                (isRetro || isAppleII || isC64) ?
                Rectangle().stroke(themeBorderColor, lineWidth: 1) : nil
            )
        }
        .buttonStyle(.plain)
        .background(
            Group {
                if !(isRetro || isAppleII || isC64) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                }
            }
        )
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1.0)
        .help(label)
    }
}
