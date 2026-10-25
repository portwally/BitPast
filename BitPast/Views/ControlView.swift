import SwiftUI

struct ControlView: View {
    let opt: ConversionOption
    let index: Int
    @ObservedObject var viewModel: ConverterViewModel
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var isC64: Bool = false

    // Theme-aware colors
    var themeTextColor: Color {
        if isC64 { return C64Theme.textColor }
        if isAppleII { return AppleIITheme.textColor }
        return isRetro ? RetroTheme.textColor : .secondary
    }
    var themeBgColor: Color {
        if isC64 { return C64Theme.windowBackground }
        if isAppleII { return AppleIITheme.windowBackground }
        return isRetro ? RetroTheme.windowBackground : Color(NSColor.controlBackgroundColor).opacity(0.5)
    }
    var themeBorderColor: Color {
        if isC64 { return C64Theme.borderColor }
        if isAppleII { return AppleIITheme.borderColor }
        return RetroTheme.borderColor
    }
    var themeFont: Font {
        if isC64 { return C64Theme.font(size: 12) }
        if isAppleII { return AppleIITheme.font(size: 12) }
        return isRetro ? RetroTheme.font(size: 11) : .system(size: 11, weight: .semibold)
    }
    var themeValueFont: Font {
        if isC64 { return C64Theme.font(size: 14) }
        if isAppleII { return AppleIITheme.font(size: 14) }
        return isRetro ? RetroTheme.font(size: 13) : .system(size: 13, weight: .medium)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(opt.label.uppercased())
                .font(themeFont)
                .foregroundColor(themeTextColor)
                .tracking(0.3)
            
            if opt.type == .slider {
                VStack(spacing: 6) {
                    Slider(
                        value: Binding(
                            get: {
                                let currentOptions = viewModel.machines[viewModel.selectedMachineIndex].options
                                if index < currentOptions.count {
                                    return Double(currentOptions[index].selectedValue) ?? 0.0
                                }
                                return 0.0
                            },
                            set: { val in
                                if index < viewModel.machines[viewModel.selectedMachineIndex].options.count {
                                    let isFloat = ["gamma", "saturation", "dither_amount", "sharpen_strength", "emboss_depth"].contains(opt.key)
                                    viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = isFloat ? String(format: "%.2f", val) : String(format: "%.0f", val)
                                    viewModel.triggerLivePreview()
                                }
                            }
                        ),
                        in: opt.range
                    )
                    .frame(width: 100)
                    .tint(.accentColor)

                    Text(safeValueDisplay)
                        .monospacedDigit()
                        .font(themeValueFont)
                        .foregroundColor(themeTextColor)
                        .frame(minWidth: 40)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(themeBgColor)
                        .cornerRadius((isRetro || isAppleII || isC64) ? 0 : 4)
                        .overlay((isRetro || isAppleII || isC64) ? Rectangle().stroke(themeBorderColor, lineWidth: 1) : nil)
                }
            } else if opt.type == .picker {
                if isC64 {
                    // C64-style popup picker with PetMe64 font
                    C64PopupPicker(
                        values: filteredValues,
                        selectedValue: Binding(
                            get: {
                                let currentOptions = viewModel.machines[viewModel.selectedMachineIndex].options
                                if index < currentOptions.count {
                                    return currentOptions[index].selectedValue
                                }
                                return ""
                            },
                            set: { val in
                                if index < viewModel.machines[viewModel.selectedMachineIndex].options.count {
                                    viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = val
                                }
                            }
                        ),
                        onChange: {
                            viewModel.triggerLivePreview()
                        }
                    )
                } else if isAppleII {
                    // Apple II-style popup picker with green phosphor look
                    AppleIIPopupPicker(
                        values: filteredValues,
                        selectedValue: Binding(
                            get: {
                                let currentOptions = viewModel.machines[viewModel.selectedMachineIndex].options
                                if index < currentOptions.count {
                                    return currentOptions[index].selectedValue
                                }
                                return ""
                            },
                            set: { val in
                                if index < viewModel.machines[viewModel.selectedMachineIndex].options.count {
                                    viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = val
                                }
                            }
                        ),
                        onChange: {
                            viewModel.triggerLivePreview()
                        }
                    )
                } else if isRetro {
                    // GS/OS-style popup picker with Shaston font
                    GSOSPopupPicker(
                        values: filteredValues,
                        selectedValue: Binding(
                            get: {
                                let currentOptions = viewModel.machines[viewModel.selectedMachineIndex].options
                                if index < currentOptions.count {
                                    return currentOptions[index].selectedValue
                                }
                                return ""
                            },
                            set: { val in
                                if index < viewModel.machines[viewModel.selectedMachineIndex].options.count {
                                    viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = val
                                }
                            }
                        ),
                        onChange: {
                            viewModel.triggerLivePreview()
                        }
                    )
                } else {
                    Picker("", selection: Binding(
                        get: {
                            let currentOptions = viewModel.machines[viewModel.selectedMachineIndex].options
                            if index < currentOptions.count {
                                return currentOptions[index].selectedValue
                            }
                            return ""
                        },
                        set: { val in
                            if index < viewModel.machines[viewModel.selectedMachineIndex].options.count {
                                viewModel.machines[viewModel.selectedMachineIndex].options[index].selectedValue = val
                                viewModel.triggerLivePreview()
                            }
                        }
                    )) {
                        ForEach(filteredValues, id: \.self) { val in
                            Text(val).tag(val)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minWidth: 110)
                    .controlSize(.regular)
                }
            }
        }
        .id("\(opt.id)_\(isAppleII)_\(isC64)_\(isRetro)")  // Force rebuild when theme changes
    }

    // Filter resolution values when Mono mode is selected
    var filteredValues: [String] {
        // Only filter for resolution picker
        guard opt.key == "resolution" else {
            return opt.values
        }
        
        // Check if current mode is "Mono"
        let currentOptions = viewModel.machines[viewModel.selectedMachineIndex].options
        if let modeOption = currentOptions.first(where: { $0.key == "mode" }),
           modeOption.selectedValue == "Mono" {
            // Only allow these two resolutions for Mono mode
            return opt.values.filter { value in
                value.contains("280x192") || value.contains("560x384")
            }
        }
        
        return opt.values
    }
    
    var safeValueDisplay: String {
        let currentOptions = viewModel.machines[viewModel.selectedMachineIndex].options
        if index < currentOptions.count {
            return currentOptions[index].selectedValue
        }
        return "-"
    }
}
