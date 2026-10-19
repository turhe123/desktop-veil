import AppKit
import CoreGraphics

/// Borderless, non-activating panel that sits just above the desktop icons on one display.
final class CoverPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Draws a wallpaper image using the same scaling the system applies, falling back to a fill colour.
final class WallpaperView: NSView {
    var image: NSImage?
    var scaling: NSImageScaling = .scaleProportionallyUpOrDown
    var allowClipping = true
    var fillColor: NSColor = .black

    override func draw(_ dirtyRect: NSRect) {
        fillColor.setFill()
        bounds.fill()
        guard let image, image.size.width > 0, image.size.height > 0 else { return }
        image.draw(in: targetRect(for: image.size), from: .zero, operation: .sourceOver, fraction: 1)
    }

    /// Computes where the image goes for fill, fit, stretch and centre modes.
    private func targetRect(for size: NSSize) -> NSRect {
        let sx = bounds.width / size.width, sy = bounds.height / size.height
        let scale: CGFloat
        switch scaling {
        case .scaleAxesIndependently: return bounds
        case .scaleNone: scale = 1
        case .scaleProportionallyDown: scale = min(1, min(sx, sy))
        default: scale = allowClipping ? max(sx, sy) : min(sx, sy)
        }
        let w = size.width * scale, h = size.height * scale
        return NSRect(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2, width: w, height: h)
    }
}

/// Creates and maintains one wallpaper cover window per enabled display.
@MainActor
final class CoverWindowManager {
    private var windows: [CGDirectDisplayID: CoverPanel] = [:]
    private var observers: [NSObjectProtocol] = []
    private var refreshTimer: Timer?

    var isShowing: Bool { !windows.isEmpty }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    func show() {
        rebuild()
        guard observers.isEmpty else { return }
        let rebuildBlock: (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in self?.rebuild() }
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main, using: rebuildBlock))
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: rebuildBlock))
        // Wallpapers that rotate on a schedule are picked up periodically.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.rebuild() }
        }
    }

    func hide() {
        observers.forEach {
            NotificationCenter.default.removeObserver($0)
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
        observers.removeAll()
        refreshTimer?.invalidate()
        refreshTimer = nil
        windows.values.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    /// Re-creates covers to match the current screens, wallpapers and per-display preferences.
    func rebuild() {
        let excluded = Set(StoredList.read(SettingKey.excludedDisplays))
        var seen = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            guard let id = Self.displayID(of: screen), !excluded.contains(String(id)) else { continue }
            seen.insert(id)
            let panel = windows[id] ?? makePanel()
            windows[id] = panel
            panel.setFrame(screen.frame, display: false)
            configure(panel.contentView as? WallpaperView, for: screen)
            panel.contentView?.needsDisplay = true
            panel.orderFront(nil)
        }
        for (id, panel) in windows where !seen.contains(id) {
            panel.orderOut(nil)
            windows[id] = nil
        }
    }

    private func makePanel() -> CoverPanel {
        let panel = CoverPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false)
        // One level above the desktop icons, still below every normal window.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = true
        panel.animationBehavior = .none
        panel.contentView = WallpaperView()
        return panel
    }

    private func configure(_ view: WallpaperView?, for screen: NSScreen) {
        guard let view else { return }
        let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
        if let raw = options[.imageScaling] as? NSNumber, let scaling = NSImageScaling(rawValue: raw.uintValue) {
            view.scaling = scaling
        }
        view.allowClipping = (options[.allowClipping] as? NSNumber)?.boolValue ?? true
        view.fillColor = (options[.fillColor] as? NSColor) ?? .black
        // Solid colours and some dynamic wallpapers have no loadable image; the fill colour is used then.
        if let url = NSWorkspace.shared.desktopImageURL(for: screen), !url.hasDirectoryPath {
            view.image = NSImage(contentsOf: url)
        } else {
            view.image = nil
        }
    }
}
