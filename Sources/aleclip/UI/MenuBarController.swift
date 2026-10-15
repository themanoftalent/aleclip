import Foundation
import AppKit
import SwiftUI

@MainActor
public final class MenuBarController: NSObject, NSMenuDelegate {
    public static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?

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

        // 1. About AleClip
        let aboutItem = NSMenuItem(
            title: loc("menu.about"),
            action: #selector(openAboutAction),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        // 2. Check for Updates...
        let updateItem = NSMenuItem(
            title: loc("menu.updates"),
            action: #selector(checkForUpdatesAction),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Toggle Panel Item
        let openItem = NSMenuItem(
            title: loc("menu.openPanel"),
            action: #selector(openPanelAction),
            keyEquivalent: "v"
        )
        openItem.keyEquivalentModifierMask = [.option]
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Recent Clips Header
        let recentHeader = NSMenuItem(title: loc("menu.recentClips"), action: nil, keyEquivalent: "")
        recentHeader.isEnabled = false
        menu.addItem(recentHeader)

        let clips = StorageService.shared.clips
        let recentClips = clips.prefix(7)

        if recentClips.isEmpty {
            let emptyItem = NSMenuItem(title: loc("menu.noClips"), action: nil, keyEquivalent: "")
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

        // 5. Clear unpinned
        let clearItem = NSMenuItem(
            title: loc("menu.clearUnpinned"),
            action: #selector(clearHistoryAction),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)

        // 6. Preferences / Settings
        let settingsItem = NSMenuItem(
            title: loc("menu.settings"),
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // 7. Quit
        let quitItem = NSMenuItem(
            title: loc("menu.quit"),
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

    @objc public func openAboutAction() {
        if aboutWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 472, height: 490),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = loc("about.title")
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: AboutView())
            self.aboutWindow = window
        } else {
            aboutWindow?.title = loc("about.title")
            aboutWindow?.setContentSize(NSSize(width: 472, height: 490))
            aboutWindow?.contentView = NSHostingView(rootView: AboutView())
        }

        aboutWindow?.center()
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc public func checkForUpdatesAction() {
        // TODO: Switch to a real Sparkle feed when ready:
        // 1. Generate your own EdDSA public/private keypair using Sparkle's `bin/generate_keys`.
        // 2. Add `SUPublicEDKey` (<your-ed25519-public-key>) and `SUFeedURL` (e.g. https://github.com/themanoftalent/aleclip/releases/latest/download/appcast.xml) to Info.plist.
        // 3. Integrate Sparkle.framework / SPM package `Sparkle` and call `SPUStandardUpdaterController.shared.checkForUpdates(nil)`.
        // 4. Set `SUEnableAutomaticChecks` back to YES.
        // For now, open user releases page in default web browser to prevent updating from the upstream feed:
        if let url = URL(string: "https://github.com/themanoftalent/aleclip/releases") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc public func openSettingsAction() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 530),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = loc("settings.title")
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView())
            self.settingsWindow = window
        } else {
            settingsWindow?.title = loc("settings.title")
        }

        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
