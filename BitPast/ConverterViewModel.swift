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
    @Published var machines: [RetroMachine] = [AppleIIConverter()]
    @Published var selectedMachineIndex: Int = 0
    
    @Published var inputImages: [InputImage] = []
    @Published var selectedImageId: UUID?
    
    @Published var currentResult: ConversionResult?
    @Published var isConverting: Bool = false
    @Published var errorMessage: String?
    
    @Published var selectedExportFormat: ExportFormat = .png
    
    private var previewTask: Task<Void, Never>?
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case png = "PNG", jpg = "JPG", appleII = "Apple II Binary", gif = "GIF", bmp = "BMP"
        var id: String { self.rawValue }
    }
    
    var convertedImage: NSImage? { currentResult?.previewImage }
    var currentOriginalImage: NSImage? {
        guard let id = selectedImageId, let item = inputImages.first(where: { $0.id == id }) else { return nil }
        return item.image
    }
    var currentMachine: RetroMachine {
        get { machines[selectedMachineIndex] }
        set { machines[selectedMachineIndex] = newValue }
    }
    
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
    
    func saveResult() {
        guard let result = currentResult else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let panel = NSSavePanel()
            let type = self.selectedExportFormat
            switch type {
            case .png:  panel.allowedContentTypes = [.png]
            case .jpg:  panel.allowedContentTypes = [.jpeg]
            case .gif:  panel.allowedContentTypes = [.gif]
            case .bmp:  panel.allowedContentTypes = [.bmp]
            case .appleII: panel.allowedContentTypes = [UTType.data]
            }
            var baseName = "retro_output"
            if let id = self.selectedImageId, let item = self.inputImages.first(where: {$0.id == id}) {
                baseName = item.name.replacingOccurrences(of: ".[^.]+$", with: "", options: .regularExpression).replacingOccurrences(of: " ", with: "_")
            }
            let fileExt = type == .appleII ? "BIN" : type.rawValue.lowercased()
            panel.nameFieldStringValue = "\(baseName).\(fileExt)"
            panel.canCreateDirectories = true
            panel.title = type == .appleII ? "Save Apple II Binary Files" : "Export Image"
            panel.begin { response in
                if response == .OK, let targetUrl = panel.url {
                    DispatchQueue.global(qos: .userInitiated).async {
                        if type == .appleII {
                            let fileManager = FileManager.default
                            let targetFolder = targetUrl.deletingLastPathComponent()
                            let targetBaseName = targetUrl.deletingPathExtension().lastPathComponent
                            for assetUrl in result.fileAssets {
                                let assetExt = assetUrl.pathExtension.uppercased()
                                let newFileName = "\(targetBaseName).\(assetExt)"
                                let destination = targetFolder.appendingPathComponent(newFileName)
                                try? fileManager.removeItem(at: destination)
                                try? fileManager.copyItem(at: assetUrl, to: destination)
                            }
                        } else {
                            var props: [NSBitmapImageRep.PropertyKey : Any] = [:]
                            var fileType: NSBitmapImageRep.FileType = .png
                            switch type {
                            case .png: fileType = .png
                            case .jpg: fileType = .jpeg; props[.compressionFactor] = 0.9
                            case .gif: fileType = .gif
                            case .bmp: fileType = .bmp
                            default: break
                            }
                            if let tiffData = result.previewImage.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData), let fileData = bitmap.representation(using: fileType, properties: props) { try? fileData.write(to: targetUrl) }
                        }
                    }
                }
            }
        }
    }
}
