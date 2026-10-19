import AppKit

/// Hides icons by turning off Finder's `CreateDesktop` preference and relaunching Finder.
enum FinderDesktopService {
    private static let finderID = "com.apple.finder"
    private static let key = "CreateDesktop"

    /// Writes the preference and records a crash-recovery flag while icons are hidden this way.
    static func setIconsHidden(_ hidden: Bool, waitForRelaunch: Bool = false) {
        guard let finderDefaults = UserDefaults(suiteName: finderID) else { return }
        if hidden {
            finderDefaults.set(false, forKey: key)
        } else {
            finderDefaults.removeObject(forKey: key)
        }
        finderDefaults.synchronize()
        UserDefaults.standard.set(hidden, forKey: SettingKey.finderHiddenFlag)

        if waitForRelaunch {
            relaunchFinder()
        } else {
            DispatchQueue.global(qos: .userInitiated).async { relaunchFinder() }
        }
    }

    /// Quits Finder (forcing it if needed) and reopens it so the preference takes effect.
    private static func relaunchFinder() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: finderID)
        running.forEach { $0.terminate() }
        if !waitUntil(timeout: 2, { running.allSatisfy(\.isTerminated) }) {
            running.forEach { $0.forceTerminate() }
            _ = waitUntil(timeout: 2) { running.allSatisfy(\.isTerminated) }
        }
        // launchd often restarts Finder by itself; only open it if it has not come back.
        if waitUntil(timeout: 1.5, { !NSRunningApplication.runningApplications(withBundleIdentifier: finderID).isEmpty }) {
            return
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: finderID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error { NSLog("DesktopVeil: could not relaunch Finder: \(error.localizedDescription)") }
        }
    }

    private static func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
    }
}
