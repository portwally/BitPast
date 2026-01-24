
import SwiftUI

@main
struct BitPastApp: App {

    init() {
        cleanupTempFolder()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    /// Cleans up the app's temp folder on launch
    private func cleanupTempFolder() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileManager = FileManager.default

        do {
            let tempFiles = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            var cleanedCount = 0

            for fileURL in tempFiles {
                try? fileManager.removeItem(at: fileURL)
                cleanedCount += 1
            }

            if cleanedCount > 0 {
                print("Cleaned up \(cleanedCount) temporary file(s)")
            }
        } catch {
            // Silently ignore errors - temp cleanup is not critical
        }
    }
}
