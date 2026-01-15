import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var selectedMode: AppearanceMode

    init() {
        _selectedMode = State(initialValue: AppSettings.shared.appearanceMode)
    }

    var isRetro: Bool { settings.isRetroMode }
    var isAppleII: Bool { settings.isAppleIIMode }

    // Theme-aware colors
    var themeTextColor: Color { isAppleII ? AppleIITheme.textColor : RetroTheme.textColor }
    var themeBgColor: Color { isAppleII ? AppleIITheme.backgroundColor : RetroTheme.backgroundColor }
    var themeFont: Font { isAppleII ? AppleIITheme.font(size: 14) : RetroTheme.boldFont(size: 14) }
    var themeSmallFont: Font { isAppleII ? AppleIITheme.font(size: 12) : RetroTheme.font(size: 12) }

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
        .frame(width: 300, height: 200)
        .background(isRetro ? themeBgColor : Color.clear)
    }
}
