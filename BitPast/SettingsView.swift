import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var selectedMode: AppearanceMode

    init() {
        _selectedMode = State(initialValue: AppSettings.shared.appearanceMode)
    }

    var isRetro: Bool { settings.isRetroMode }

    var body: some View {
        Form {
            Text("Appearance")
                .font(isRetro ? RetroTheme.boldFont(size: 14) : .headline)
                .foregroundColor(isRetro ? RetroTheme.textColor : .primary)

            Picker("", selection: $selectedMode) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue)
                        .font(isRetro ? RetroTheme.font(size: 12) : .body)
                        .tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .onChange(of: selectedMode) { newValue in
                settings.appearanceMode = newValue
            }
        }
        .padding(20)
        .frame(width: 300, height: 200)
        .background(isRetro ? RetroTheme.backgroundColor : Color.clear)
    }
}
