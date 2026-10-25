import Foundation
import os

/// App logging. Debug messages only print in debug builds; errors are kept in
/// release builds and show up in Console.app under the app's bundle identifier.
nonisolated enum Log {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BitPast", category: "BitPast")

    /// Progress and diagnostic output, compiled out of release builds.
    static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        print(message())
        #endif
    }

    /// Failures worth seeing in a user's log (unreadable files, full disks, write errors).
    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        #if DEBUG
        print(message)
        #endif
    }
}
