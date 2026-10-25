import SwiftUI

struct ImageGridItem: View {
    let item: InputImage
    let isSelected: Bool
    var isMultiSelected: Bool = false
    var isLocked: Bool = false  // Per-image settings locked
    var isRetro: Bool = false
    var isAppleII: Bool = false
    var onToggleSelection: (() -> Void)? = nil

    // Theme-aware colors
    var themeBgColor: Color { isAppleII ? AppleIITheme.windowBackground : RetroTheme.windowBackground }
    var themeBorderColor: Color { isAppleII ? AppleIITheme.borderColor : RetroTheme.borderColor }
    var themeTextColor: Color { isAppleII ? AppleIITheme.textColor : RetroTheme.textColor }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if isRetro {
                    Rectangle()
                        .fill(themeBgColor)
                        .border(themeBorderColor, width: 1)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }

                Image(nsImage: item.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 70)
                    .padding(4)

                // Selection circle overlay (top-right corner) and lock indicator (top-left)
                VStack {
                    HStack {
                        // Lock indicator (top-left)
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                        .frame(width: 18, height: 18)
                                )
                                .padding(2)
                        }
                        Spacer()
                        Button(action: { onToggleSelection?() }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 20, height: 20)
                                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                if isMultiSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.accentColor)
                                } else {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
                                        .frame(width: 16, height: 16)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                    }
                    Spacer()
                }
            }
            .frame(height: 80)
            .overlay(
                Group {
                    if isRetro {
                        Rectangle()
                            .stroke(isSelected || isMultiSelected ? themeBorderColor : Color.clear, lineWidth: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : (isMultiSelected ? Color.accentColor.opacity(0.7) : Color.clear), lineWidth: 2.5)
                    }
                }
            )

            Text(item.name)
                .font(isRetro ? (isAppleII ? AppleIITheme.font(size: 10) : RetroTheme.font(size: 10)) : .caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(isRetro ? themeTextColor : (isSelected || isMultiSelected ? .primary : .secondary))
        }
        .padding(6)
        .background(isSelected ? (isRetro ? themeBgColor : Color.accentColor.opacity(0.12)) : (isMultiSelected ? Color.accentColor.opacity(0.08) : Color.clear))
        .cornerRadius(isRetro ? 0 : 10)
    }
}
