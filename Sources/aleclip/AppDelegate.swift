import Foundation
import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as an accessory app (menu bar agent, no Dock clutter)
        NSApp.setActivationPolicy(.accessory)

        // Initialize UI components
        FloatingPanelController.shared.setup()
        MenuBarController.shared.setup()

        // Configure Global Hotkey
        HotkeyManager.shared.onHotkeyPressed = {
            FloatingPanelController.shared.toggle()
        }
        HotkeyManager.shared.applyConfiguredHotkey()

        // Start background clipboard polling
        ClipboardMonitor.shared.start()

        print("AleClip: Application launched and monitoring clipboard.")
    }

    public func applicationWillTerminate(_ notification: Notification) {
        ClipboardMonitor.shared.stop()
        HotkeyManager.shared.unregisterHotkey()
        StorageService.shared.saveHistory()
        print("AleClip: Application terminated safely.")
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        FloatingPanelController.shared.show()
        return true
    }
}
