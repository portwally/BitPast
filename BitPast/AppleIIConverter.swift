import Cocoa

class AppleIIConverter: RetroMachine {
    var name: String = "Apple II"
    
    var options: [ConversionOption] = [
        
        // 1. TARGET FORMAT
        ConversionOption(
            label: "Target Format",
            key: "mode",
            values: ["DHGR (Double Hi-Res)", "HGR (Hi-Res)", "LGR (Lo-Res)", "DLGR (Double Lo-Res)", "Mono"],
            selectedValue: "DHGR (Double Hi-Res)"
        ),
        
        // 2. OUTPUT RESOLUTION
        ConversionOption(
            label: "Output Resolution",
            key: "resolution",
            values: [
                "140x192 (DHGR Direct)",
                "280x192 (HGR Native)",
                "320x200 (C64/DOS)",
                "560x384 (DHGR Best)",
                "640x400 (VGA)",
                "640x480 (VGA Square)"
            ],
            selectedValue: "560x384 (DHGR Best)"
        ),
        
        // 3. DITHER (matching b2d.c dithertext[] - IDs 1-9)
        ConversionOption(
            label: "Dither Algo",
            key: "dither",
            values: [
                "None",              // No dither flag
                "Floyd-Steinberg",   // -D1
                "Jarvis",            // -D2
                "Stucki",            // -D3
                "Atkinson",          // -D4
                "Burkes",            // -D5
                "Sierra",            // -D6
                "Sierra Two",        // -D7
                "Sierra Lite",       // -D8
                "Buckels"            // -D9
            ],
            selectedValue: "None"
        ),

        // 4. PALETTE (matching b2d.c palname[] - IDs 0-16)
        ConversionOption(
            label: "Palette",
            key: "palette",
            values: [
                "Kegs32 RGB",              // -P0  (Apple IIgs)
                "CiderPress RGB",          // -P1
                "AppleWin Old NTSC",       // -P2
                "AppleWin New NTSC",       // -P3
                "Wikipedia NTSC",          // -P4
                "tohgr NTSC (Default)",    // -P5  (Default for DHGR)
                "Super Convert RGB",       // -P12
                "Jace NTSC",               // -P13
                "Cybernesto NTSC",         // -P14
                "tohgr NTSC HGR"           // -P16 (For HGR mode)
            ],
            selectedValue: "Kegs32 RGB"
        ),
        
        // 5. CROSS-HATCH PATTERN (X)
        ConversionOption(
            label: "Cross-hatch Pattern",
            key: "crosshatch",
            range: 0.0...10.0,
            defaultValue: 0.0  // Changed default to 0
        ),
        
        // 6. THRESHOLD FOR CROSS-HATCH (Z)
        ConversionOption(
            label: "Cross-hatch Threshold",
            key: "z_threshold",
            range: 0.0...40.0,
            defaultValue: 0.0  // Changed default to 0
        ),
        
        // 7. ERROR-DIFFUSION MATRIX (E)
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
        let resString = options.first(where: {$0.key == "resolution"})?.selectedValue ?? ""
        
        // --- SAFE RESOLUTION MAPPING ---
        var targetW = 280
        var targetH = 192
        
        // Handle Mono mode - only allows 280x192 (HGR Native) or 560x384 (DHGR Best)
        if mode == "Mono" {
            if resString.contains("280x192") {
                // HGR Monochrome: 280x192
                targetW = 280
                targetH = 192
            } else {
                // DHGR Monochrome: 560x384 Color BMP for dithered output
                targetW = 560
                targetH = 384
            }
        }
        else if mode.contains("DLGR") { targetW = 80; targetH = 48 }
        else if mode.contains("LGR") && !mode.contains("DLGR") { targetW = 40; targetH = 48 }
        else if mode.contains("HGR") && !mode.contains("DHGR") {
            // HGR mode requires minimum 560px width for b2d to process correctly
            // b2d needs double-width input to simulate NTSC color artifacts properly
            if resString.contains("640x480") { targetW = 640; targetH = 480 }
            else if resString.contains("640") { targetW = 640; targetH = 400 }
            else if resString.contains("560x384") { targetW = 560; targetH = 384 }
            else if resString.contains("560x192") { targetW = 560; targetH = 192 }
            else if resString.contains("560") { targetW = 560; targetH = 192 }
            else if resString.contains("320") { targetW = 640; targetH = 400 } // Upscale for HGR
            else if resString.contains("280x192") { targetW = 560; targetH = 384 } // Upscale for HGR
            else if resString.contains("140x192") { targetW = 560; targetH = 384 } // Upscale for HGR
            else { targetW = 560; targetH = 384 }  // Default for HGR
        }
        else {
            // DHGR, LGR, DLGR modes
            if resString.contains("640x480") { targetW = 640; targetH = 480 }
            else if resString.contains("640") { targetW = 640; targetH = 400 }
            else if resString.contains("560x384") { targetW = 560; targetH = 384 }
            else if resString.contains("320") { targetW = 320; targetH = 200 }
            else if resString.contains("280x192") {
                // For DHGR, upscale 280x192 to avoid format issues
                targetW = 560
                targetH = 384
            }
            else if resString.contains("140x192") { targetW = 140; targetH = 192 }
            else { targetW = 280; targetH = 192 }
        }
        
        // --- SAVE BMP ---
        let readyImage = sourceImage.fitToStandardSize(targetWidth: targetW, targetHeight: targetH)
        try readyImage.saveAsStrict24BitBMP(to: inputUrl)
        
        // --- B2D ARGUMENTS ---
        var args: [String] = [inputFilename]
        
        // Mode Flags - clear and explicit logic
        if mode == "Mono" {
            // Mono mode uses only MONO flag (HGR and MONO are mutually exclusive!)
            args.append("MONO")
        }
        else if mode.contains("HGR") && !mode.contains("DHGR") {
            // HGR mode needs the HGR flag for color output (but not DHGR!)
            args.append("HGR")
        }
        else if mode.contains("DLGR") {
            args.append("DL")
        }
        else if mode.contains("LGR") && !mode.contains("DLGR") {
            args.append("L")
        }
        // DHGR mode (default) - no flags needed for color DHGR
        
        // --- DITHER MAPPING (matching b2d.c defines) ---
        let ditherName = options.first(where: {$0.key == "dither"})?.selectedValue ?? ""
        switch ditherName {
        case "None":           break  // No dither flag
        case "Floyd-Steinberg": args.append("-D1")
        case "Jarvis":          args.append("-D2")
        case "Stucki":          args.append("-D3")
        case "Atkinson":        args.append("-D4")
        case "Burkes":          args.append("-D5")
        case "Sierra":          args.append("-D6")
        case "Sierra Two":      args.append("-D7")
        case "Sierra Lite":     args.append("-D8")
        case "Buckels":         args.append("-D9")
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

        // --- PALETTE MAPPING (matching b2d.c palname[] indices) ---
        let palName = options.first(where: {$0.key == "palette"})?.selectedValue ?? ""

        // For Mono mode, DO NOT set any palette - palette flags can trigger HGR internally!
        if mode != "Mono" {
            switch palName {
            case "Kegs32 RGB":           args.append("-P0")
            case "CiderPress RGB":       args.append("-P1")
            case "AppleWin Old NTSC":    args.append("-P2")
            case "AppleWin New NTSC":    args.append("-P3")
            case "Wikipedia NTSC":       args.append("-P4")
            case "tohgr NTSC (Default)": args.append("-P5")
            case "Super Convert RGB":    args.append("-P12")
            case "Jace NTSC":            args.append("-P13")
            case "Cybernesto NTSC":      args.append("-P14")
            case "tohgr NTSC HGR":       args.append("-P16")
            default:                     args.append("-P5")  // Fallback to tohgr
            }
        }
        
        // --- SLIDERS (X, Z) ---
        if let valStr = options.first(where: {$0.key == "crosshatch"})?.selectedValue, let val = Double(valStr), val > 0 {
            args.append("-X\(Int(val))")
        }
        if let valStr = options.first(where: {$0.key == "z_threshold"})?.selectedValue, let val = Double(valStr), val > 0 {
            args.append("-Z\(Int(val))")
        }
        
        args.append("-V") // Preview

        // Switch to temp directory (b2d expects this)
        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(tempDir.path)
        
        // Build argv array for C
        var cArgs: [UnsafeMutablePointer<CChar>?] = []
        cArgs.append(strdup("b2d")) // argv[0] = program name

        for arg in args {
            cArgs.append(strdup(arg))
        }
        cArgs.append(nil) // argv must end with NULL

        // Call b2d conversion
        let exitCode = b2d_main_wrapper(Int32(cArgs.count - 1), &cArgs)

        // Return to original directory
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
        
        // Find output files
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
