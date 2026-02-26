import Cocoa

// RGB color for palette editing
struct PaletteRGB {
    var r: Double
    var g: Double
    var b: Double
}

// Ergebnis-Container (Bild + Dateien)
struct ConversionResult {
    let previewImage: NSImage
    let fileAssets: [URL]
    var palettes: [[PaletteRGB]]  // For Apple IIgs palette editing
    var pixelIndices: [Int]       // Pixel-to-palette-color indices
    var imageWidth: Int
    var imageHeight: Int

    init(previewImage: NSImage, fileAssets: [URL], palettes: [[PaletteRGB]] = [], pixelIndices: [Int] = [], imageWidth: Int = 0, imageHeight: Int = 0) {
        self.previewImage = previewImage
        self.fileAssets = fileAssets
        self.palettes = palettes
        self.pixelIndices = pixelIndices
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }
}

enum OptionType {
    case picker
    case slider
}

struct ConversionOption: Identifiable {
    let id = UUID()
    let label: String
    let key: String
    let type: OptionType
    
    // Für Picker
    let values: [String]
    
    // Für Slider
    let range: ClosedRange<Double>
    
    var selectedValue: String
    
    // INIT 1: Für DROPDOWN
    init(label: String, key: String, values: [String], selectedValue: String) {
        self.label = label
        self.key = key
        self.type = .picker
        self.values = values
        self.range = 0...1
        self.selectedValue = selectedValue
    }
    
    // INIT 2: Für SLIDER (mit Formatierungs-Fix)
    init(label: String, key: String, range: ClosedRange<Double>, defaultValue: Double) {
        self.label = label
        self.key = key
        self.type = .slider
        self.values = []
        self.range = range
        
        // FIX: Wenn der Wert glatt ist (z.B. 3.0), speichern wir "3" statt "3.00"
        let isInteger = floor(defaultValue) == defaultValue
        if isInteger {
            self.selectedValue = String(format: "%.0f", defaultValue)
        } else {
            self.selectedValue = String(format: "%.2f", defaultValue)
        }
    }
}

protocol RetroMachine {
    var name: String { get }
    var options: [ConversionOption] { get set }
    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]?) async throws -> ConversionResult
}

// MARK: - Input Validation

enum ConversionValidationError: LocalizedError {
    case emptyImage
    case invalidDimensions(width: Int, height: Int)

    var errorDescription: String? {
        switch self {
        case .emptyImage:
            return "Cannot convert: the source image is empty or has no pixel data."
        case .invalidDimensions(let w, let h):
            return "Cannot convert: invalid image dimensions (\(w)×\(h)). Width and height must be greater than zero."
        }
    }
}

// Extension to provide default parameter value and shared validation
extension RetroMachine {
    func convert(sourceImage: NSImage) async throws -> ConversionResult {
        try await convert(sourceImage: sourceImage, withSettings: nil)
    }

    /// Validates that a source image has valid, non-zero dimensions before conversion.
    func validateSourceImage(_ image: NSImage) throws {
        let w = Int(image.size.width)
        let h = Int(image.size.height)
        guard w > 0 && h > 0 else {
            if w == 0 && h == 0 {
                throw ConversionValidationError.emptyImage
            }
            throw ConversionValidationError.invalidDimensions(width: w, height: h)
        }
    }
}

// Hilfserweiterung für Scaling
extension NSImage {
    func fitToStandardSize(targetWidth: Int, targetHeight: Int) -> NSImage {
        let newSize = NSSize(width: targetWidth, height: targetHeight)
        let img = NSImage(size: newSize)
        
        img.lockFocus()
        NSColor.black.set()
        NSRect(origin: .zero, size: newSize).fill()
        
        let srcSize = self.size
        self.draw(in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
                  from: NSRect(origin: .zero, size: srcSize),
                  operation: .sourceOver,
                  fraction: 1.0)
        
        img.unlockFocus()
        return img
    }
}
