import SwiftUI

// MARK: - Retro Action Button

/// Retro-styled action button for Apple II, C64, and IIgs themes
struct RetroActionButton: View {
    let title: String
    let isAppleII: Bool
    var isC64: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    // Theme colors
    var bgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        return RetroTheme.windowBackground
    }
    var textColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return RetroTheme.textColor
    }
    var borderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        return RetroTheme.borderColor
    }
    var disabledColor: Color {
        if isC64 { return C64Theme.textColor.opacity(0.4) }
        if isAppleII { return AppleIITheme.dimTextColor }
        return RetroTheme.textColor.opacity(0.4)
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 12) }
        if isAppleII { return AppleIITheme.font(size: 12) }
        return RetroTheme.font(size: 12)
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if isAppleII {
                    Text("[ \(title) ]")
                        .font(themeFont)
                        .foregroundColor(isDisabled ? disabledColor : textColor)
                } else if isC64 {
                    Text("[ \(title) ]")
                        .font(themeFont)
                        .foregroundColor(isDisabled ? disabledColor : textColor)
                        .textCase(.uppercase)
                } else {
                    Text(title)
                        .font(themeFont)
                        .foregroundColor(isDisabled ? disabledColor : textColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background(bgColor)
        .overlay(
            Rectangle()
                .stroke(isDisabled ? disabledColor : borderColor, lineWidth: 2)
        )
    }
}

// MARK: - Retro Action Menu

/// Retro-styled dropdown menu for Apple II, C64, and IIgs themes
struct RetroActionMenu<MenuItems: View>: View {
    let title: String
    let isAppleII: Bool
    var isC64: Bool = false
    var isDisabled: Bool = false
    @ViewBuilder let menuItems: () -> MenuItems

    // Theme colors
    var bgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        return RetroTheme.windowBackground
    }
    var textColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return RetroTheme.textColor
    }
    var borderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        return RetroTheme.borderColor
    }
    var disabledColor: Color {
        if isC64 { return C64Theme.textColor.opacity(0.4) }
        if isAppleII { return AppleIITheme.dimTextColor }
        return RetroTheme.textColor.opacity(0.4)
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 12) }
        if isAppleII { return AppleIITheme.font(size: 12) }
        return RetroTheme.font(size: 12)
    }
    var themeSmallFont: Font {
        if isC64 { return C64Theme.font(size: 10) }
        if isAppleII { return AppleIITheme.font(size: 10) }
        return RetroTheme.font(size: 8)
    }

    var body: some View {
        Menu {
            menuItems()
        } label: {
            HStack {
                if isAppleII {
                    Text("[ \(title) ]")
                        .font(themeFont)
                        .foregroundColor(isDisabled ? disabledColor : textColor)
                } else if isC64 {
                    Text("[ \(title) ]")
                        .font(themeFont)
                        .foregroundColor(isDisabled ? disabledColor : textColor)
                        .textCase(.uppercase)
                } else {
                    Text(title)
                        .font(themeFont)
                        .foregroundColor(isDisabled ? disabledColor : textColor)
                }
                Spacer()
                Text(isAppleII || isC64 ? "v" : "▼")
                    .font(themeSmallFont)
                    .foregroundColor(isDisabled ? disabledColor : textColor)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .menuStyle(.borderlessButton)
        .disabled(isDisabled)
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background(bgColor)
        .overlay(
            Rectangle()
                .stroke(isDisabled ? disabledColor : borderColor, lineWidth: 2)
        )
    }
}
