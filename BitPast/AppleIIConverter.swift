
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
            range: 0...50,
            defaultValue: 0
        ),
        
        // 7. COLOR BLEED (Slider)
        ConversionOption(
            label: "Color Bleed Reduction",
            key: "bleed",
            range: 0...99,
            defaultValue: 0
        )
    ]
    
    func convert(sourceImage: NSImage) async throws -> ConversionResult {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let inputFilename = "bp_\(uuid).bmp"
        let inputUrl = tempDir.appendingPathComponent(inputFilename)
        
        // --- CONFIG ---
        let mode = options.first(where: {$0.key == "mode"})?.selectedValue ?? ""
        let colorType = options.first(where: {$0.key == "colortype"})?.selectedValue ?? ""
        let resString = options.first(where: {$0.key == "resolution"})?.selectedValue ?? ""
        
        // --- SAFE RESOLUTION MAPPING ---
        var targetW = 280
        var targetH = 192
        if resString.contains("320") { targetW = 320; targetH = 200 }
        else if resString.contains("640") { targetW = 320; targetH = resString.contains("480") ? 240 : 200; targetH = 200 }
        else { targetW = 280; targetH = 192 }
        
        // --- SAVE BMP ---
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
        
        if let xStr = options.first(where: {$0.key == "crosshatch"})?.selectedValue, let xVal = Int(xStr), xVal > 0 {
            args.append("-X\(xVal)")
        }
        
        if let cStr = options.first(where: {$0.key == "bleed"})?.selectedValue, let cVal = Int(cStr), cVal > 0 {
            args.append("-C\(cVal)")
        }
        
        args.append("-V") // Preview
        
        let process = Process()
        process.executableURL = toolUrl
        process.arguments = args
        process.currentDirectoryURL = tempDir
        try process.run()
        process.waitUntilExit()
        
        // --- COLLECT RESULTS ---
        let baseName = inputFilename.replacingOccurrences(of: ".bmp", with: "")
        let allFiles = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.creationDateKey])
        
        let previewFile = allFiles.filter { $0.lastPathComponent.contains(baseName) && $0 != inputUrl && $0.pathExtension.lowercased() == "bmp" }
            .sorted { (try? fileManager.attributesOfItem(atPath: $0.path)[.creationDate] as? Date) ?? Date.distantPast > (try? fileManager.attributesOfItem(atPath: $1.path)[.creationDate] as? Date) ?? Date.distantPast }.first
        
        let assets = allFiles.filter { $0.lastPathComponent.contains(baseName) && $0.pathExtension.lowercased() != "bmp" }
        
        if let outputUrl = previewFile, let img = NSImage(contentsOf: outputUrl) {
            try? fileManager.removeItem(at: inputUrl)
            return ConversionResult(previewImage: img, fileAssets: assets)
        }
        
        throw NSError(domain: "BitPast", code: 500, userInfo: [NSLocalizedDescriptionKey: "Conversion failed. Try 280x192."])
    }
}
