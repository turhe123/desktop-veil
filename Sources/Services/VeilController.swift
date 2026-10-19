import AppKit

/// Owns the hidden/visible state and coordinates the hiding method, auto-reveal and watched apps.
@MainActor
final class VeilController: ObservableObject {
    static let shared = VeilController()

    @Published private(set) var isHidden = false
    @Published private(set) var revealDate: Date?

    private let covers = CoverWindowManager()
    private var activeMethod: HideMethod?
    private var revealTimer: Timer?
    /// True when icons were hidden automatically because a watched app launched.
    private var hiddenByWatcher = false
    private var workspaceObservers: [NSObjectProtocol] = []

    private init() {}

    var method: HideMethod {
        HideMethod(rawValue: UserDefaults.standard.string(forKey: SettingKey.method) ?? "") ?? .cover
    }

    func start() {
        HotKeyService.shared.onTrigger = { [weak self] in self?.toggle() }
        HotKeyService.shared.registerFromDefaults()
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                                                     object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.evaluateWatchedApps() }
        })
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                                                     object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.evaluateWatchedApps() }
        })
        evaluateWatchedApps()
    }

    func toggle() {
        isHidden ? reveal() : hide()
    }

    func hide(automatic: Bool = false) {
        guard !isHidden else { return }
        let method = self.method
        switch method {
        case .cover: covers.show()
        case .finder: FinderDesktopService.setIconsHidden(true)
        }
        activeMethod = method
        hiddenByWatcher = automatic
        isHidden = true
        if !automatic { scheduleAutoReveal() }
    }

    func reveal() {
        guard isHidden else { return }
        switch activeMethod ?? method {
        case .cover: covers.hide()
        case .finder: FinderDesktopService.setIconsHidden(false)
        }
        activeMethod = nil
        hiddenByWatcher = false
        isHidden = false
        cancelAutoReveal()
    }

    /// Restarts the auto-reveal countdown using the stored duration (0 = off).
    func scheduleAutoReveal() {
        cancelAutoReveal()
        let minutes = UserDefaults.standard.integer(forKey: SettingKey.autoRevealMinutes)
        guard isHidden, minutes > 0 else { return }
        let interval = TimeInterval(minutes * 60)
        revealDate = Date().addingTimeInterval(interval)
        revealTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.reveal() }
        }
    }

    private func cancelAutoReveal() {
        revealTimer?.invalidate()
        revealTimer = nil
        revealDate = nil
    }

    func refreshCovers() {
        if isHidden, activeMethod == .cover { covers.rebuild() }
    }

    /// Hides while any watched app runs, and reveals again when the last one quits.
    func evaluateWatchedApps() {
        guard UserDefaults.standard.bool(forKey: SettingKey.hideWhileSharing) else { return }
        let watched = Set(StoredList.read(SettingKey.watchedApps))
        let anyRunning = NSWorkspace.shared.runningApplications.contains {
            guard let id = $0.bundleIdentifier else { return false }
            return watched.contains(id) && !$0.isTerminated
        }
        if anyRunning, !isHidden {
            hide(automatic: true)
        } else if !anyRunning, isHidden, hiddenByWatcher {
            reveal()
        }
    }

    /// Called on quit so Finder mode never leaves icons hidden.
    func restoreForQuit() {
        covers.hide()
        if activeMethod == .finder || UserDefaults.standard.bool(forKey: SettingKey.finderHiddenFlag) {
            FinderDesktopService.setIconsHidden(false, waitForRelaunch: true)
        }
    }
}
