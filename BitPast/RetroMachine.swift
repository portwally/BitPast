import Cocoa

// Ergebnis-Container (Bild + Dateien)
struct ConversionResult {
    let previewImage: NSImage
    let fileAssets: [URL]
}

// Typ der Option (Dropdown oder Slider)
enum OptionType {
    case picker
    case slider
}

// Eine einzelne Option
struct ConversionOption: Identifiable {
    let id = UUID()
    let label: String
    let key: String
    let type: OptionType
    
    // Für Picker
    let values: [String]
    
    // Für Slider
    let range: ClosedRange<Double>
    
    // Der Wert ist intern immer ein String, damit wir flexibel bleiben
    var selectedValue: String
    
    // INIT 1: Für DROPDOWN (Picker)
    init(label: String, key: String, values: [String], selectedValue: String) {
        self.label = label
        self.key = key
        self.type = .picker
        self.values = values
        self.range = 0...1 // Dummy range
        self.selectedValue = selectedValue
    }
    
    // INIT 2: Für SLIDER (Double) -> HIER WAR DER FEHLER (Int vs Double)
    init(label: String, key: String, range: ClosedRange<Double>, defaultValue: Double) {
        self.label = label
        self.key = key
        self.type = .slider
        self.values = []
        self.range = range
        // Wir speichern das Double direkt als String mit 2 Nachkommastellen
        self.selectedValue = String(format: "%.2f", defaultValue)
    }
}

protocol RetroMachine {
    var name: String { get }
    var options: [ConversionOption] { get set }
    func convert(sourceImage: NSImage) async throws -> ConversionResult
}

// Hilfserweiterungen für Bildbearbeitung (Skalierung)
extension NSImage {
    func fitToStandardSize(targetWidth: Int, targetHeight: Int) -> NSImage {
        let newSize = NSSize(width: targetWidth, height: targetHeight)
        let img = NSImage(size: newSize)
        
        img.lockFocus()
        // Hintergrund schwarz füllen
        NSColor.black.set()
        NSRect(origin: .zero, size: newSize).fill()
        
        // Aspekt-Ratio beibehalten
        let srcSize = self.size
        let ratioX = CGFloat(targetWidth) / srcSize.width
        let ratioY = CGFloat(targetHeight) / srcSize.height
        // Wir nehmen "Scale Aspect Fill" ähnliches Verhalten oder "Fit"
        // Für Retro Converter ist oft "Stretch" zu targetWidth (wegen Pixels) besser,
        // oder "Fit" mit schwarzen Balken. Hier machen wir "Stretch to Fill",
        // da Apple II Pixel oft nicht quadratisch sind.
        
        self.draw(in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
                  from: NSRect(origin: .zero, size: srcSize),
                  operation: .sourceOver,
                  fraction: 1.0)
        
        img.unlockFocus()
        return img
    }
}
