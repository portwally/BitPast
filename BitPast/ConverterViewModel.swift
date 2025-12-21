import SwiftUI
import Combine
import UniformTypeIdentifiers

// GLOBAL STRUKTUR
struct InputImage: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let image: NSImage
    let details: String
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: InputImage, rhs: InputImage) -> Bool { lhs.id == rhs.id }
}

@MainActor
class ConverterViewModel: ObservableObject {
    @Published var machines: [RetroMachine] = [AppleIIConverter(),AppleIIGSConverter()]
    @Published var selectedMachineIndex: Int = 0
    
    @Published var inputImages: [InputImage] = []
    @Published var selectedImageId: UUID?
    
    @Published var currentResult: ConversionResult?
    @Published var isConverting: Bool = false
    @Published var errorMessage: String?
    
    
    // ProDOS Optionen
    enum DiskFormat: String, CaseIterable, Identifiable {
        case po = "po", hdv = "hdv", twoMG = "2mg"
        var id: String { self.rawValue }
    }
    
    enum DiskSize: String, CaseIterable, Identifiable {
            case kb140 = "140 KB (5.25\")"
            case kb800 = "800 KB (3.5\")"
            case mb32 = "32 MB (Hard Disk)"
            
            var id: String { self.rawValue }
            
            var cadiusSize: String {
                switch self {
                case .kb140: return "143KB" // <--- FIX: 143KB statt 140KB
                case .kb800: return "800KB"
                case .mb32: return "32MB"
                }
            }
        }
    
    private var previewTask: Task<Void, Never>?
    
    var convertedImage: NSImage? { currentResult?.previewImage }
    var currentOriginalImage: NSImage? {
        guard let id = selectedImageId, let item = inputImages.first(where: { $0.id == id }) else { return nil }
        return item.image
    }
    var currentMachine: RetroMachine {
        get { machines[selectedMachineIndex] }
        set { machines[selectedMachineIndex] = newValue }
    }
    
    // MARK: - File Loading
    
    func selectImagesFromFinder() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]; panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { for url in panel.urls { loadImage(from: url) } }
    }
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        var found = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, _) in
                    if let urlData = data as? Data, let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                        DispatchQueue.main.async { self.loadImage(from: url) }
                    } else if let url = data as? URL {
                        DispatchQueue.main.async { self.loadImage(from: url) }
                    }
                }
                found = true
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let img = image as? NSImage {
                        DispatchQueue.main.async {
                            let info = "PASTE • \(Int(img.size.width))x\(Int(img.size.height))"
                            let newItem = InputImage(name: "Dropped Image", image: img, details: info)
                            self.inputImages.append(newItem)
                            if self.inputImages.count == 1 { self.selectedImageId = newItem.id; self.convertImmediately() }
                        }
                    }
                }
                found = true
            }
        }
        return found
    }
    
    private func loadImage(from url: URL) {
        if let img = NSImage(contentsOf: url) {
            let name = url.lastPathComponent
            let ext = url.pathExtension.uppercased()
            let info = "\(ext.isEmpty ? "?" : ext) • \(Int(img.size.width))x\(Int(img.size.height))"
            let newItem = InputImage(name: name, image: img, details: info)
            self.inputImages.append(newItem)
            if selectedImageId == nil {
                selectedImageId = newItem.id
                convertImmediately()
            }
        }
    }
    
    func removeSelectedImage() {
        guard let id = selectedImageId else { return }
        if let idx = inputImages.firstIndex(where: { $0.id == id }) {
            inputImages.remove(at: idx)
            if !inputImages.isEmpty {
                selectedImageId = inputImages[min(idx, inputImages.count-1)].id
                convertImmediately()
            } else {
                selectedImageId = nil
                currentResult = nil
            }
        }
    }
    
    // MARK: - Conversion
    
    func triggerLivePreview() {
        guard currentOriginalImage != nil else { return }
        previewTask?.cancel()
        previewTask = Task {
            try? await Task.sleep(nanoseconds: 300 * 1_000_000)
            if Task.isCancelled { return }
            await performConversion()
        }
    }
    
    func convertImmediately() {
        previewTask?.cancel()
        Task { await performConversion() }
    }
    
    private func performConversion() async {
        guard let input = currentOriginalImage else { return }
        isConverting = true
        errorMessage = nil
        let machine = currentMachine
        do {
            let result = try await machine.convert(sourceImage: input)
            if !Task.isCancelled { self.currentResult = result }
        } catch {
            if !Task.isCancelled { self.errorMessage = "\(error.localizedDescription)" }
        }
        if !Task.isCancelled { self.isConverting = false }
    }
    
    // MARK: - Export Logic
    
    enum ImageExportType: String {
        case png = "PNG", jpg = "JPG", gif = "GIF", tiff = "TIFF"
    }
    
    func saveImage(as type: ImageExportType) {
        guard let result = currentResult else { return }
        
        let panel = NSSavePanel()
        switch type {
        case .png:  panel.allowedContentTypes = [.png]
        case .jpg:  panel.allowedContentTypes = [.jpeg]
        case .gif:  panel.allowedContentTypes = [.gif]
        case .tiff: panel.allowedContentTypes = [.tiff]
        }
        
        let baseName = getBaseName()
        panel.nameFieldStringValue = "\(baseName).\(type.rawValue.lowercased())"
        panel.canCreateDirectories = true
        panel.title = "Save Image as \(type.rawValue)"
        
        panel.begin { response in
            if response == .OK, let targetUrl = panel.url {
                DispatchQueue.global(qos: .userInitiated).async {
                    var props: [NSBitmapImageRep.PropertyKey : Any] = [:]
                    var fileType: NSBitmapImageRep.FileType = .png
                    
                    switch type {
                    case .png: fileType = .png
                    case .jpg: fileType = .jpeg; props[.compressionFactor] = 0.9
                    case .gif: fileType = .gif
                    case .tiff: fileType = .tiff
                    }
                    
                    if let tiffData = result.previewImage.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let fileData = bitmap.representation(using: fileType, properties: props) {
                        try? fileData.write(to: targetUrl)
                    }
                }
            }
        }
    }
    // MARK: - Native File Export
        
        func saveNativeFile() {
            guard let result = currentResult, let sourceUrl = result.fileAssets.first else { return }
            
            let originalExt = sourceUrl.pathExtension.lowercased()
            let fileTypeLabel = originalExt.uppercased()
            
            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType(filenameExtension: originalExt) ?? .data]
            panel.canCreateDirectories = true
            panel.title = "Save Native \(fileTypeLabel) File"
            
            // Basisnamen ermitteln
            let baseName = getBaseName()
            panel.nameFieldStringValue = "\(baseName).\(originalExt)"
            
            panel.begin { response in
                if response == .OK, let targetUrl = panel.url {
                    do {
                        // Falls Datei schon existiert, löschen
                        if FileManager.default.fileExists(atPath: targetUrl.path) {
                            try FileManager.default.removeItem(at: targetUrl)
                        }
                        // Kopieren
                        try FileManager.default.copyItem(at: sourceUrl, to: targetUrl)
                    } catch {
                        DispatchQueue.main.async {
                            self.errorMessage = "Export failed: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    func createProDOSDisk(size: DiskSize, format: DiskFormat, volumeName: String) {
            guard let result = currentResult else { return }
            
            guard let cadiusUrl = Bundle.main.url(forResource: "cadius", withExtension: nil) else {
                self.errorMessage = "Cadius tool not found in Bundle."
                return
            }
            
            // Name für das Save-Panel
            var outputBaseName = "retro_output"
            var originalFileNameRaw = "IMAGE"
            
            if let id = self.selectedImageId, let item = self.inputImages.first(where: {$0.id == id}) {
                outputBaseName = item.name.replacingOccurrences(of: ".[^.]+$", with: "", options: .regularExpression)
                originalFileNameRaw = item.name
            }
            
            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType(filenameExtension: format.rawValue) ?? .data]
            panel.nameFieldStringValue = "\(outputBaseName).\(format.rawValue)"
            panel.title = "Create ProDOS Disk Image"
            
            panel.begin { response in
                if response == .OK, let targetUrl = panel.url {
                    Task {
                        self.isConverting = true
                        defer { self.isConverting = false }
                        
                        if result.fileAssets.isEmpty {
                            DispatchQueue.main.async { self.errorMessage = "Error: No assets found to write to disk." }
                            return
                        }
                        
                        let fileManager = FileManager.default
                        
                        // 1. Volume Name reinigen
                        var safeVolume = volumeName.uppercased().replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
                        if safeVolume.isEmpty { safeVolume = "BITPAST" }
                        if let first = safeVolume.first, !first.isLetter { safeVolume = "V" + safeVolume }
                        safeVolume = String(safeVolume.prefix(15))
                        
                        print("💾 CREATING DISK: \(targetUrl.lastPathComponent)")
                        
                        // 2. Create Volume (Cadius 1.4+ needs clean target)
                        try? fileManager.removeItem(at: targetUrl)
                        
                        let createArgs = ["CREATEVOLUME", targetUrl.path, safeVolume, size.cadiusSize]
                        
                        do {
                            try self.runCadius(url: cadiusUrl, args: createArgs)
                            
                            // 3. Process & Add Files
                            for (index, assetUrl) in result.fileAssets.enumerated() {
                                
                                // A. ZIEL-NAME
                                let rawName = originalFileNameRaw.uppercased()
                                var finalBaseName = rawName.replacingOccurrences(of: ".[^.]+$", with: "", options: .regularExpression)
                                finalBaseName = finalBaseName.replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
                                if finalBaseName.isEmpty { finalBaseName = "IMG" }
                                if let first = finalBaseName.first, !first.isLetter { finalBaseName = "F" + finalBaseName }
                                if result.fileAssets.count > 1 && index > 0 { finalBaseName += "\(index)" }
                                
                                // Max 11 Zeichen, damit Platz für Extension bleibt (Total 15)
                                finalBaseName = String(finalBaseName.prefix(11))
                                
                                // --- INTELLIGENTE SUFFIX LOGIK ---
                                let fileExt = assetUrl.pathExtension.uppercased()
                                var magicSuffix = "#062000" // Default: BINary, $2000 (Apple II HGR)
                                var proDOSExt = "BIN"
                                
                                // Entscheidung basierend auf Dateiendung vom Converter
                                if fileExt == "SHR" || fileExt == "A2GS" {
                                    // Apple IIgs Super Hi-Res
                                    // Type: $C1 (PIC - Picture)
                                    // Aux:  $0000
                                    magicSuffix = "#C10000"
                                    proDOSExt = "PIC" // Oder "SHR", aber PIC ist üblicher für Type $C1
                                } else if fileExt == "BIN" {
                                    // Apple II Standard
                                    magicSuffix = "#062000"
                                    proDOSExt = "BIN"
                                }
                                
                                let finalProDOSName = "\(finalBaseName).\(proDOSExt)"
                                
                                // B. IMPORT-NAME
                                let shortNameOnDisk = "TMP\(index)"
                                let importFilename = "\(shortNameOnDisk)\(magicSuffix)"
                                
                                print("➡️ FILE \(index+1) (\(fileExt)):")
                                print("   Suffix: \(magicSuffix)")
                                print("   Final:  \(finalProDOSName)")
                                
                                // C. Temp Datei
                                let tempFolder = fileManager.temporaryDirectory
                                let tempFileUrl = tempFolder.appendingPathComponent(importFilename)
                                
                                try? fileManager.removeItem(at: tempFileUrl)
                                try fileManager.copyItem(at: assetUrl, to: tempFileUrl)
                                
                                // D. ADDFILE
                                let targetFolderOnDisk = "/\(safeVolume)/"
                                let addArgs = ["ADDFILE", targetUrl.path, targetFolderOnDisk, tempFileUrl.path]
                                try self.runCadius(url: cadiusUrl, args: addArgs)
                                
                                try? fileManager.removeItem(at: tempFileUrl)
                                
                                // E. RENAMEFILE
                                let fullPathToTempFile = "/\(safeVolume)/\(shortNameOnDisk)"
                                let renameArgs = ["RENAMEFILE", targetUrl.path, fullPathToTempFile, finalProDOSName]
                                try self.runCadius(url: cadiusUrl, args: renameArgs)
                            }
                            
                            print("✅ DISK CREATION SUCCESSFUL")
                            
                        } catch {
                            print("❌ DISK ERROR: \(error)")
                            DispatchQueue.main.async {
                                self.errorMessage = "Disk creation failed: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            }
        }
    
    private func runCadius(url: URL, args: [String]) throws {
            // 1. Debugging: Was rufen wir genau auf?
            print("🛠️ CADIUS RUNNING: \(url.path)")
            print("   ARGS: \(args.joined(separator: " "))")

            let process = Process()
            process.executableURL = url
            process.arguments = args
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
            } catch {
                print("❌ CADIUS START FAILED: \(error)")
                throw error
            }
            
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // 2. Debugging: Was sagt Cadius?
            if !output.isEmpty {
                print("📝 CADIUS OUTPUT:\n\(output)")
            }

            if process.terminationStatus != 0 {
                print("❌ CADIUS EXIT CODE: \(process.terminationStatus)")
                // Wir packen den Output in den Fehler, damit er in der UI angezeigt wird (oder im Log)
                throw NSError(domain: "CadiusError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Cadius Error (\(process.terminationStatus)): \(output)"])
            }
        }
    
    private func getBaseName() -> String {
        if let id = self.selectedImageId, let item = self.inputImages.first(where: {$0.id == id}) {
            return item.name.replacingOccurrences(of: ".[^.]+$", with: "", options: .regularExpression).replacingOccurrences(of: " ", with: "_")
        }
        return "retro_output"
    }
}
