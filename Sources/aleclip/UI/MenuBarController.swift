import Foundation
import AppKit
import SwiftUI

@MainActor
public final class MenuBarController: NSObject, NSMenuDelegate {
    public static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    private override init() {
        super.init()
    }

    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "AleClip") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "📋"
            }
            button.toolTip = "AleClip - Clipboard History (⌥V)"
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }

    public func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        // 1. Toggle Panel Item
        let openItem = NSMenuItem(
            title: "Open Clipboard Panel",
            action: #selector(openPanelAction),
            keyEquivalent: "v"
        )
        openItem.keyEquivalentModifierMask = [.option]
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Recent Clips Header
        let recentHeader = NSMenuItem(title: "Recent Clips", action: nil, keyEquivalent: "")
        recentHeader.isEnabled = false
        menu.addItem(recentHeader)

        let clips = StorageService.shared.clips
        let recentClips = clips.prefix(7)

        if recentClips.isEmpty {
            let emptyItem = NSMenuItem(title: "  (No clips yet)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, clip) in recentClips.enumerated() {
                let title = clip.displayTitle.replacingOccurrences(of: "\n", with: " ")
                let truncated = title.count > 38 ? String(title.prefix(35)) + "..." : title
                let prefix = clip.isPinned ? "📌 " : "  "

                let item = NSMenuItem(
                    title: "\(prefix)\(index + 1). \(truncated)",
                    action: #selector(clipSelectedAction(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = clip
                item.target = self
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // 3. Clear unpinned
        let clearItem = NSMenuItem(
            title: "Clear Unpinned History",
            action: #selector(clearHistoryAction),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)

        // 4. Preferences / Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Quit
        let quitItem = NSMenuItem(
            title: "Quit AleClip",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func openPanelAction() {
        FloatingPanelController.shared.toggle()
    }

    @objc private func clipSelectedAction(_ sender: NSMenuItem) {
        guard let clip = sender.representedObject as? ClipItem else { return }
        PasteService.shared.pasteClip(clip, targetApp: FloatingPanelController.shared.previousApp)
    }

    @objc private func clearHistoryAction() {
        StorageService.shared.clearUnpinned()
    }

    @objc public func openSettingsAction() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 530),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "AleClip Settings"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView())
            self.settingsWindow = window
        }

        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
