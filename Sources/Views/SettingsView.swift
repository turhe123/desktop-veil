import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

/// Settings window: hotkey, method, displays, watched apps and launch at login.
struct SettingsView: View {
    @ObservedObject var veil: VeilController
    @AppStorage(SettingKey.method) private var method = HideMethod.cover.rawValue
    @AppStorage(SettingKey.excludedDisplays) private var excludedRaw = ""
    @AppStorage(SettingKey.watchedApps) private var watchedRaw = ""
    @AppStorage(SettingKey.hideWhileSharing) private var hideWhileSharing = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var newBundleID = ""
    @State private var selectedApp: String?
    @State private var screens = NSScreen.screens

    var body: some View {
        Form {
            Section("Shortcut") {
                LabeledContent("Toggle hotkey") { HotKeyRecorder() }
            }
            Section("Method") {
                Picker("Hide icons using", selection: $method) {
                    ForEach(HideMethod.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .disabled(veil.isHidden)
                Text(veil.isHidden ? "Show icons before changing the method."
                     : "The cover method needs no permissions. The Finder method relaunches Finder each time.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Displays") {
                ForEach(screens, id: \.self) { screen in
                    if let id = CoverWindowManager.displayID(of: screen) {
                        Toggle(screen.localizedName, isOn: displayBinding(String(id)))
                    }
                }
                Text("Applies to the wallpaper cover method.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Screen sharing") {
                Toggle("Hide icons while a watched app is running", isOn: $hideWhileSharing)
                    .onChange(of: hideWhileSharing) { veil.evaluateWatchedApps() }
                watchedAppsList
            }
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { setLaunchAtLogin(launchAtLogin) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Button("Support / Donate ❤️") {
                    NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 600)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = NSScreen.screens
        }
    }

    private var watchedApps: [String] { StoredList.decode(watchedRaw) }

    @ViewBuilder private var watchedAppsList: some View {
        if watchedApps.isEmpty {
            Text("Add apps such as screen recorders.").foregroundStyle(.secondary)
        } else {
            List(watchedApps, id: \.self, selection: $selectedApp) { id in
                Text(appName(for: id)).tag(id)
            }
            .frame(minHeight: 80)
        }
        HStack {
            TextField("Bundle ID, e.g. us.zoom.xos", text: $newBundleID)
                .onSubmit { addWatched(newBundleID) }
            Button("Add") { addWatched(newBundleID) }
                .disabled(newBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Choose App…", action: chooseApp)
            Button("Remove") {
                if let selectedApp { watchedRaw = StoredList.encode(watchedApps.filter { $0 != selectedApp }) }
                selectedApp = nil
            }
            .disabled(selectedApp == nil)
        }
    }

    private func appName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return "\(FileManager.default.displayName(atPath: url.path)) (\(bundleID))"
    }

    private func addWatched(_ raw: String) {
        let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !watchedApps.contains(id) else { return }
        watchedRaw = StoredList.encode(watchedApps + [id])
        newBundleID = ""
        veil.evaluateWatchedApps()
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }.forEach(addWatched)
    }

    private func displayBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !StoredList.decode(excludedRaw).contains(id) },
            set: { enabled in
                var excluded = StoredList.decode(excludedRaw).filter { $0 != id }
                if !enabled { excluded.append(id) }
                excludedRaw = StoredList.encode(excluded)
                veil.refreshCovers()
            })
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Could not update login item: \(error.localizedDescription). "
                + "You can manage it in System Settings › General › Login Items."
        }
    }
}

/// Click-to-record control that captures a key combination and registers it as the global hotkey.
struct HotKeyRecorder: View {
    @AppStorage(SettingKey.hotKeyDisplay) private var display = HotKeyService.defaultDisplay
    @AppStorage(SettingKey.hotKeyCode) private var keyCode = HotKeyService.defaultKeyCode
    @AppStorage(SettingKey.hotKeyModifiers) private var modifiers = HotKeyService.defaultModifiers
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Button(recording ? "Press shortcut…" : (display.isEmpty ? "Record Shortcut" : display)) {
                recording ? stop() : start()
            }
            .frame(minWidth: 130)
            if !display.isEmpty && !recording {
                Button("Clear") {
                    display = ""
                    keyCode = -1
                    HotKeyService.shared.unregister()
                }
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        HotKeyService.shared.unregister()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(0x35) { // Escape cancels
                stop()
                return nil
            }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !flags.subtracting(.shift).isEmpty else { NSSound.beep(); return nil }
            keyCode = Int(event.keyCode)
            modifiers = HotKeyService.carbonModifiers(from: flags)
            display = HotKeyService.displayString(flags: flags, key: event.charactersIgnoringModifiers ?? "?")
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { HotKeyService.shared.registerFromDefaults() }
        recording = false
    }
}
