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
    
    // Der Wert ist immer ein String
    var selectedValue: String
    
    // Init für Dropdown
    init(label: String, key: String, values: [String], selectedValue: String) {
        self.label = label
        self.key = key
        self.type = .picker
        self.values = values
        self.range = 0...1
        self.selectedValue = selectedValue
    }
    
    // Init für Slider
    init(label: String, key: String, range: ClosedRange<Double>, defaultValue: Int) {
        self.label = label
        self.key = key
        self.type = .slider
        self.values = []
        self.range = range
        self.selectedValue = String(defaultValue)
    }
}

protocol RetroMachine {
    var name: String { get }
    var options: [ConversionOption] { get set }
    func convert(sourceImage: NSImage) async throws -> ConversionResult
}

// Hilfserweiterungen für Bildbearbeitung
extension NSImage {
    func fitToStandardSize(targetWidth: Int, targetHeight: Int) -> NSImage {
        let targetSize = NSSize(width: targetWidth, height: targetHeight)
        let newImage = NSImage(size: targetSize)
        
        newImage.lockFocus()
        NSColor.black.set()
        NSRect(origin: .zero, size: targetSize).fill()
        
        let srcSize = self.size
        let ratio = min(CGFloat(targetWidth)/srcSize.width, CGFloat(targetHeight)/srcSize.height)
        let scaledSize = NSSize(width: srcSize.width * ratio, height: srcSize.height * ratio)
        let x = (CGFloat(targetWidth) - scaledSize.width) / 2
        let y = (CGFloat(targetHeight) - scaledSize.height) / 2
        
        self.draw(in: NSRect(x: x, y: y, width: scaledSize.width, height: scaledSize.height),
                  from: .zero,
                  operation: .sourceOver,
                  fraction: 1.0)
        
        newImage.unlockFocus()
        return newImage
    }

    func saveAsStrict24BitBMP(to url: URL) throws {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "BMPError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No CGImage"])
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bytesPerRow = width * 4
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        guard let context = CGContext(data: &rawData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            throw NSError(domain: "BMPError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Context failed"])
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let padding = (4 - (width * 3) % 4) % 4
        let rowSize = (width * 3) + padding
        let fileSize = 54 + (rowSize * height)
        
        var bmpBytes = [UInt8]()
        bmpBytes.reserveCapacity(fileSize)
        
        func append16(_ val: UInt16) { bmpBytes.append(contentsOf: withUnsafeBytes(of: val.littleEndian) { Array($0) }) }
        func append32(_ val: UInt32) { bmpBytes.append(contentsOf: withUnsafeBytes(of: val.littleEndian) { Array($0) }) }
        
        bmpBytes.append(0x42); bmpBytes.append(0x4D)
        append32(UInt32(fileSize)); append16(0); append16(0); append32(54)
        append32(40); append32(UInt32(width)); append32(UInt32(height)); append16(1); append16(24); append32(0); append32(0); append32(0); append32(0); append32(0); append32(0)
        
        for y in 0..<height {
            let srcY = height - 1 - y
            let srcRowStart = srcY * bytesPerRow
            for x in 0..<width {
                let ptr = srcRowStart + (x * 4)
                bmpBytes.append(rawData[ptr+2])
                bmpBytes.append(rawData[ptr+1])
                bmpBytes.append(rawData[ptr])
            }
            for _ in 0..<padding { bmpBytes.append(0) }
        }
        
        try Data(bmpBytes).write(to: url)
    }
}
