import SwiftUI
import Combine

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case retroIIgs = "Retro (Apple IIgs)"
    case retroII = "Retro (Apple II)"
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            applyAppearance()
        }
    }

    var isRetroMode: Bool {
        appearanceMode == .retroIIgs || appearanceMode == .retroII
    }

    var isAppleIIgsMode: Bool {
        appearanceMode == .retroIIgs
    }

    var isAppleIIMode: Bool {
        appearanceMode == .retroII
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        self.appearanceMode = AppearanceMode(rawValue: saved) ?? .system
        applyAppearance()
    }

    func applyAppearance() {
        DispatchQueue.main.async {
            switch self.appearanceMode {
            case .system:
                NSApp.appearance = nil
            case .light, .retroIIgs:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark, .retroII:
                // Apple II green phosphor needs dark mode base
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }
}

// Retro theme colors and fonts - Apple IIgs GS/OS style
struct RetroTheme {
    // GS/OS Desktop colors
    static let backgroundColor = Color.white
    static let windowBackground = Color.white
    static let textColor = Color.black
    static let borderColor = Color.black

    // GS/OS window chrome colors (from screenshot)
    static let titleBarGray = Color(red: 0.73, green: 0.73, blue: 0.73)  // Light gray for title bar
    static let contentGray = Color(red: 0.73, green: 0.73, blue: 0.73)   // Gray for content area
    static let infoBarBackground = Color.white

    // Divider thickness (3px for retro mode)
    static let dividerThickness: CGFloat = 3

    // GS/OS title bar height
    static let titleBarHeight: CGFloat = 18
    static let infoBarHeight: CGFloat = 20

    // Shaston 640 font - the authentic Apple IIgs system font (640x200, 1-by-2 pixel aspect)
    // Use at 16pt (1x), 32pt (2x), or 48pt (3x) for pixel-perfect rendering
    static func font(size: CGFloat) -> Font {
        // Round to nearest supported size for crisp pixels
        let crispSize = roundToPixelPerfect(size)
        return .custom("Shaston640", size: crispSize)
    }

    static func boldFont(size: CGFloat) -> Font {
        // Shaston doesn't have bold variant, use regular
        let crispSize = roundToPixelPerfect(size)
        return .custom("Shaston640", size: crispSize)
    }

    // Round font size to nearest multiple of 16 for pixel-perfect rendering
    private static func roundToPixelPerfect(_ size: CGFloat) -> CGFloat {
        // Shaston looks best at 16pt or 32pt
        if size <= 12 {
            return 16  // Small text uses 16pt
        } else if size <= 20 {
            return 16  // Medium text uses 16pt
        } else {
            return 32  // Large text uses 32pt
        }
    }
}

// Apple II Green Phosphor theme - classic monitor look
struct AppleIITheme {
    // Classic green phosphor monitor colors
    static let backgroundColor = Color.black
    static let windowBackground = Color.black
    static let textColor = Color(red: 0.2, green: 1.0, blue: 0.2)  // Bright green #33FF33
    static let dimTextColor = Color(red: 0.1, green: 0.6, blue: 0.1)  // Dimmer green
    static let borderColor = Color(red: 0.2, green: 1.0, blue: 0.2)

    // Inverse video (for selections)
    static let inverseBackground = Color(red: 0.2, green: 1.0, blue: 0.2)
    static let inverseTextColor = Color.black

    // Divider thickness
    static let dividerThickness: CGFloat = 2

    // Print Char 21 font - authentic Apple II 40-column font
    // Falls back to Menlo (monospace) if font isn't installed
    static func font(size: CGFloat) -> Font {
        return .custom("Print Char 21", size: size)
    }

    static func boldFont(size: CGFloat) -> Font {
        // Apple II doesn't have bold, use regular
        return font(size: size)
    }

    // NSFont version for AppKit components
    static func nsFont(size: CGFloat) -> NSFont {
        if let font = NSFont(name: "Print Char 21", size: size) {
            return font
        }
        // Fallback to Menlo monospace
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}
