import SwiftUI

// MARK: - Create Disk Sheet

struct CreateDiskSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedSystemIndex: Int
    @ObservedObject var viewModel: ConverterViewModel
    let onExport: (DiskConfiguration) -> Void

    @State private var selectedFormat: DiskFormat
    @State private var selectedSize: DiskSize
    @State private var volumeName: String = "BITPAST"

    private var selectedSystem: DiskSystem {
        DiskSystem(rawValue: selectedSystemIndex) ?? .appleII
    }

    init(isPresented: Binding<Bool>,
         selectedSystemIndex: Binding<Int>,
         viewModel: ConverterViewModel,
         onExport: @escaping (DiskConfiguration) -> Void) {
        self._isPresented = isPresented
        self._selectedSystemIndex = selectedSystemIndex
        self.viewModel = viewModel
        self.onExport = onExport

        // Initialize format and size based on initial system
        let system = DiskSystem(rawValue: selectedSystemIndex.wrappedValue) ?? .appleII
        self._selectedFormat = State(initialValue: system.defaultFormat)
        self._selectedSize = State(initialValue: system.defaultSize)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // System Selection Bar
            systemSelectionBar

            Divider()

            // Options Section
            optionsSection

            Divider()

            // Buttons
            buttonSection
        }
        .frame(width: 900, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: selectedSystemIndex) { _, newValue in
            updateForSystem(DiskSystem(rawValue: newValue) ?? .appleII)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("Create Disk Image")
                    .font(.headline)
                Text("Create a virtual disk image with your converted files")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - System Selection Bar

    private var systemSelectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(DiskSystem.allCases) { system in
                    DiskSystemButton(
                        system: system,
                        isSelected: selectedSystemIndex == system.rawValue
                    ) {
                        selectedSystemIndex = system.rawValue
                    }

                    if system != DiskSystem.allCases.last {
                        Rectangle()
                            .fill(Color(NSColor.separatorColor).opacity(0.3))
                            .frame(width: 1)
                    }
                }
            }
        }
        .frame(height: 70)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Selected System Info
            HStack {
                Image(selectedSystem.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedSystem.displayName)
                        .font(.headline)
                    Text("Disk image for \(selectedSystem.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.bottom, 8)

            // Volume Name
            HStack {
                Text("Volume Name:")
                    .frame(width: 100, alignment: .trailing)

                TextField("Volume Name", text: $volumeName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .onChange(of: volumeName) { _, newValue in
                        volumeName = selectedSystem.sanitizeVolumeName(newValue)
                    }

                Text("(max \(selectedSystem.maxVolumeNameLength) chars)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            // Disk Format
            HStack {
                Text("Disk Format:")
                    .frame(width: 100, alignment: .trailing)

                Picker("", selection: $selectedFormat) {
                    ForEach(selectedSystem.availableFormats) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)

                Spacer()
            }

            // Disk Size
            HStack {
                Text("Disk Size:")
                    .frame(width: 100, alignment: .trailing)

                Picker("", selection: $selectedSize) {
                    ForEach(selectedSystem.availableSizes) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)

                Text("(\(formatBytes(selectedSize.bytes)))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            // Info about selected images
            if !viewModel.selectedImageIds.isEmpty {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.secondary)
                    Text("\(viewModel.selectedImageIds.count) image(s) will be converted and added to the disk")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            } else if !viewModel.inputImages.isEmpty {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.secondary)
                    Text("\(viewModel.inputImages.count) image(s) will be converted and added to the disk")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
    }

    // MARK: - Button Section

    private var buttonSection: some View {
        HStack {
            Spacer()

            Button("Cancel") {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)

            Button("Create Disk Image") {
                // Use default if volume name is empty
                let finalVolumeName = volumeName.isEmpty ? "DISK" : volumeName
                let config = DiskConfiguration(
                    system: selectedSystem,
                    format: selectedFormat,
                    size: selectedSize,
                    volumeName: finalVolumeName
                )
                onExport(config)
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Helpers

    private func updateForSystem(_ system: DiskSystem) {
        // Update format if current one not available
        if !system.availableFormats.contains(selectedFormat) {
            selectedFormat = system.defaultFormat
        }
        // Update size if current one not available
        if !system.availableSizes.contains(selectedSize) {
            selectedSize = system.defaultSize
        }
        // Sanitize volume name for new system
        volumeName = system.sanitizeVolumeName(volumeName)
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.2f MB", Double(bytes) / 1_000_000)
        } else {
            return String(format: "%.0f KB", Double(bytes) / 1_000)
        }
    }
}

// MARK: - Disk System Button

struct DiskSystemButton: View {
    let system: DiskSystem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(system.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 40)

                Text(system.displayName)
                    .font(.system(size: 8, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 50)
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    CreateDiskSheet(
        isPresented: .constant(true),
        selectedSystemIndex: .constant(8),
        viewModel: ConverterViewModel()
    ) { config in
        print("Export: \(config.system.displayName) \(config.format.displayName) \(config.size.displayName)")
    }
}
