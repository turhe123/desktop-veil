import SwiftUI

/// The menu shown from the menu bar icon.
struct MenuContentView: View {
    @ObservedObject var veil: VeilController
    @AppStorage(SettingKey.autoRevealMinutes) private var autoRevealMinutes = 0
    @AppStorage(SettingKey.hotKeyDisplay) private var hotKeyDisplay = HotKeyService.defaultDisplay
    @Environment(\.openSettings) private var openSettings

    private let revealChoices: [(String, Int)] = [("Off", 0), ("5 minutes", 5), ("15 minutes", 15), ("1 hour", 60)]

    var body: some View {
        Text(veil.isHidden ? "DesktopVeil — Icons Hidden" : "DesktopVeil — Icons Visible")
        if let date = veil.revealDate {
            Text("Auto-reveal at \(date.formatted(date: .omitted, time: .shortened))")
        }
        Divider()
        Button(veil.isHidden ? "Show Desktop Icons" : "Hide Desktop Icons") { veil.toggle() }
        if !hotKeyDisplay.isEmpty {
            Text("Hotkey: \(hotKeyDisplay)")
        }
        Menu("Auto-reveal") {
            Picker("Auto-reveal", selection: $autoRevealMinutes) {
                ForEach(revealChoices, id: \.1) { Text($0.0).tag($0.1) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .onChange(of: autoRevealMinutes) { veil.scheduleAutoReveal() }
        Divider()
        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",")
        Button("Support / Donate ❤️") {
            NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
        }
        Divider()
        Button("Quit DesktopVeil") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
