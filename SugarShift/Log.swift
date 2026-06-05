import Foundation
import os

/// Lightweight facade over `os.Logger` so diagnostics flow through the unified
/// logging system — privacy-aware, off the hot path, and visible in Console.app
/// — instead of `print`, which also writes to stdout in Release builds.
///
/// The `os` import and privacy annotations stay contained here; callers pass
/// plain Swift strings: `Log.error(.audio, "failed to load \(name)")`.
enum Log {
    enum Category: String {
        case audio, economy, general
    }

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.currenttech.SugarShift"

    private static let loggers: [Category: Logger] = [
        .audio:   Logger(subsystem: subsystem, category: Category.audio.rawValue),
        .economy: Logger(subsystem: subsystem, category: Category.economy.rawValue),
        .general: Logger(subsystem: subsystem, category: Category.general.rawValue)
    ]

    static func error(_ category: Category, _ message: String) {
        loggers[category]?.error("\(message, privacy: .public)")
    }

    static func info(_ category: Category, _ message: String) {
        loggers[category]?.info("\(message, privacy: .public)")
    }
}
