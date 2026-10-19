# DesktopVeil — specification

**Tagline:** Hide every desktop icon with one click or hotkey for clean screenshots, recordings and screen sharing.

**Category:** Menu Bar Utility

**Inspired by (paid):** Camouflage ($14.99 one-time)

**Frameworks:** SwiftUI, AppKit, CoreGraphics, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

(1) What the paid app does. Camouflage and its siblings such as Desktop Ghost hide desktop icons from the menu bar on demand. Camouflage's App Store listing shows 14.99 dollars, and cheaper rivals sell around 2 to 4 dollars, so a market clearly exists, driven by streamers, presenters and anyone sharing a screen who wants a tidy desktop. Many people otherwise run a terminal default write command to do this, which shows unmet demand for a clean toggle. Our version provides a reliable toggle plus a few niceties and no system hacks.

(2) Feature set. A single toggle hides or reveals all desktop icons. It is implemented by showing one borderless window per display at the desktop icon window level that displays the current desktop wallpaper, covering the icons without touching the Finder. A global hotkey toggles. An auto-reveal option unhides icons after a chosen time. A mode switch lets the user choose between the wallpaper cover method and the Finder preference method, where the Finder method writes the desktop creation preference and relaunches Finder. A hide-while-screen-sharing option hides icons automatically when a recording app starts, detected by a list of bundle identifiers the user can edit.

(3) UI spec. MenuBarExtra with an icon that changes between a filled and outlined desktop symbol. Menu items: Hide Desktop Icons or Show Desktop Icons depending on state, Auto-reveal submenu with Off, 5 minutes, 15 minutes and 1 hour, Settings and Quit. Settings fields: hotkey recorder, method picker, per-display toggle list, watched apps list with add and remove, and launch at login toggle. The state is also shown in the menu title. Empty state: the watched apps list is empty by default and shows the hint Add apps such as screen recorders. Nothing needs permission in cover mode.

(4) Technical approach. For cover mode create an NSWindow per NSScreen, borderless, with level set to the desktop icon window level via CGWindowLevelForKey for the desktop icon key, collection behavior set to can join all Spaces and stationary, ignoring mouse events false so clicks are absorbed. The content is an NSImageView showing the wallpaper obtained from NSWorkspace desktopImageURL for each screen, with scaling matched to NSWorkspace desktopImageOptions. Observe screen parameter changes and active Space changes to rebuild the covers. Hotkey via Carbon RegisterEventHotKey. Finder method uses UserDefaults with the Finder domain suite name to set CreateDesktop to false and then terminates and reopens Finder through NSRunningApplication and NSWorkspace, and must restore the setting on quit. Watching other apps uses NSWorkspace launch and terminate notifications. Persist settings with AppStorage and launch at login with SMAppService.

(5) Edge cases. Dynamic wallpapers and solid color wallpapers need special handling, so fall back to the fill color from desktopImageOptions when no image URL exists. Wallpapers that change on a schedule should trigger a rebuild when the Space or timer notification fires. If the app crashes in Finder mode, icons stay hidden, so store a flag and offer a first-launch repair prompt. Cover windows must not appear in Mission Control thumbnails as separate windows, so exclude them using the ignores cycle behavior flag. Clicking the cover should not bring the app forward.
