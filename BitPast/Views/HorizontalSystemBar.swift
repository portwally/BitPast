import SwiftUI

// MARK: - Horizontal System Bar

struct HorizontalSystemBar: View {
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
    var themeBorderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        return RetroTheme.borderColor
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 11) }
        if isAppleII { return AppleIITheme.font(size: 11) }
        return RetroTheme.font(size: 10)
    }

    private let systemIcons = ["icon_apple2", "icon_iigs", "icon_Amiga500", "icon_Amiga1200", "icon_AmstradCPC", "icon_Atari800", "icon_AtariST", "icon_BBCmicro", "icon_C64", "icon_MSX", "icon_PC", "icon_commodoreplus4", "icon_TRS80", "icon_vic20", "icon_ZXSpectrum"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.machines.indices, id: \.self) { index in
                if index < systemIcons.count {
                    HorizontalSystemButton(
                        iconName: systemIcons[index],
                        machineName: viewModel.machines[index].name,
                        isSelected: viewModel.selectedMachineIndex == index,
                        isRetro: isRetro,
                        isAppleII: isAppleII,
                        isC64: isC64
                    ) {
                        if viewModel.selectedMachineIndex != index {
                            viewModel.clearAllLocks()
                            viewModel.selectedMachineIndex = index
                            viewModel.triggerLivePreview()
                        }
                    }

                    if index < viewModel.machines.count - 1 {
                        if isRetro {
                            Rectangle().fill(themeBorderColor).frame(width: 1)
                        } else {
                            Rectangle().fill(Color(NSColor.separatorColor).opacity(0.3)).frame(width: 1)
                        }
                    }
                }
            }
            Spacer()
        }
        .frame(height: 64)
        .background(isRetro ? themeBgColor : Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

struct HorizontalSystemButton: View {
    let iconName: String
    let machineName: String
    let isSelected: Bool
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var isC64: Bool = false
    let action: () -> Void

    var themeBgColor: Color {
        if isC64 { return C64Theme.backgroundColor }
        if isAppleII { return AppleIITheme.backgroundColor }
        return RetroTheme.contentGray
    }
    var themeWindowBg: Color {
        if isC64 { return C64Theme.windowBackground }
        if isAppleII { return AppleIITheme.windowBackground }
        return RetroTheme.windowBackground
    }
    var themeBorderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        return RetroTheme.borderColor
    }
    var themeTextColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return RetroTheme.textColor
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 11) }
        if isAppleII { return AppleIITheme.font(size: 11) }
        return RetroTheme.font(size: 10)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 46)

                Text(machineName)
                    .font(isRetro ? themeFont : .system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isRetro ? themeTextColor : (isSelected ? .primary : .secondary))
                    .lineLimit(1)
            }
            .frame(width: 90)
            .padding(.vertical, 4)
            .background(
                Group {
                    if isRetro {
                        Rectangle().fill(isSelected ? themeWindowBg : Color.clear)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}
