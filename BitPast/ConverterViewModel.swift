import SwiftUI
import Combine
import UniformTypeIdentifiers

// GLOBAL STRUKTUR
struct InputImage: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let image: NSImage
    let details: String

    // Extended metadata
    let fileURL: URL?
    let fileSize: Int64?        // In bytes
    let format: String          // File extension (e.g., "JPEG", "PNG")
    let bitsPerPixel: Int?
    let colorSpace: String?
    let dpi: Int?
    let hasAlpha: Bool

    // Per-image conversion settings (for batch export with individual settings)
    var lockedSettings: [ConversionOption]?
    var lockedMachineIndex: Int?  // Which machine these settings are for

    init(name: String, image: NSImage, details: String, fileURL: URL? = nil, fileSize: Int64? = nil, format: String = "Unknown", bitsPerPixel: Int? = nil, colorSpace: String? = nil, dpi: Int? = nil, hasAlpha: Bool = false, lockedSettings: [ConversionOption]? = nil, lockedMachineIndex: Int? = nil) {
        self.name = name
        self.image = image
        self.details = details
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.format = format
        self.bitsPerPixel = bitsPerPixel
        self.colorSpace = colorSpace
        self.dpi = dpi
        self.hasAlpha = hasAlpha
        self.lockedSettings = lockedSettings
        self.lockedMachineIndex = lockedMachineIndex
    }

    var isLocked: Bool {
        lockedSettings != nil
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: InputImage, rhs: InputImage) -> Bool { lhs.id == rhs.id }

    // Helper to format file size
    var formattedFileSize: String? {
        guard let size = fileSize else { return nil }
        if size < 1024 {
            return "\(size) bytes"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
        }
    }
}

@MainActor
class ConverterViewModel: ObservableObject {
    static let shared = ConverterViewModel()

    @Published var machines: [RetroMachine] = [AppleIIConverter(), AppleIIGSConverter(), Amiga500Converter(), Amiga1200Converter(), AmstradCPCConverter(), Atari800Converter(), AtariSTConverter(), BBCMicroConverter(), C64Converter(), MSXConverter(), PCConverter(), Plus4Converter(), TRS80CoCoConverter(), VIC20Converter(), ZXSpectrumConverter()]
    @Published var selectedMachineIndex: Int = 0
    
    @Published var inputImages: [InputImage] = []
    @Published var selectedImageId: UUID?
    @Published var selectedImageIds: Set<UUID> = []
    
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

    var allImagesSelected: Bool {
        !inputImages.isEmpty && selectedImageIds.count == inputImages.count
    }

    var someImagesSelected: Bool {
        !selectedImageIds.isEmpty && selectedImageIds.count < inputImages.count
    }

    // Batch export state
    @Published var isBatchExporting: Bool = false
    @Published var batchExportProgress: Double = 0
    @Published var batchExportTotal: Int = 0
    @Published var batchExportCurrent: Int = 0
    var lastClickedIndex: Int? = nil

    // Disk creation progress state
    @Published var isDiskCreating: Bool = false
    @Published var diskCreationProgress: Double = 0
    @Published var diskCreationTotal: Int = 0
    @Published var diskCreationCurrent: Int = 0
    @Published var diskCreationStatus: String = ""

    func toggleSelectAll() {
        if allImagesSelected {
            selectedImageIds.removeAll()
        } else {
            selectedImageIds = Set(inputImages.map { $0.id })
        }
    }

    func toggleImageSelection(_ id: UUID) {
        if selectedImageIds.contains(id) {
            selectedImageIds.remove(id)
        } else {
            selectedImageIds.insert(id)
        }
        // Update last clicked index
        if let idx = inputImages.firstIndex(where: { $0.id == id }) {
            lastClickedIndex = idx
        }
    }

    func selectRange(to id: UUID) {
        guard let toIndex = inputImages.firstIndex(where: { $0.id == id }) else { return }
        let fromIndex = lastClickedIndex ?? 0
        let range = min(fromIndex, toIndex)...max(fromIndex, toIndex)
        for i in range {
            selectedImageIds.insert(inputImages[i].id)
        }
        lastClickedIndex = toIndex
    }

    func removeSelectedImages() {
        guard !selectedImageIds.isEmpty else { return }
        inputImages.removeAll { selectedImageIds.contains($0.id) }
        selectedImageIds.removeAll()
        lastClickedIndex = nil
        if !inputImages.isEmpty {
            selectedImageId = inputImages.first?.id
            convertImmediately()
        } else {
            selectedImageId = nil
            currentResult = nil
        }
    }

    // MARK: - Per-Image Settings Lock/Unlock

    /// Lock the current settings for the selected image
    func lockCurrentSettings() {
        guard let selectedId = selectedImageId,
              let index = inputImages.firstIndex(where: { $0.id == selectedId }) else { return }

        // Copy current machine settings to the image
        var updatedImage = inputImages[index]
        updatedImage.lockedSettings = currentMachine.options
        updatedImage.lockedMachineIndex = selectedMachineIndex
        inputImages[index] = updatedImage
    }

    /// Unlock (remove) per-image settings for the selected image
    func unlockSettings() {
        guard let selectedId = selectedImageId,
              let index = inputImages.firstIndex(where: { $0.id == selectedId }) else { return }

        var updatedImage = inputImages[index]
        updatedImage.lockedSettings = nil
        updatedImage.lockedMachineIndex = nil
        inputImages[index] = updatedImage
    }

    /// Check if the selected image has locked settings
    var selectedImageIsLocked: Bool {
        guard let selectedId = selectedImageId,
              let image = inputImages.first(where: { $0.id == selectedId }) else { return false }
        return image.isLocked
    }

    /// Check if the selected image's locked settings match the current machine
    var selectedImageLockedForCurrentMachine: Bool {
        guard let selectedId = selectedImageId,
              let image = inputImages.first(where: { $0.id == selectedId }) else { return false }
        return image.lockedMachineIndex == selectedMachineIndex
    }

    func batchExport() {
        guard !selectedImageIds.isEmpty else { return }

        // Show folder picker
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Export Folder"
        panel.message = "Select a folder to save \(selectedImageIds.count) converted images"

        guard panel.runModal() == .OK, let folderURL = panel.url else { return }

        // Get images to export
        let imagesToExport = inputImages.filter { selectedImageIds.contains($0.id) }
        batchExportTotal = imagesToExport.count
        batchExportCurrent = 0
        batchExportProgress = 0
        isBatchExporting = true

        Task {
            for (index, imageItem) in imagesToExport.enumerated() {
                do {
                    // Convert the image using per-image settings if locked, otherwise use global settings
                    let settingsToUse = (imageItem.lockedSettings != nil && imageItem.lockedMachineIndex == self.selectedMachineIndex)
                        ? imageItem.lockedSettings : nil
                    let result = try await currentMachine.convert(sourceImage: imageItem.image, withSettings: settingsToUse)

                    // Copy native file to export folder
                    if let sourceURL = result.fileAssets.first {
                        let baseName = (imageItem.name as NSString).deletingPathExtension
                        let fileExtension = sourceURL.pathExtension
                        let fileName = "\(baseName).\(fileExtension)"
                        let destURL = folderURL.appendingPathComponent(fileName)

                        // Remove existing file if it exists
                        if FileManager.default.fileExists(atPath: destURL.path) {
                            try FileManager.default.removeItem(at: destURL)
                        }
                        try FileManager.default.copyItem(at: sourceURL, to: destURL)
                    }

                    await MainActor.run {
                        batchExportCurrent = index + 1
                        batchExportProgress = Double(index + 1) / Double(batchExportTotal)
                    }
                } catch {
                    print("Error exporting \(imageItem.name): \(error)")
                }
            }

            await MainActor.run {
                isBatchExporting = false
                // Optionally clear selection after export
                // selectedImageIds.removeAll()
            }
        }
    }

    func batchSaveImages(as type: ImageExportType) {
        guard !selectedImageIds.isEmpty else { return }

        // Show folder picker
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Export Folder"
        panel.message = "Save \(selectedImageIds.count) images as \(type.rawValue.uppercased())"

        guard panel.runModal() == .OK, let folderURL = panel.url else { return }

        // Get images to export
        let imagesToExport = inputImages.filter { selectedImageIds.contains($0.id) }
        batchExportTotal = imagesToExport.count
        batchExportCurrent = 0
        batchExportProgress = 0
        isBatchExporting = true

        Task {
            for (index, imageItem) in imagesToExport.enumerated() {
                do {
                    // Convert the image using per-image settings if locked, otherwise use global settings
                    let settingsToUse = (imageItem.lockedSettings != nil && imageItem.lockedMachineIndex == self.selectedMachineIndex)
                        ? imageItem.lockedSettings : nil
                    let result = try await currentMachine.convert(sourceImage: imageItem.image, withSettings: settingsToUse)

                    // Save as specified image format
                    let baseName = (imageItem.name as NSString).deletingPathExtension
                    let fileName = "\(baseName).\(type.rawValue.lowercased())"
                    let destURL = folderURL.appendingPathComponent(fileName)

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
                        try fileData.write(to: destURL)
                    }

                    await MainActor.run {
                        batchExportCurrent = index + 1
                        batchExportProgress = Double(index + 1) / Double(batchExportTotal)
                    }
                } catch {
                    print("Error exporting \(imageItem.name): \(error)")
                }
            }

            await MainActor.run {
                isBatchExporting = false
            }
        }
    }

    func batchSaveNativeFiles() {
        guard !selectedImageIds.isEmpty else { return }

        // Show folder picker
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Export Folder"
        panel.message = "Save \(selectedImageIds.count) images in native format"

        guard panel.runModal() == .OK, let folderURL = panel.url else { return }

        // Get images to export (this is same as batchExport)
        let imagesToExport = inputImages.filter { selectedImageIds.contains($0.id) }
        batchExportTotal = imagesToExport.count
        batchExportCurrent = 0
        batchExportProgress = 0
        isBatchExporting = true

        Task {
            for (index, imageItem) in imagesToExport.enumerated() {
                do {
                    // Convert the image using per-image settings if locked, otherwise use global settings
                    let settingsToUse = (imageItem.lockedSettings != nil && imageItem.lockedMachineIndex == self.selectedMachineIndex)
                        ? imageItem.lockedSettings : nil
                    let result = try await currentMachine.convert(sourceImage: imageItem.image, withSettings: settingsToUse)

                    // Copy native file to export folder
                    if let sourceURL = result.fileAssets.first {
                        let baseName = (imageItem.name as NSString).deletingPathExtension
                        let fileExtension = sourceURL.pathExtension
                        let fileName = "\(baseName).\(fileExtension)"
                        let destURL = folderURL.appendingPathComponent(fileName)

                        // Remove existing file if it exists
                        if FileManager.default.fileExists(atPath: destURL.path) {
                            try FileManager.default.removeItem(at: destURL)
                        }
                        try FileManager.default.copyItem(at: sourceURL, to: destURL)
                    }

                    await MainActor.run {
                        batchExportCurrent = index + 1
                        batchExportProgress = Double(index + 1) / Double(batchExportTotal)
                    }
                } catch {
                    print("Error exporting \(imageItem.name): \(error)")
                }
            }

            await MainActor.run {
                isBatchExporting = false
            }
        }
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

                            // Extract metadata from pasted image
                            var bitsPerPixel: Int? = nil
                            var colorSpace: String? = nil
                            var hasAlpha = false

                            if let rep = img.representations.first as? NSBitmapImageRep {
                                bitsPerPixel = rep.bitsPerPixel
                                hasAlpha = rep.hasAlpha
                                let csName = rep.colorSpaceName
                                switch csName {
                                case .calibratedRGB, .deviceRGB:
                                    colorSpace = "RGB"
                                case .calibratedWhite, .deviceWhite:
                                    colorSpace = "Grayscale"
                                case .deviceCMYK:
                                    colorSpace = "CMYK"
                                default:
                                    colorSpace = "sRGB"
                                }
                            }

                            let newItem = InputImage(
                                name: "Pasted Image",
                                image: img,
                                details: info,
                                fileURL: nil,
                                fileSize: nil,
                                format: "Clipboard",
                                bitsPerPixel: bitsPerPixel,
                                colorSpace: colorSpace,
                                dpi: 72,
                                hasAlpha: hasAlpha
                            )
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

            // Extract file size
            var fileSize: Int64? = nil
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                fileSize = size
            }

            // Extract image metadata from bitmap representation
            var bitsPerPixel: Int? = nil
            var colorSpace: String? = nil
            var dpi: Int? = nil
            var hasAlpha = false

            if let rep = img.representations.first as? NSBitmapImageRep {
                bitsPerPixel = rep.bitsPerPixel
                hasAlpha = rep.hasAlpha

                // Get color space name
                let csName = rep.colorSpaceName
                switch csName {
                case .calibratedRGB, .deviceRGB:
                    colorSpace = "RGB"
                case .calibratedWhite, .deviceWhite:
                    colorSpace = "Grayscale"
                case .deviceCMYK:
                    colorSpace = "CMYK"
                default:
                    colorSpace = "sRGB"
                }

                // Calculate DPI from pixels per unit
                let pixelsWide = rep.pixelsWide
                let pointsWide = rep.size.width
                if pointsWide > 0 {
                    dpi = Int(Double(pixelsWide) / pointsWide * 72.0)
                }
            }

            let newItem = InputImage(
                name: name,
                image: img,
                details: info,
                fileURL: url,
                fileSize: fileSize,
                format: ext.isEmpty ? "Unknown" : ext,
                bitsPerPixel: bitsPerPixel,
                colorSpace: colorSpace,
                dpi: dpi,
                hasAlpha: hasAlpha
            )
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
        // Get images to convert: selected ones, or all if none selected
        let imagesToConvert: [InputImage]
        if !selectedImageIds.isEmpty {
            imagesToConvert = inputImages.filter { selectedImageIds.contains($0.id) }
        } else {
            imagesToConvert = inputImages
        }

        guard !imagesToConvert.isEmpty else {
            self.errorMessage = "No images to add to disk."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: format.rawValue) ?? .data]
        panel.nameFieldStringValue = "IMAGES.\(format.rawValue)"
        panel.title = "Create ProDOS Disk Image"

        panel.begin { response in
            if response == .OK, let targetUrl = panel.url {
                Task {
                    await MainActor.run {
                        self.isDiskCreating = true
                        self.diskCreationStatus = "Preparing..."
                    }
                    defer { Task { await MainActor.run { self.isDiskCreating = false } } }

                    // Clean volume name
                    var safeVolume = volumeName.uppercased().replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
                    if safeVolume.isEmpty { safeVolume = "BITPAST" }
                    if let first = safeVolume.first, !first.isLetter { safeVolume = "V" + safeVolume }
                    safeVolume = String(safeVolume.prefix(15))

                    print("Creating ProDOS disk: \(targetUrl.lastPathComponent)")
                    print("Converting \(imagesToConvert.count) image(s)...")

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

                    // Convert each image and add to disk
                    var fileIndex = 0
                    var totalBytesUsed = 0
                    let availableBytes = size.totalBlocks * 512 - 8192 // Reserve space for volume directory

                    // Initialize progress tracking
                    await MainActor.run {
                        self.diskCreationTotal = imagesToConvert.count
                        self.diskCreationCurrent = 0
                        self.diskCreationProgress = 0
                    }

                    for (imageIndex, imageItem) in imagesToConvert.enumerated() {
                        // Update progress
                        await MainActor.run {
                            self.diskCreationCurrent = imageIndex + 1
                            self.diskCreationProgress = Double(imageIndex) / Double(imagesToConvert.count)
                            self.diskCreationStatus = "Converting \(imageItem.name)..."
                        }

                        do {
                            // Convert the image using per-image settings if locked, otherwise use global settings
                            let settingsToUse = (imageItem.lockedSettings != nil && imageItem.lockedMachineIndex == self.selectedMachineIndex)
                                ? imageItem.lockedSettings : nil
                            let result = try await self.currentMachine.convert(sourceImage: imageItem.image, withSettings: settingsToUse)

                            for assetUrl in result.fileAssets {
                                // Build target filename from original image name
                                let rawName = imageItem.name.uppercased()
                                var finalBaseName = rawName.replacingOccurrences(of: ".[^.]+$", with: "", options: .regularExpression)
                                finalBaseName = finalBaseName.replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
                                if finalBaseName.isEmpty { finalBaseName = "IMG" }
                                if let first = finalBaseName.first, !first.isLetter { finalBaseName = "F" + finalBaseName }
                                // Add index for unique filenames
                                if imagesToConvert.count > 1 || result.fileAssets.count > 1 {
                                    finalBaseName = String(finalBaseName.prefix(8)) + "\(fileIndex)"
                                }
                                finalBaseName = String(finalBaseName.prefix(11))

                                // Determine file type and aux type based on extension
                                let fileExt = assetUrl.pathExtension.uppercased()
                                var fileType: UInt8 = 0x06  // BIN
                                var auxType: UInt16 = 0x2000 // Default load address
                                var proDOSExt = "BIN"

                                if fileExt == "SHR" || fileExt == "A2GS" {
                                    fileType = 0xC1
                                    auxType = 0x0000  // Standard SHR 320 mode
                                    proDOSExt = "PIC"
                                } else if fileExt == "3200" {
                                    fileType = 0xC1
                                    auxType = 0x0002  // Brooks 3200-color format
                                    proDOSExt = "PIC"
                                } else if fileExt == "BIN" {
                                    fileType = 0x06
                                    auxType = 0x2000
                                    proDOSExt = "BIN"
                                }

                                let finalProDOSName = "\(finalBaseName).\(proDOSExt)"

                                // Read file data
                                guard let fileData = try? Data(contentsOf: assetUrl) else {
                                    print("Could not read file: \(assetUrl.path)")
                                    continue
                                }

                                // Check if file fits on disk
                                totalBytesUsed += fileData.count
                                if totalBytesUsed > availableBytes {
                                    await MainActor.run {
                                        self.errorMessage = "Disk full! Only \(fileIndex) file(s) added. Choose a larger disk size."
                                    }
                                    print("Disk full after \(fileIndex) files")
                                    return
                                }

                                print("Adding file \(fileIndex+1): \(finalProDOSName) (type $\(String(format: "%02X", fileType)), \(fileData.count) bytes)")

                                // Add file using native ProDOSWriter
                                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                                    ProDOSWriter.shared.addFile(diskImagePath: targetUrl, fileName: finalProDOSName, fileData: fileData, fileType: fileType, auxType: auxType) { success, message in
                                        if !success {
                                            print("Failed to add file: \(message)")
                                        }
                                        continuation.resume()
                                    }
                                }

                                fileIndex += 1
                            }
                        } catch {
                            print("Error converting \(imageItem.name): \(error)")
                        }
                    }

                    // Final progress update
                    await MainActor.run {
                        self.diskCreationProgress = 1.0
                        self.diskCreationStatus = "Complete!"
                    }

                    print("Disk creation complete! Added \(fileIndex) file(s), \(totalBytesUsed) bytes used")
                }
            }
        }
    }

    // MARK: - Batch Conversion Helper

    /// Returns images to convert: selected ones, or all if none selected
    private func getImagesToConvert() -> [InputImage] {
        if !selectedImageIds.isEmpty {
            return inputImages.filter { selectedImageIds.contains($0.id) }
        } else {
            return inputImages
        }
    }

    /// Batch convert images and return file URLs with their original image names
    private func batchConvertAndCollectFiles() async -> [(url: URL, name: String)] {
        let imagesToConvert = getImagesToConvert()
        var allFiles: [(url: URL, name: String)] = []

        // Update progress state
        await MainActor.run {
            self.diskCreationTotal = imagesToConvert.count
            self.diskCreationCurrent = 0
            self.diskCreationProgress = 0
        }

        for (index, imageItem) in imagesToConvert.enumerated() {
            // Update progress
            await MainActor.run {
                self.diskCreationCurrent = index + 1
                self.diskCreationProgress = Double(index) / Double(imagesToConvert.count)
                self.diskCreationStatus = "Converting \(imageItem.name)..."
            }

            do {
                // Convert the image using per-image settings if locked, otherwise use global settings
                let settingsToUse = (imageItem.lockedSettings != nil && imageItem.lockedMachineIndex == self.selectedMachineIndex)
                    ? imageItem.lockedSettings : nil
                let result = try await currentMachine.convert(sourceImage: imageItem.image, withSettings: settingsToUse)
                // Get base name without extension from original image
                let baseName = (imageItem.name as NSString).deletingPathExtension
                for (assetIndex, assetUrl) in result.fileAssets.enumerated() {
                    // If multiple assets per image, append index
                    let fileName = result.fileAssets.count > 1 ? "\(baseName)\(assetIndex)" : baseName
                    allFiles.append((url: assetUrl, name: fileName))
                }
            } catch {
                print("Error converting \(imageItem.name): \(error)")
            }
        }

        // Final progress update
        await MainActor.run {
            self.diskCreationProgress = 1.0
            self.diskCreationStatus = "Writing disk image..."
        }

        return allFiles
    }

    // MARK: - Universal Disk Image Creation

    func createDiskImage(configuration: DiskConfiguration) {
        // Route to appropriate disk writer based on system
        switch configuration.system {
        case .appleII, .appleIIgs:
            // Convert DiskConfiguration to existing ProDOS types
            let proDOSSize: DiskSize
            switch configuration.size {
            case .kb140: proDOSSize = .kb140
            case .kb800: proDOSSize = .kb800
            case .mb32: proDOSSize = .mb32
            default: proDOSSize = .kb140
            }

            let proDOSFormat: DiskFormat
            switch configuration.format {
            case .po: proDOSFormat = .po
            case .twoMG: proDOSFormat = .twoMG
            case .hdv: proDOSFormat = .hdv
            default: proDOSFormat = .po
            }

            createProDOSDisk(size: proDOSSize, format: proDOSFormat, volumeName: configuration.volumeName)

        case .c64, .vic20, .plus4:
            createCBMDisk(configuration: configuration)

        case .amiga500, .amiga1200:
            createAmigaDisk(configuration: configuration)

        case .atari800:
            createAtariDisk(configuration: configuration)

        case .atariST:
            createAtariSTDisk(configuration: configuration)

        case .msx:
            createMSXDisk(configuration: configuration)

        case .amstradCPC:
            createCPCDisk(configuration: configuration)

        case .zxSpectrum:
            createSpectrumDisk(configuration: configuration)

        case .bbcMicro:
            createBBCDisk(configuration: configuration)

        case .pc:
            createPCDisk(configuration: configuration)

        case .trs80coco:
            createCoCoDisk(configuration: configuration)
        }
    }

    // MARK: - Commodore Disk (D64/D71/D81)

    private func createCBMDisk(configuration: DiskConfiguration) {
        let imagesToConvert = getImagesToConvert()
        guard !imagesToConvert.isEmpty else {
            self.errorMessage = "No images to add to disk."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: configuration.format.fileExtension) ?? .data]
        panel.nameFieldStringValue = "IMAGES.\(configuration.format.fileExtension)"
        panel.title = "Create Commodore Disk Image"

        panel.begin { response in
            if response == .OK, let targetUrl = panel.url {
                Task {
                    await MainActor.run {
                        self.isDiskCreating = true
                        self.diskCreationStatus = "Preparing..."
                    }
                    defer { Task { await MainActor.run { self.isDiskCreating = false } } }

                    let allFiles = await self.batchConvertAndCollectFiles()

                    if allFiles.isEmpty {
                        await MainActor.run { self.errorMessage = "No assets to write to disk." }
                        return
                    }

                    // Create D64/D71/D81 disk image with proper filenames
                    let success = D64Writer.shared.createDiskImageWithNames(
                        at: targetUrl,
                        volumeName: configuration.volumeName,
                        format: configuration.format,
                        size: configuration.size,
                        files: allFiles
                    )

                    if !success {
                        await MainActor.run { self.errorMessage = "Failed to create Commodore disk image" }
                    }
                }
            }
        }
    }

    // MARK: - Amiga Disk (ADF)

    private func createAmigaDisk(configuration: DiskConfiguration) {
        let imagesToConvert = getImagesToConvert()
        guard !imagesToConvert.isEmpty else {
            self.errorMessage = "No images to add to disk."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "adf") ?? .data]
        panel.nameFieldStringValue = "IMAGES.adf"
        panel.title = "Create Amiga Disk Image"

        panel.begin { response in
            if response == .OK, let targetUrl = panel.url {
                Task {
                    await MainActor.run {
                        self.isDiskCreating = true
                        self.diskCreationStatus = "Preparing..."
                    }
                    defer { Task { await MainActor.run { self.isDiskCreating = false } } }

                    let allFiles = await self.batchConvertAndCollectFiles()

                    if allFiles.isEmpty {
                        await MainActor.run { self.errorMessage = "No assets to write to disk." }
                        return
                    }

                    let success = ADFWriter.shared.createDiskImage(
                        at: targetUrl,
                        volumeName: configuration.volumeName,
                        size: configuration.size,
                        files: allFiles
                    )

                    if !success {
                        await MainActor.run { self.errorMessage = "Failed to create Amiga disk image" }
                    }
                }
            }
        }
    }

    // MARK: - Atari 800 Disk (ATR)

    private func createAtariDisk(configuration: DiskConfiguration) {
        let imagesToConvert = getImagesToConvert()
        guard !imagesToConvert.isEmpty else {
            self.errorMessage = "No images to add to disk."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "atr") ?? .data]
        panel.nameFieldStringValue = "IMAGES.atr"
        panel.title = "Create Atari 800 Disk Image"

        panel.begin { response in
            if response == .OK, let targetUrl = panel.url {
                Task {
                    await MainActor.run {
                        self.isDiskCreating = true
                        self.diskCreationStatus = "Preparing..."
                    }
                    defer { Task { await MainActor.run { self.isDiskCreating = false } } }

                    let allFiles = await self.batchConvertAndCollectFiles()

                    if allFiles.isEmpty {
                        await MainActor.run { self.errorMessage = "No assets to write to disk." }
                        return
                    }

                    let success = ATRWriter.shared.createDiskImage(
                        at: targetUrl,
                        volumeName: configuration.volumeName,
                        size: configuration.size,
                        files: allFiles
                    )

                    if !success {
                        await MainActor.run { self.errorMessage = "Failed to create Atari disk image" }
                    }
                }
            }
        }
    }

    // MARK: - Atari ST Disk (ST)

    private func createAtariSTDisk(configuration: DiskConfiguration) {
        let imagesToConvert = getImagesToConvert()
        guard !imagesToConvert.isEmpty else {
            self.errorMessage = "No images to add to disk."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "st") ?? .data]
        panel.nameFieldStringValue = "IMAGES.st"
        panel.title = "Create Atari ST Disk Image"

        panel.begin { response in
            if response == .OK, let targetUrl = panel.url {
                Task {
                    await MainActor.run {
                        self.isDiskCreating = true
                        self.diskCreationStatus = "Preparing..."
                    }
                    defer { Task { await MainActor.run { self.isDiskCreating = false } } }

                    let allFiles = await self.batchConvertAndCollectFiles()

                    if allFiles.isEmpty {
                        await MainActor.run { self.errorMessage = "No assets to write to disk." }
                        return
                    }

                    let success = STWriter.shared.createDiskImage(
                        at: targetUrl,
                        volumeName: configuration.volumeName,
                        size: configuration.size,
                        files: allFiles
                    )

                    if !success {
                        await MainActor.run { self.errorMessage = "Failed to create Atari ST disk image" }
                    }
                }
            }
        }
    }

    // MARK: - MSX Disk (DSK)

    private func createMSXDisk(configuration: DiskConfiguration) {
        let imagesToConvert = getImagesToConvert()
        guard !imagesToConvert.isEmpty else {
            self.errorMessage = "No images to add to disk."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "dsk") ?? .data]
        panel.nameFieldStringValue = "IMAGES.dsk"
        panel.title = "Create MSX Disk Image"

        panel.begin { response in
            if response == .OK, let targetUrl = panel.url {
                Task {
                    await MainActor.run {
                        self.isDiskCreating = true
                        self.diskCreationStatus = "Preparing..."
                    }
                    defer { Task { await MainActor.run { self.isDiskCreating = false } } }

                    let allFiles = await self.batchConvertAndCollectFiles()

                    if allFiles.isEmpty {
                        await MainActor.run { self.errorMessage = "No assets to write to disk." }
                        return
                    }

                    let success = MSXDiskWriter.shared.createDiskImage(
                        at: targetUrl,
                        volumeName: configuration.volumeName,
                        size: configuration.size,
                        files: allFiles
                    )

                    if !success {
                        await MainActor.run { self.errorMessage = "Failed to create MSX disk image" }
                    }
                }
            }
        }
    }

    // MARK: - Amstrad CPC Disk (DSK)

    private func createCPCDisk(configuration: DiskConfiguration) {
        let imagesToConvert = getImagesToConvert()
        guard !imagesToConvert.isEmpty else {
            self.errorMessage = "No images to add to disk."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "dsk") ?? .data]
        panel.nameFieldStringValue = "IMAGES.dsk"
        panel.title = "Create Amstrad CPC Disk Image"

        panel.begin { response in
            if response == .OK, let targetUrl = panel.url {
                Task {
                    await MainActor.run {
                        self.isDiskCreating = true
                        self.diskCreationStatus = "Preparing..."
                    }
                    defer { Task { await MainActor.run { self.isDiskCreating = false } } }

                    let allFiles = await self.batchConvertAndCollectFiles()

                    if allFiles.isEmpty {
                        await MainActor.run { self.errorMessage = "No assets to write to disk." }
                        return
                    }

                    let success = CPCDiskWriter.shared.createDiskImage(
                        at: targetUrl,
                        volumeName: configuration.volumeName,
                        size: configuration.size,
                        files: allFiles
                    )

                    if !success {
                        await MainActor.run { self.errorMessage = "Failed to create Amstrad CPC disk image" }
                    }
                }
            }
        }
    }

    // MARK: - ZX Spectrum Disk (TRD/DSK)

    private func createSpectrumDisk(configuration: DiskConfiguration) {
        let imagesToConvert = getImagesToConvert()
        guard !imagesToConvert.isEmpty else {
            self.errorMessage = "No images to add to disk."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: configuration.format.fileExtension) ?? .data]
        panel.nameFieldStringValue = "IMAGES.\(configuration.format.fileExtension)"
        panel.title = "Create ZX Spectrum Disk Image"

        panel.begin { response in
            if response == .OK, let targetUrl = panel.url {
                Task {
                    await MainActor.run {
                        self.isDiskCreating = true
                        self.diskCreationStatus = "Preparing..."
                    }
                    defer { Task { await MainActor.run { self.isDiskCreating = false } } }

                    let allFiles = await self.batchConvertAndCollectFiles()

                    if allFiles.isEmpty {
                        await MainActor.run { self.errorMessage = "No assets to write to disk." }
                        return
                    }

                    let success = TRDWriter.shared.createDiskImage(
                        at: targetUrl,
                        volumeName: configuration.volumeName,
                        format: configuration.format,
                        size: configuration.size,
                        files: allFiles
                    )

                    if !success {
                        await MainActor.run { self.errorMessage = "Failed to create ZX Spectrum disk image" }
                    }
                }
            }
        }
    }

    // MARK: - BBC Micro Disk (SSD/DSD)

    private func createBBCDisk(configuration: DiskConfiguration) {
        let imagesToConvert = getImagesToConvert()
        guard !imagesToConvert.isEmpty else {
            self.errorMessage = "No images to add to disk."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: configuration.format.fileExtension) ?? .data]
        panel.nameFieldStringValue = "IMAGES.\(configuration.format.fileExtension)"
        panel.title = "Create BBC Micro Disk Image"

        panel.begin { response in
            if response == .OK, let targetUrl = panel.url {
                Task {
                    await MainActor.run {
                        self.isDiskCreating = true
                        self.diskCreationStatus = "Preparing..."
                    }
                    defer { Task { await MainActor.run { self.isDiskCreating = false } } }

                    let allFiles = await self.batchConvertAndCollectFiles()

                    if allFiles.isEmpty {
                        await MainActor.run { self.errorMessage = "No assets to write to disk." }
                        return
                    }

                    let success = BBCDiskWriter.shared.createDiskImage(
                        at: targetUrl,
                        volumeName: configuration.volumeName,
                        format: configuration.format,
                        size: configuration.size,
                        files: allFiles
                    )

                    if !success {
                        await MainActor.run { self.errorMessage = "Failed to create BBC Micro disk image" }
                    }
                }
            }
        }
    }

    // MARK: - PC Disk (IMG)

    private func createPCDisk(configuration: DiskConfiguration) {
        let imagesToConvert = getImagesToConvert()
        guard !imagesToConvert.isEmpty else {
            self.errorMessage = "No images to add to disk."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "img") ?? .data]
        panel.nameFieldStringValue = "IMAGES.img"
        panel.title = "Create PC Disk Image"

        panel.begin { response in
            if response == .OK, let targetUrl = panel.url {
                Task {
                    await MainActor.run {
                        self.isDiskCreating = true
                        self.diskCreationStatus = "Preparing..."
                    }
                    defer { Task { await MainActor.run { self.isDiskCreating = false } } }

                    let allFiles = await self.batchConvertAndCollectFiles()

                    if allFiles.isEmpty {
                        await MainActor.run { self.errorMessage = "No assets to write to disk." }
                        return
                    }

                    let success = IMGWriter.shared.createDiskImage(
                        at: targetUrl,
                        volumeName: configuration.volumeName,
                        size: configuration.size,
                        files: allFiles
                    )

                    if !success {
                        await MainActor.run { self.errorMessage = "Failed to create PC disk image" }
                    }
                }
            }
        }
    }

    // MARK: - TRS-80 CoCo Disk (DSK)

    private func createCoCoDisk(configuration: DiskConfiguration) {
        let imagesToConvert = getImagesToConvert()
        guard !imagesToConvert.isEmpty else {
            self.errorMessage = "No images to add to disk."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "dsk") ?? .data]
        panel.nameFieldStringValue = "IMAGES.dsk"
        panel.title = "Create TRS-80 CoCo Disk Image"

        panel.begin { response in
            if response == .OK, let targetUrl = panel.url {
                Task {
                    await MainActor.run {
                        self.isDiskCreating = true
                        self.diskCreationStatus = "Preparing..."
                    }
                    defer { Task { await MainActor.run { self.isDiskCreating = false } } }

                    let allFiles = await self.batchConvertAndCollectFiles()

                    if allFiles.isEmpty {
                        await MainActor.run { self.errorMessage = "No assets to write to disk." }
                        return
                    }

                    let filesWritten = CoCoDiskWriter.shared.createDiskImage(
                        at: targetUrl,
                        volumeName: configuration.volumeName,
                        size: configuration.size,
                        files: allFiles
                    )

                    if filesWritten == 0 {
                        await MainActor.run { self.errorMessage = "Failed to create TRS-80 CoCo disk image" }
                    }
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
