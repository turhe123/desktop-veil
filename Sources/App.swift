import SwiftUI
import AppKit

/// App entry point: a menu bar extra plus a Settings window.
@main
struct DesktopVeilApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var veil = VeilController.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(veil: veil)
        } label: {
            Image(systemName: veil.isHidden ? "rectangle.fill" : "menubar.rectangle")
                .accessibilityLabel(veil.isHidden ? "Desktop icons hidden" : "Desktop icons visible")
        }
        Settings {
            SettingsView(veil: veil)
        }
    }
}

/// Handles launch-time recovery for Finder mode and restores icons when the app quits.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            VeilController.shared.start()
            offerRepairIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { VeilController.shared.restoreForQuit() }
    }

    /// If a previous session hid icons through Finder and never restored them, offer to fix it.
    @MainActor
    private func offerRepairIfNeeded() {
        guard UserDefaults.standard.bool(forKey: SettingKey.finderHiddenFlag) else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Desktop icons may still be hidden"
        alert.informativeText = "DesktopVeil did not quit cleanly while using the Finder method. "
            + "Restore your desktop icons now? Finder will relaunch."
        alert.addButton(withTitle: "Restore Icons")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn {
            FinderDesktopService.setIconsHidden(false)
        }
    }
}
