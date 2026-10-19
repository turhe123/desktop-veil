import Foundation

/// Central list of persisted setting keys and defaults shared by `@AppStorage` and services.
enum SettingKey {
    static let method = "hideMethod"
    static let autoRevealMinutes = "autoRevealMinutes"
    static let excludedDisplays = "excludedDisplayIDs"
    static let watchedApps = "watchedBundleIDs"
    static let hideWhileSharing = "hideWhileSharing"
    static let hotKeyCode = "hotKeyCode"
    static let hotKeyModifiers = "hotKeyModifiers"
    static let hotKeyDisplay = "hotKeyDisplay"
    static let finderHiddenFlag = "finderHiddenByDesktopVeil"
}

/// The technique used to hide desktop icons.
enum HideMethod: String, CaseIterable, Identifiable {
    case cover
    case finder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cover: return "Wallpaper cover (recommended)"
        case .finder: return "Finder preference (relaunches Finder)"
        }
    }
}

/// Helpers for list-valued settings that are stored as newline-separated strings.
enum StoredList {
    static func decode(_ raw: String) -> [String] {
        raw.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func encode(_ items: [String]) -> String {
        items.joined(separator: "\n")
    }

    static func read(_ key: String) -> [String] {
        decode(UserDefaults.standard.string(forKey: key) ?? "")
    }
}
