import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var selectedMode: AppearanceMode

    init() {
        _selectedMode = State(initialValue: AppSettings.shared.appearanceMode)
    }

    var isRetro: Bool { settings.isRetroMode }
    var isAppleII: Bool { settings.isAppleIIMode }
    var isC64: Bool { settings.isC64Mode }

    // Theme-aware colors
    var themeTextColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return RetroTheme.textColor
    }
    var themeBgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        return RetroTheme.backgroundColor
    }
    var themeFont: Font {
        if isC64 { return C64Theme.boldFont(size: 14) }
        if isAppleII { return AppleIITheme.font(size: 14) }
        return RetroTheme.boldFont(size: 14)
    }
    var themeSmallFont: Font {
        if isC64 { return C64Theme.font(size: 12) }
        if isAppleII { return AppleIITheme.font(size: 12) }
        return RetroTheme.font(size: 12)
    }

    var body: some View {
        Form {
            Text("Appearance")
                .font(isRetro ? themeFont : .headline)
                .foregroundColor(isRetro ? themeTextColor : .primary)

            Picker("", selection: $selectedMode) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue)
                        .font(isRetro ? themeSmallFont : .body)
                        .tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .onChange(of: selectedMode) { _, newValue in
                settings.appearanceMode = newValue
            }
        }
        .padding(20)
        .frame(width: 350, height: 200)
        .background(isRetro ? themeBgColor : Color.clear)
    }
}
