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
                "None",
                "Floyd-Steinberg",
                "Jarvis, Judice, Ninke",
                "Stucki",
                "Atkinson",
                "Burkes",
                "Sierra",
                "Sierra-2",
                "Sierra-Lite"
            ],
            selectedValue: "None"  // Changed default to None
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
            defaultValue: 0.0  // Changed default to 0
        ),
        
        // 7. THRESHOLD FOR CROSS-HATCH (Z)
        ConversionOption(
            label: "Cross-hatch Threshold",
            key: "z_threshold",
            range: 0.0...40.0,
            defaultValue: 0.0  // Changed default to 0
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
        var forceMonoMode = false  // Some resolutions require mono mode
        
        if mode.contains("DLGR") { targetW = 80; targetH = 48 }
        else if mode.contains("LGR") { targetW = 40; targetH = 48 }
        else {
            if resString.contains("640x480") { targetW = 640; targetH = 480 }
            else if resString.contains("640") { targetW = 640; targetH = 400 }
            else if resString.contains("560x384") { targetW = 560; targetH = 384 }
            else if resString.contains("560x192") { 
                targetW = 560; targetH = 192
                forceMonoMode = true  // 560x192 requires MONO mode
            }
            else if resString.contains("560") { targetW = 560; targetH = 192; forceMonoMode = true }
            else if resString.contains("320") { targetW = 320; targetH = 200 }
            else if resString.contains("140x192") { targetW = 140; targetH = 192 }
            else { targetW = 280; targetH = 192 }
        }
        
        // --- SAVE BMP ---
        let readyImage = sourceImage.fitToStandardSize(targetWidth: targetW, targetHeight: targetH)
        
        // Validate the resized image has the correct dimensions
        if readyImage.size.width != CGFloat(targetW) || readyImage.size.height != CGFloat(targetH) {
            print("⚠️ WARNING: Image resize failed. Expected \(targetW)x\(targetH), got \(Int(readyImage.size.width))x\(Int(readyImage.size.height))")
            // Continue anyway - b2d will reject it if it's really wrong
        }
        
        try readyImage.saveAsStrict24BitBMP(to: inputUrl)
        
        // Verify the BMP was written successfully
        if let attrs = try? fileManager.attributesOfItem(atPath: inputUrl.path),
           let fileSize = attrs[.size] as? Int64 {
            print("✅ BMP saved: \(inputUrl.lastPathComponent) (\(fileSize) bytes, \(targetW)x\(targetH))")
        } else {
            print("⚠️ WARNING: BMP file may not have been saved correctly")
        }
        
        // --- B2D ARGUMENTS ---
        // Die executable wird nicht mehr benötigt, da wir den C-Code direkt eingebunden haben!
        
        var args: [String] = [inputFilename]
        
        // Mode Flags
        // Special handling for specific resolutions
        if forceMonoMode {
            // 560x192 uses MONO mode only (not HGR)
            args.append("MONO")
        }
        else if mode.contains("DHGR") { 
            // DHGR mode (default - no flag needed for color)
            if colorType == "Monochrome" { 
                args.append("MONO") 
            }
        }
        else if mode.contains("HGR") { 
            // HGR mode ALWAYS needs the HGR flag
            args.append("HGR")
            
            if colorType == "Monochrome" { 
                args.append("MONO") 
            } 
        }
        else if mode.contains("DLGR") { args.append("DL") }
        else if mode.contains("LGR") { args.append("L") }
        
        // --- DITHER MAPPING (Internal ID) ---
        let ditherName = options.first(where: {$0.key == "dither"})?.selectedValue ?? ""
        switch ditherName {
        case "None":
            // Don't add any dither flag - let b2d use its default (which should be none after reset)
            break
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
        // Only add error matrix if dithering is enabled (not "None")
        if ditherName != "None" {
            if let eStr = options.first(where: {$0.key == "error_matrix"})?.selectedValue,
               let eVal = Double(eStr),
               eVal > 0 {
                args.append("-E\(Int(eVal))")
            }
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
        print("Args: b2d \(args.joined(separator: " "))")
        print("-------------------------------\n")
        
        // Wechsel ins Temp-Verzeichnis (b2d erwartet das)
        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(tempDir.path)
        
        // Baue argv-Array für C
        var cArgs: [UnsafeMutablePointer<CChar>?] = []
        cArgs.append(strdup("b2d")) // argv[0] = Programmname
        
        for arg in args {
            cArgs.append(strdup(arg))
        }
        cArgs.append(nil) // argv muss mit NULL enden
        
        // Rufe b2d direkt auf (keine executable mehr nötig!)
        let exitCode = b2d_main_wrapper(Int32(cArgs.count - 1), &cArgs)
        
        // Zurück ins Original-Verzeichnis
        fileManager.changeCurrentDirectoryPath(originalDir)
        
        // Cleanup
        for ptr in cArgs where ptr != nil {
            free(ptr)
        }
        
        guard exitCode == 0 else {
            // Clean up the failed input file
            try? fileManager.removeItem(at: inputUrl)
            
            let errorMsg: String
            if exitCode == 1 {
                errorMsg = "b2d rejected the BMP file (wrong format). The image may have invalid dimensions or unsupported format."
            } else {
                errorMsg = "b2d conversion failed with code \(exitCode)"
            }
            
            throw NSError(domain: "BitPast", code: Int(exitCode),
                         userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        // --- RESULTS ---
        let allFiles = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        
        // Debug: Print all files in temp directory
        print("📁 Files in temp directory:")
        for file in allFiles {
            let name = file.lastPathComponent
            if name.localizedCaseInsensitiveContains(baseNameRaw) {
                print("   ✅ \(name)")
            }
        }
        
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
        
        print("🖼️ Preview file: \(previewFile?.lastPathComponent ?? "NOT FOUND")")
        print("📦 Asset files: \(assets.map { $0.lastPathComponent })")
        
        if let outputUrl = previewFile, let img = NSImage(contentsOf: outputUrl) {
            try? fileManager.removeItem(at: inputUrl)
            return ConversionResult(previewImage: img, fileAssets: assets)
        }
        
        throw NSError(domain: "BitPast", code: 500, userInfo: [NSLocalizedDescriptionKey: "Conversion failed. No preview. Exit code: \(exitCode)"])
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
