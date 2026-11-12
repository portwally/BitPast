import AppKit
import Combine

/// The pictures opened most recently, newest first, for File ▸ Open Recent.
///
/// The app is sandboxed, so a path alone cannot be opened again after a relaunch.
/// Each entry keeps a security-scoped bookmark, made while the app still has access
/// (from the open panel or a drop), and opening an entry goes through that bookmark.
@MainActor
final class RecentFiles: ObservableObject {
    static let shared = RecentFiles()
    static let limit = 10
    private static let key = "recentFiles"

    struct Entry: Identifiable, Codable, Equatable {
        let path: String
        let bookmark: Data
        var id: String { path }
        var name: String { (path as NSString).lastPathComponent }
    }

    @Published private(set) var entries: [Entry] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = Array(saved.prefix(Self.limit))
        }
    }

    /// Puts a file at the top of the list. Call it while the app can read the file.
    func add(_ url: URL) {
        let url = url.standardizedFileURL
        guard let bookmark = (try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil))
                ?? (try? url.bookmarkData()) else { return }
        entries.removeAll { $0.path == url.path }
        entries.insert(Entry(path: url.path, bookmark: bookmark), at: 0)
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
        save()
    }

    /// Opens an entry's file: `body` runs while the app has access to it.
    /// Returns false, and drops the entry, when the file can no longer be found.
    @discardableResult
    func open(_ entry: Entry, _ body: (URL) -> Void) -> Bool {
        var stale = false
        let url = (try? URL(resolvingBookmarkData: entry.bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale))
            ?? (try? URL(resolvingBookmarkData: entry.bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale))
        guard let url, FileManager.default.fileExists(atPath: url.path) else {
            entries.removeAll { $0 == entry }
            save()
            return false
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        body(url)
        if stale { add(url) }
        return true
    }

    func clear() {
        entries = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: Self.key) }
    }
}
