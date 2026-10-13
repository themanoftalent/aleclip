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

    public func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme?.lowercased() == "aleclip" else { continue }
            switch url.host?.lowercased() {
            case "toggle":
                FloatingPanelController.shared.toggle()
            case "show":
                FloatingPanelController.shared.show()
            case "settings":
                MenuBarController.shared.openSettingsAction()
            case "about":
                MenuBarController.shared.openAboutAction()
            default:
                FloatingPanelController.shared.toggle()
            }
        }
    }
}
