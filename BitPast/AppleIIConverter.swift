import Cocoa

class AppleIIConverter: RetroMachine {
    var name: String = "Apple II"
    
    var options: [ConversionOption] = [
        
        // 1. TARGET FORMAT
        ConversionOption(
            label: "Target Format",
            key: "mode",
            values: ["DHGR (Double Hi-Res)", "HGR (Hi-Res)", "LGR (Lo-Res)", "DLGR (Double Lo-Res)"],
            selectedValue: "DHGR (Double Hi-Res)"
        ),
        
        // 2. COLOR TYPE
        ConversionOption(
            label: "Color Type",
            key: "colortype",
            values: ["Color", "Monochrome"],
            selectedValue: "Color"
        ),
        
        // 3. OUTPUT RESOLUTION
        ConversionOption(
            label: "Output Resolution",
            key: "resolution",
            values: [
                "140x192 (DHGR Direct)",
                "280x192 (HGR Native)",
                "320x200 (C64/DOS)",
                "560x192 (DHGR Mono)",
                "560x384 (DHGR Best)",
                "640x400 (VGA)",
                "640x480 (VGA Square)"
            ],
            selectedValue: "560x384 (DHGR Best)"
        ),
        
        // 4. DITHER
        ConversionOption(
            label: "Dither",
            key: "dither",
            values: ["Floyd-Steinberg", "Atkinson", "Jarvis", "Stucki", "Sierra-Lite", "None"],
            selectedValue: "Floyd-Steinberg"
        ),
        
        // 5. PALETTE
        ConversionOption(
            label: "Palette",
            key: "palette",
            values: [
                "Standard (tohgr)",
                "Kegs RGB (P0)",
                "CiderPress (P1)",
                "AppleWin Old (P2)",
                "AppleWin NTSC (P3)",
                "Wikipedia (P4)",
                "Greyscale (P5 Mono)",
                "Virtu (P8)",
                "MicroM8 (P9)",
                "GS (P10)",
                "MAME (P11)",
                "Sa70 (P12)"
            ],
            selectedValue: "Standard (tohgr)"
        ),
        
        // 6. CROSSHATCH (Slider)
        ConversionOption(
            label: "Crosshatch Threshold",
            key: "crosshatch",
            range: 0.0...50.0,
            defaultValue: 0.0
        ),
        
        // 7. COLOR BLEED (Slider)
        ConversionOption(
            label: "Color Bleed Reduction",
            key: "bleed",
            range: 0.0...99.0,
            defaultValue: 0.0
        )
    ]
    
    func convert(sourceImage: NSImage) async throws -> ConversionResult {
            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory
            let uuid = UUID().uuidString.prefix(8)
            
            let baseNameRaw = "bp_\(uuid)"
            let inputFilename = "\(baseNameRaw).bmp"
            let inputUrl = tempDir.appendingPathComponent(inputFilename)
            
            // --- CONFIG ---
            let mode = options.first(where: {$0.key == "mode"})?.selectedValue ?? ""
            let colorType = options.first(where: {$0.key == "colortype"})?.selectedValue ?? ""
            let resString = options.first(where: {$0.key == "resolution"})?.selectedValue ?? ""
            
            // --- SAFE RESOLUTION MAPPING ---
            var targetW = 280
            var targetH = 192
            if resString.contains("320") { targetW = 320; targetH = 200 }
            else if resString.contains("640") { targetW = 320; targetH = 200 }
            else { targetW = 280; targetH = 192 }
            
            // --- SAVE BMP (Legacy Format) ---
            let readyImage = sourceImage.fitToStandardSize(targetWidth: targetW, targetHeight: targetH)
            try readyImage.saveAsStrict24BitBMP(to: inputUrl)
            
            // --- B2D ARGUMENTS ---
            guard let toolUrl = Bundle.main.url(forResource: "b2d", withExtension: nil) else {
                throw NSError(domain: "BitPast", code: 404, userInfo: [NSLocalizedDescriptionKey: "b2d missing"])
            }
            
            var args: [String] = [inputFilename]
            
            if mode.contains("DHGR") { if colorType == "Monochrome" { args.append("MONO") } }
            else if mode.contains("HGR") { args.append("HGR"); if colorType == "Monochrome" { args.append("MONO") } }
            else if mode.contains("DLGR") { args.append("DL") }
            else if mode.contains("LGR") { args.append("L") }
            
            let dither = options.first(where: {$0.key == "dither"})?.selectedValue
            if dither?.contains("Floyd") == true { args.append("-D1") }
            else if dither?.contains("Atkinson") == true { args.append("-D4") }
            else if dither?.contains("Jarvis") == true { args.append("-D2") }
            else if dither?.contains("Stucki") == true { args.append("-D3") }
            else if dither?.contains("Sierra") == true { args.append("-D8") }
            
            let palStr = options.first(where: {$0.key == "palette"})?.selectedValue ?? ""
            if let range = palStr.range(of: "P\\d+", options: .regularExpression) {
                let pTag = String(palStr[range])
                args.append("-\(pTag)")
            } else {
                args.append("-P5")
            }
            
            // Slider Parsing (String -> Double -> Int)
            if let xStr = options.first(where: {$0.key == "crosshatch"})?.selectedValue,
               let xDouble = Double(xStr),
               xDouble > 0 {
                args.append("-X\(Int(xDouble))")
            }
            
            if let cStr = options.first(where: {$0.key == "bleed"})?.selectedValue,
               let cDouble = Double(cStr),
               cDouble > 0 {
                args.append("-C\(Int(cDouble))")
            }
            
            args.append("-V") // Preview
            
            let process = Process()
            process.executableURL = toolUrl
            process.arguments = args
            process.currentDirectoryURL = tempDir
            try process.run()
            process.waitUntilExit()
            
            // --- COLLECT RESULTS ---
            let allFiles = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.creationDateKey])
            
            let previewFile = allFiles.first { file in
                let name = file.lastPathComponent
                return name.localizedCaseInsensitiveContains(baseNameRaw) &&
                       name != inputFilename &&
                       name.lowercased().hasSuffix(".bmp")
            }
            
            let assets = allFiles.filter { file in
                let name = file.lastPathComponent
                return name.localizedCaseInsensitiveContains(baseNameRaw) &&
                       file.pathExtension.lowercased() != "bmp"
            }
            
            if let outputUrl = previewFile, let img = NSImage(contentsOf: outputUrl) {
                try? fileManager.removeItem(at: inputUrl)
                return ConversionResult(previewImage: img, fileAssets: assets)
            }
            
            throw NSError(domain: "BitPast", code: 500, userInfo: [NSLocalizedDescriptionKey: "Conversion failed. No preview generated."])
        }
    }

// MARK: - Extensions für AppleIIConverter

extension NSImage {
    func saveAsStrict24BitBMP(to url: URL) throws {
        let width = Int(self.size.width)
        let height = Int(self.size.height)
        
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "BMPError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No CGImage"])
        }
        
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        )
        
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // BMP Setup
        let rowSize = ((width * 3) + 3) & ~3
        let pixelDataSize = rowSize * height
        let fileSize = 54 + pixelDataSize
        
        var bmpData = Data()
        bmpData.reserveCapacity(fileSize)
        
        // HEADER (FIX: "contentsOf:" Label hinzugefügt)
        bmpData.append(contentsOf: [0x42, 0x4D]) // "BM"
        bmpData.append(contentsOf: uInt32ToBytes(UInt32(fileSize)))
        bmpData.append(contentsOf: [0, 0, 0, 0])
        bmpData.append(contentsOf: uInt32ToBytes(54))
        
        // INFO HEADER
        bmpData.append(contentsOf: uInt32ToBytes(40))
        bmpData.append(contentsOf: uInt32ToBytes(UInt32(width)))
        bmpData.append(contentsOf: uInt32ToBytes(UInt32(height)))
        bmpData.append(contentsOf: [1, 0])
        bmpData.append(contentsOf: [24, 0])
        bmpData.append(contentsOf: [0, 0, 0, 0])
        bmpData.append(contentsOf: uInt32ToBytes(UInt32(pixelDataSize)))
        bmpData.append(contentsOf: [0, 0, 0, 0])
        bmpData.append(contentsOf: [0, 0, 0, 0])
        bmpData.append(contentsOf: [0, 0, 0, 0])
        bmpData.append(contentsOf: [0, 0, 0, 0])
        
        // PIXELS
        let paddingBytes = [UInt8](repeating: 0, count: rowSize - (width * 3))
        
        for y in (0..<height).reversed() {
            let rowStart = y * bytesPerRow
            for x in 0..<width {
                let pixelIdx = rowStart + (x * 4)
                let r = rawData[pixelIdx]
                let g = rawData[pixelIdx + 1]
                let b = rawData[pixelIdx + 2]
                
                bmpData.append(b)
                bmpData.append(g)
                bmpData.append(r)
            }
            if !paddingBytes.isEmpty {
                bmpData.append(contentsOf: paddingBytes)
            }
        }
        
        try bmpData.write(to: url)
    }
    
    private func uInt32ToBytes(_ val: UInt32) -> [UInt8] {
        var v = val
        return withUnsafeBytes(of: &v) { Array($0) }
    }
}
