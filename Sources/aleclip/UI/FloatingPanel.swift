import Foundation
import AppKit
import SwiftUI

public class FloatingPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return true
    }
}

@MainActor
public final class FloatingPanelController: ObservableObject {
    public static let shared = FloatingPanelController()

    @Published public var isVisible: Bool = false
    @Published public var selectedIndex: Int = 0
    @Published public var searchText: String = ""
    @Published public var selectedFilter: FilterTab = .all
    @Published public var previewClip: ClipItem? = nil
    @Published public var editingClip: ClipItem? = nil
    @Published public var showShortcutsPopover: Bool = false

    public private(set) var previousApp: NSRunningApplication?
    private var panel: FloatingPanel?
    private var localKeyMonitor: Any?
    private var globalClickMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    public enum FilterTab: String, CaseIterable, Identifiable {
        case all = "All"
        case pinned = "Pinned"
        case text = "Text"
        case links = "Links"
        case images = "Images"
        case files = "Files"
        case colors = "Colors"

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .all: return loc("filter.all")
            case .pinned: return loc("filter.pinned")
            case .text: return loc("filter.text")
            case .links: return loc("filter.links")
            case .images: return loc("filter.images")
            case .files: return loc("filter.files")
            case .colors: return loc("filter.colors")
            }
        }

        public var iconName: String {
            switch self {
            case .all: return "square.stack.3d.up"
            case .pinned: return "pin.fill"
            case .text: return "doc.text"
            case .links: return "link"
            case .images: return "photo"
            case .files: return "folder"
            case .colors: return "paintpalette"
            }
        }
    }

    private init() {}

    public func setup() {
        let panelRect = NSRect(x: 0, y: 0, width: 880, height: 260)
        let panel = FloatingPanel(contentRect: panelRect)

        let hostingView = NSHostingView(rootView: ClipboardBarView())
        panel.contentView = hostingView

        self.panel = panel
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        if panel == nil {
            setup()
        }

        guard let panel = panel else { return }

        // Remember the currently frontmost app before showing panel
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.previousApp = frontmost
        }

        // Reset state
        self.searchText = ""
        self.selectedIndex = 0
        self.previewClip = nil
        self.editingClip = nil
        self.showShortcutsPopover = false

        // Position at bottom center of screen where mouse currently is
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let screen = targetScreen {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - (panel.frame.width / 2.0)
            let y = screenRect.minY + 24 // 24px above dock / bottom edge
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0.0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1.0
        }

        isVisible = true
        startKeyboardMonitoring()
        startDismissMonitoring()
    }

    public func hide() {
        guard let panel = panel, isVisible else { return }

        stopKeyboardMonitoring()
        stopDismissMonitoring()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            DispatchQueue.main.async {
                panel.orderOut(nil)
                self?.isVisible = false
                self?.showShortcutsPopover = false
            }
        })
    }

    // MARK: - Dismiss Monitoring (Outside clicks & app switching)

    private func startDismissMonitoring() {
        stopDismissMonitoring()

        // 1. Outside click monitor (clicks on other apps or desktop)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isVisible else { return }
                self.hide()
            }
        }

        // 2. Resign key notification (app switching via Command-Tab, clicking menubar, etc.)
        if let panel = self.panel {
            resignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: panel,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isVisible else { return }
                    if !self.showShortcutsPopover && self.previewClip == nil && self.editingClip == nil {
                        self.hide()
                    }
                }
            }
        }
    }

    private func stopDismissMonitoring() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let observer = resignObserver {
            NotificationCenter.default.removeObserver(observer)
            resignObserver = nil
        }
    }

    // MARK: - Keyboard Event Monitoring

    private func startKeyboardMonitoring() {
        stopKeyboardMonitoring()

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return event }

            // If an edit sheet or quick look is open, let it handle keys unless Escape is pressed
            if self.previewClip != nil {
                if event.keyCode == 53 /* Escape */ || event.keyCode == 49 /* Space */ {
                    self.previewClip = nil
                    return nil
                }
                return event
            }

            if self.editingClip != nil {
                if event.keyCode == 53 /* Escape */ {
                    self.editingClip = nil
                    return nil
                }
                return event
            }

            // ⌘1 through ⌘9 Quick Paste
            if event.modifierFlags.contains(.command),
               let chars = event.charactersIgnoringModifiers,
               let firstChar = chars.first,
               let num = Int(String(firstChar)),
               (1...9).contains(num) {
                let index = num - 1
                let items = self.filteredClips()
                if index < items.count {
                    self.selectedIndex = index
                    self.pasteSelected(forcePlainText: event.modifierFlags.contains(.shift))
                    return nil
                }
            }

            switch event.keyCode {
            case 53: // Escape
                self.hide()
                return nil

            case 123: // Left Arrow
                self.moveSelection(by: -1)
                return nil

            case 124: // Right Arrow
                self.moveSelection(by: 1)
                return nil

            case 36, 76: // Return / Enter
                self.pasteSelected(forcePlainText: event.modifierFlags.contains(.shift))
                return nil

            case 49: // Space
                if !self.isSearchFocused {
                    self.toggleQuickLook()
                    return nil
                }

            case 51: // Delete / Backspace
                if !self.isSearchFocused {
                    self.deleteSelected()
                    return nil
                }

            case 14: // 'E'
                if event.modifierFlags.contains(.command) {
                    self.editSelected()
                    return nil
                }

            case 43: // ','
                if event.modifierFlags.contains(.command) {
                    self.hide()
                    MenuBarController.shared.openSettingsAction()
                    return nil
                }

            default:
                break
            }

            return event
        }
    }

    private func stopKeyboardMonitoring() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }

    public var isSearchFocused: Bool = false

    public func filteredClips() -> [ClipItem] {
        let allClips = StorageService.shared.clips
        return allClips.filter { clip in
            // Filter by Tab
            switch selectedFilter {
            case .all:
                break
            case .pinned:
                if !clip.isPinned { return false }
            case .text:
                if clip.type != .text && clip.type != .richText && clip.type != .html { return false }
            case .links:
                if clip.type != .link { return false }
            case .images:
                if clip.type != .image { return false }
            case .files:
                if clip.type != .file { return false }
            case .colors:
                if clip.type != .color { return false }
            }

            // Filter by search query
            return clip.matches(query: searchText)
        }
    }

    public func moveSelection(by delta: Int) {
        let items = filteredClips()
        guard !items.isEmpty else {
            selectedIndex = 0
            return
        }
        let newIndex = selectedIndex + delta
        if newIndex >= 0 && newIndex < items.count {
            selectedIndex = newIndex
        }
    }

    public func pasteSelected(forcePlainText: Bool = false) {
        let items = filteredClips()
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }
        let selectedClip = items[selectedIndex]
        let target = self.previousApp
        hide()
        PasteService.shared.pasteClip(selectedClip, targetApp: target, forcePlainText: forcePlainText)
    }

    public func toggleQuickLook() {
        let items = filteredClips()
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }
        previewClip = items[selectedIndex]
    }

    public func deleteSelected() {
        let items = filteredClips()
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }
        let toDelete = items[selectedIndex]
        StorageService.shared.deleteClip(id: toDelete.id)
        if selectedIndex >= filteredClips().count {
            selectedIndex = max(0, filteredClips().count - 1)
        }
    }

    public func editSelected() {
        let items = filteredClips()
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }
        editingClip = items[selectedIndex]
    }
}
