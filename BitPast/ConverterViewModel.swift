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
    static let shared = ConverterViewModel()

    @Published var machines: [RetroMachine] = [AppleIIConverter(), AppleIIGSConverter(), Amiga500Converter(), Amiga1200Converter(), AmstradCPCConverter(), Atari800Converter(), AtariSTConverter(), BBCMicroConverter(), C64Converter(), MSXConverter(), PCConverter(), Plus4Converter(), VIC20Converter(), ZXSpectrumConverter()]
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

            /// Number of 512-byte blocks for this disk size
            var totalBlocks: Int {
                switch self {
                case .kb140: return 280    // 140KB = 280 blocks
                case .kb800: return 1600   // 800KB = 1600 blocks
                case .mb32: return 65535   // 32MB max ProDOS volume
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

        // Name for save panel
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
                    await MainActor.run { self.isConverting = true }
                    defer { Task { await MainActor.run { self.isConverting = false } } }

                    if result.fileAssets.isEmpty {
                        await MainActor.run { self.errorMessage = "Error: No assets found to write to disk." }
                        return
                    }

                    // Clean volume name
                    var safeVolume = volumeName.uppercased().replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
                    if safeVolume.isEmpty { safeVolume = "BITPAST" }
                    if let first = safeVolume.first, !first.isLetter { safeVolume = "V" + safeVolume }
                    safeVolume = String(safeVolume.prefix(15))

                    print("Creating ProDOS disk: \(targetUrl.lastPathComponent)")

                    // Remove existing file if present
                    try? FileManager.default.removeItem(at: targetUrl)

                    // Create disk image using native ProDOSWriter
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        ProDOSWriter.shared.createDiskImage(at: targetUrl, volumeName: safeVolume, totalBlocks: size.totalBlocks) { success, message in
                            if !success {
                                Task { await MainActor.run { self.errorMessage = "Disk creation failed: \(message)" } }
                            }
                            continuation.resume()
                        }
                    }

                    // Check if disk was created
                    guard FileManager.default.fileExists(atPath: targetUrl.path) else {
                        await MainActor.run { self.errorMessage = "Disk creation failed" }
                        return
                    }

                    // Add files to disk
                    for (index, assetUrl) in result.fileAssets.enumerated() {
                        // Build target filename
                        let rawName = originalFileNameRaw.uppercased()
                        var finalBaseName = rawName.replacingOccurrences(of: ".[^.]+$", with: "", options: .regularExpression)
                        finalBaseName = finalBaseName.replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
                        if finalBaseName.isEmpty { finalBaseName = "IMG" }
                        if let first = finalBaseName.first, !first.isLetter { finalBaseName = "F" + finalBaseName }
                        if result.fileAssets.count > 1 && index > 0 { finalBaseName += "\(index)" }
                        finalBaseName = String(finalBaseName.prefix(11))

                        // Determine file type and aux type based on extension
                        let fileExt = assetUrl.pathExtension.uppercased()
                        var fileType: UInt8 = 0x06  // BIN
                        var auxType: UInt16 = 0x2000 // Default load address
                        var proDOSExt = "BIN"

                        if fileExt == "SHR" || fileExt == "A2GS" || fileExt == "3200" {
                            // Apple IIgs Super Hi-Res (PIC type $C1)
                            fileType = 0xC1
                            auxType = 0x0000
                            proDOSExt = "PIC"
                        } else if fileExt == "BIN" {
                            fileType = 0x06
                            auxType = 0x2000
                            proDOSExt = "BIN"
                        }

                        let finalProDOSName = "\(finalBaseName).\(proDOSExt)"

                        print("Adding file \(index+1): \(finalProDOSName) (type $\(String(format: "%02X", fileType)))")

                        // Read file data
                        guard let fileData = try? Data(contentsOf: assetUrl) else {
                            print("Could not read file: \(assetUrl.path)")
                            continue
                        }

                        // Add file using native ProDOSWriter
                        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                            ProDOSWriter.shared.addFile(diskImagePath: targetUrl, fileName: finalProDOSName, fileData: fileData, fileType: fileType, auxType: auxType) { success, message in
                                if !success {
                                    print("Failed to add file: \(message)")
                                }
                                continuation.resume()
                            }
                        }
                    }

                    print("Disk creation complete!")
                }
            }
        }
    }
    
    private func getBaseName() -> String {
        if let id = self.selectedImageId, let item = self.inputImages.first(where: {$0.id == id}) {
            return item.name.replacingOccurrences(of: ".[^.]+$", with: "", options: .regularExpression).replacingOccurrences(of: " ", with: "_")
        }
        return "retro_output"
    }
}
