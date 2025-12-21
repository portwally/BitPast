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
        
        // 4. DITHER (Clean Names)
        ConversionOption(
            label: "Dither Algo",
            key: "dither",
            values: [
                "Floyd-Steinberg",
                "Jarvis, Judice, Ninke",
                "Stucki",
                "Atkinson",
                "Burkes",
                "Sierra",
                "Sierra-2",
                "Sierra-Lite",
                "None"
            ],
            selectedValue: "Floyd-Steinberg"
        ),
        
        // 5. PALETTE (Clean Names)
        ConversionOption(
            label: "Palette",
            key: "palette",
            values: [
                "Apple IIgs RGB",
                "Wikipedia NTSC",
                "VBMP NTSC",
                "RGB Palette",
                "Palette Clipping",
                "-----------------",
                "Standard (tohgr)",
                "CiderPress",
                "AppleWin Old",
                "Greyscale",
                "Virtu",
                "MAME"
            ],
            selectedValue: "Apple IIgs RGB"
        ),
        
        // 6. CROSS-HATCH PATTERN (X)
        ConversionOption(
            label: "Cross-hatch Pattern",
            key: "crosshatch",
            range: 0.0...10.0,
            defaultValue: 3.0
        ),
        
        // 7. THRESHOLD FOR CROSS-HATCH (Z)
        ConversionOption(
            label: "Cross-hatch Threshold",
            key: "z_threshold",
            range: 0.0...40.0,
            defaultValue: 20.0
        ),
        
        // 8. ERROR-DIFFUSION MATRIX (E)
        ConversionOption(
            label: "Error Matrix Index",
            key: "error_matrix",
            range: 0.0...10.0,
            defaultValue: 1.0
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
        
        if mode.contains("DLGR") { targetW = 80; targetH = 48 }
        else if mode.contains("LGR") { targetW = 40; targetH = 48 }
        else {
            if resString.contains("640x480") { targetW = 640; targetH = 480 }
            else if resString.contains("640") { targetW = 640; targetH = 400 }
            else if resString.contains("560x384") { targetW = 560; targetH = 384 }
            else if resString.contains("560") { targetW = 560; targetH = 192 }
            else if resString.contains("320") { targetW = 320; targetH = 200 }
            else { targetW = 280; targetH = 192 }
        }
        
        // --- SAVE BMP ---
        let readyImage = sourceImage.fitToStandardSize(targetWidth: targetW, targetHeight: targetH)
        try readyImage.saveAsStrict24BitBMP(to: inputUrl)
        
        // --- B2D ARGUMENTS ---
        guard let toolUrl = Bundle.main.url(forResource: "b2d", withExtension: nil) else {
            throw NSError(domain: "BitPast", code: 404, userInfo: [NSLocalizedDescriptionKey: "b2d missing"])
        }
        
        var args: [String] = [inputFilename]
        
        // Mode Flags
        if mode.contains("DHGR") { if colorType == "Monochrome" { args.append("MONO") } }
        else if mode.contains("HGR") { args.append("HGR"); if colorType == "Monochrome" { args.append("MONO") } }
        else if mode.contains("DLGR") { args.append("DL") }
        else if mode.contains("LGR") { args.append("L") }
        
        // --- DITHER MAPPING (Internal ID) ---
        let ditherName = options.first(where: {$0.key == "dither"})?.selectedValue ?? ""
        switch ditherName {
        case "Floyd-Steinberg":       args.append("-D1")
        case "Jarvis, Judice, Ninke": args.append("-D2")
        case "Stucki":                args.append("-D3")
        case "Atkinson":              args.append("-D4")
        case "Burkes":                args.append("-D5")
        case "Sierra":                args.append("-D6")
        case "Sierra-2":              args.append("-D7")
        case "Sierra-Lite":           args.append("-D8")
        default: break
        }
        
        // --- ERROR MATRIX (E) ---
        if let eStr = options.first(where: {$0.key == "error_matrix"})?.selectedValue,
           let eVal = Double(eStr),
           eVal > 0 {
            args.append("-E\(Int(eVal))")
        }
        
        // --- PALETTE MAPPING (Internal ID) ---
        let palName = options.first(where: {$0.key == "palette"})?.selectedValue ?? ""
        if palName.contains("Apple IIgs RGB") { args.append("-P0") }
        else if palName.contains("CiderPress") { args.append("-P1") }
        else if palName.contains("AppleWin Old") { args.append("-P2") }
        else if palName.contains("VBMP NTSC") { args.append("-P3") }
        else if palName.contains("Wikipedia NTSC") { args.append("-P4") }
        else if palName.contains("Greyscale") { args.append("-P5") }
        else if palName.contains("Standard (tohgr)") { args.append("-P5") }
        else if palName.contains("Virtu") { args.append("-P8") }
        else if palName.contains("RGB Palette") { args.append("-P9") }
        else if palName.contains("MAME") { args.append("-P11") }
        else if palName.contains("Clipping") { args.append("-P13") }
        else { args.append("-P5") } // Fallback
        
        // --- SLIDERS (X, Z) ---
        if let valStr = options.first(where: {$0.key == "crosshatch"})?.selectedValue, let val = Double(valStr), val > 0 {
            args.append("-X\(Int(val))")
        }
        if let valStr = options.first(where: {$0.key == "z_threshold"})?.selectedValue, let val = Double(valStr), val > 0 {
            args.append("-Z\(Int(val))")
        }
        
        args.append("-V") // Preview
        
        // --- DEBUG PRINT ---
        print("\n---------- B2D DEBUG ----------")
        print("Cmd: \"\(toolUrl.path)\" \(args.joined(separator: " "))")
        print("-------------------------------\n")
        
        let process = Process()
        process.executableURL = toolUrl
        process.arguments = args
        process.currentDirectoryURL = tempDir
        try process.run()
        process.waitUntilExit()
        
        // --- RESULTS ---
        let allFiles = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        
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
        
        throw NSError(domain: "BitPast", code: 500, userInfo: [NSLocalizedDescriptionKey: "Conversion failed. No preview."])
    }
}

extension NSImage {
    func saveAsStrict24BitBMP(to url: URL) throws {
        let width = Int(self.size.width)
        let height = Int(self.size.height)
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "BMPError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No CGImage"])
        }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bytesPerRow = width * 4
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        let context = CGContext(data: &rawData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let rowSize = ((width * 3) + 3) & ~3
        let fileSize = 54 + (rowSize * height)
        var bmpData = Data(); bmpData.reserveCapacity(fileSize)
        
        bmpData.append(contentsOf: [0x42, 0x4D])
        bmpData.append(contentsOf: uInt32ToBytes(UInt32(fileSize)))
        bmpData.append(contentsOf: [0, 0, 0, 0])
        bmpData.append(contentsOf: uInt32ToBytes(54))
        bmpData.append(contentsOf: uInt32ToBytes(40))
        bmpData.append(contentsOf: uInt32ToBytes(UInt32(width)))
        bmpData.append(contentsOf: uInt32ToBytes(UInt32(height)))
        bmpData.append(contentsOf: [1, 0, 24, 0, 0, 0, 0, 0])
        bmpData.append(contentsOf: uInt32ToBytes(UInt32(rowSize * height)))
        bmpData.append(contentsOf: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])
        
        let paddingBytes = [UInt8](repeating: 0, count: rowSize - (width * 3))
        for y in (0..<height).reversed() {
            let rowStart = y * bytesPerRow
            for x in 0..<width {
                let i = rowStart + (x * 4)
                bmpData.append(contentsOf: [rawData[i+2], rawData[i+1], rawData[i]])
            }
            bmpData.append(contentsOf: paddingBytes)
        }
        try bmpData.write(to: url)
    }
    private func uInt32ToBytes(_ val: UInt32) -> [UInt8] { var v = val; return withUnsafeBytes(of: &v) { Array($0) } }
}
