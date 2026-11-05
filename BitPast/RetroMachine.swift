import Cocoa

// RGB color for palette editing
nonisolated struct PaletteRGB {
    var r: Double
    var g: Double
    var b: Double
}

// Ergebnis-Container (Bild + Dateien)
nonisolated struct ConversionResult {
    let previewImage: NSImage
    let fileAssets: [URL]
    var palettes: [[PaletteRGB]]  // For Apple IIgs palette editing
    var pixelIndices: [Int]       // Pixel-to-palette-color indices
    var imageWidth: Int
    var imageHeight: Int
    /// Which of `palettes` each line uses, when lines share a few palettes (IIgs 256 colours)
    var paletteLines: [Int]
    /// The palettes were changed in the palette editor after converting
    var editedPalettes: Bool
    /// How large the picture was drawn relative to the screen (Fit other than Stretch)
    var framedScale: CGSize? = nil

    init(previewImage: NSImage, fileAssets: [URL], palettes: [[PaletteRGB]] = [], pixelIndices: [Int] = [], imageWidth: Int = 0, imageHeight: Int = 0,
         paletteLines: [Int] = [], editedPalettes: Bool = false) {
        self.previewImage = previewImage
        self.fileAssets = fileAssets
        self.palettes = palettes
        self.pixelIndices = pixelIndices
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.paletteLines = paletteLines
        self.editedPalettes = editedPalettes
    }
}

nonisolated enum OptionType {
    case picker
    case slider
}

nonisolated struct ConversionOption: Identifiable {
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

nonisolated protocol RetroMachine {
    var name: String { get }
    var options: [ConversionOption] { get set }
    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]?) async throws -> ConversionResult
}

// MARK: - Input Validation

nonisolated enum ConversionValidationError: LocalizedError {
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
nonisolated extension RetroMachine {
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
nonisolated extension NSImage {
    /// A mirrored copy, pixel for pixel, keeping the size in points.
    func flipped(horizontal: Bool, vertical: Bool) -> NSImage {
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let ctx = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return self }
        ctx.translateBy(x: horizontal ? CGFloat(cg.width) : 0, y: vertical ? CGFloat(cg.height) : 0)
        ctx.scaleBy(x: horizontal ? -1 : 1, y: vertical ? -1 : 1)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard let mirrored = ctx.makeImage() else { return self }
        return NSImage(cgImage: mirrored, size: size)
    }

    /// Scales the picture to exactly `targetWidth`×`targetHeight` pixels on black, placed by
    /// `framing`. Draws into a fixed sRGB bitmap, so the result doesn't depend on the screens
    /// attached (`lockFocus` picked its pixel density and colours from them).
    func fitToStandardSize(targetWidth: Int, targetHeight: Int, framing: ImageFraming = .stretch) -> NSImage {
        let size = NSSize(width: targetWidth, height: targetHeight)
        guard let source = cgImage(forProposedRect: nil, context: nil, hints: nil),
              let ctx = CGContext(data: nil, width: targetWidth, height: targetHeight, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return NSImage(size: size)
        }
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.interpolationQuality = .high
        ctx.draw(source, in: framing.destination(sourceWidth: source.width, sourceHeight: source.height,
                                                 width: targetWidth, height: targetHeight))
        guard let scaled = ctx.makeImage() else { return NSImage(size: size) }
        return NSImage(cgImage: scaled, size: size)
    }
}
