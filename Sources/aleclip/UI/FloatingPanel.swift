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

    public override func cancelOperation(_ sender: Any?) {
        FloatingPanelController.shared.hide()
    }
}

public enum DateFilterOption: String, CaseIterable, Identifiable {
    case allTime = "All Time"
    case today = "Today"
    case yesterday = "Yesterday"
    case pastWeek = "Past 7 Days"
    case pastMonth = "Past 30 Days"

    public var id: String { rawValue }
}

@MainActor
public final class FloatingPanelController: ObservableObject {
    public static let shared = FloatingPanelController()

    @Published public var isVisible: Bool = false
    @Published public var selectedIndex: Int = 0
    @Published public var searchText: String = ""
    @Published public var selectedFilter: FilterTab = .all
    @Published public var selectedCollectionId: UUID? = nil
    @Published public var selectedAppFilter: String? = nil
    @Published public var selectedDateFilter: DateFilterOption = .allTime

    @Published public var previewClip: ClipItem? = nil
    @Published public var editingClip: ClipItem? = nil
    @Published public var renamingClip: ClipItem? = nil
    @Published public var showNewCollectionSheet: Bool = false
    @Published public var showNewClipSheet: Bool = false

    @Published public var multiSelectedIds: Set<UUID> = []
    @Published public var isMultiSelectMode: Bool = false

    @Published public var showShortcutsPopover: Bool = false
    @Published public var toastMessage: String? = nil
    @Published public var toastActionTitle: String? = nil
    @Published public var toastAction: (() -> Void)? = nil

    public var focusSearchTrigger: (() -> Void)?

    public private(set) var previousApp: NSRunningApplication?
    private var panel: FloatingPanel?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var globalClickMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var toastDismissWorkItem: DispatchWorkItem?

    public enum FilterTab: String, CaseIterable, Identifiable {
        case all = "All"
        case pinned = "Pinned"
        case text = "Text"
        case code = "Code"
        case links = "Links"
        case images = "Images"
        case files = "Files"
        case colors = "Colors"
        case deleted = "Deleted"

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .all: return loc("filter.all")
            case .pinned: return loc("filter.pinned")
            case .text: return loc("filter.text")
            case .code: return "Code"
            case .links: return loc("filter.links")
            case .images: return loc("filter.images")
            case .files: return loc("filter.files")
            case .colors: return loc("filter.colors")
            case .deleted: return loc("filter.deleted")
            }
        }

        public var iconName: String {
            switch self {
            case .all: return "square.stack.3d.up"
            case .pinned: return "pin.fill"
            case .text: return "doc.text"
            case .code: return "curlybraces"
            case .links: return "link"
            case .images: return "photo"
            case .files: return "folder"
            case .colors: return "paintpalette"
            case .deleted: return "trash"
            }
        }
    }

    private init() {}

    public func setup() {
        let screen = NSScreen.main
        let screenRect = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let panelHeight: CGFloat = 330
        let panelRect = NSRect(x: screenRect.minX, y: screenRect.minY, width: screenRect.width, height: panelHeight)
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

        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.previousApp = frontmost
        }

        self.searchText = ""
        self.selectedIndex = 0
        self.previewClip = nil
        self.editingClip = nil
        self.renamingClip = nil
        self.showNewCollectionSheet = false
        self.showNewClipSheet = false
        self.multiSelectedIds.removeAll()
        self.isMultiSelectMode = false
        self.showShortcutsPopover = false
        self.toastMessage = nil
        self.toastActionTitle = nil
        self.toastAction = nil

        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let screen = targetScreen {
            let screenRect = screen.visibleFrame
            let panelHeight: CGFloat = 350
            panel.setFrame(NSRect(x: screenRect.minX, y: screenRect.minY, width: screenRect.width, height: panelHeight), display: true)
        }

        panel.alphaValue = 0.0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }

        self.isVisible = true

        startKeyboardMonitoring()
        startDismissMonitoring()
    }

    public func hide() {
        guard let panel = panel, isVisible else { return }

        stopKeyboardMonitoring()
        stopDismissMonitoring()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.panel?.orderOut(nil)
                self.isVisible = false
                self.previewClip = nil
                self.editingClip = nil
                self.renamingClip = nil
                self.showNewCollectionSheet = false
                self.showNewClipSheet = false
            }
        })
    }

    private func startDismissMonitoring() {
        stopDismissMonitoring()

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self = self, self.isVisible, let panel = self.panel else { return }
                let clickLocation = NSEvent.mouseLocation
                if !NSMouseInRect(clickLocation, panel.frame, false) {
                    if self.previewClip == nil && self.editingClip == nil && self.renamingClip == nil &&
                        !self.showNewCollectionSheet && !self.showNewClipSheet {
                        self.hide()
                    }
                }
            }
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isVisible else { return }
                if self.previewClip == nil && self.editingClip == nil && self.renamingClip == nil &&
                    !self.showNewCollectionSheet && !self.showNewClipSheet {
                    self.hide()
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

        // 1. Global Escape key monitor guarantees Escape closes panel even if focus shifted
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            if event.keyCode == 53 /* Escape */ {
                Task { @MainActor [weak self] in
                    self?.hide()
                }
            }
        }

        // 2. Local monitor for all active panel keys
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return event }

            // Priority: Escape ALWAYS dismisses sub-sheets first, or closes the panel immediately
            if event.keyCode == 53 /* Escape */ {
                if self.previewClip != nil {
                    self.previewClip = nil
                    return nil
                }
                if self.editingClip != nil {
                    self.editingClip = nil
                    return nil
                }
                if self.renamingClip != nil {
                    self.renamingClip = nil
                    return nil
                }
                if self.showNewCollectionSheet {
                    self.showNewCollectionSheet = false
                    return nil
                }
                if self.showNewClipSheet {
                    self.showNewClipSheet = false
                    return nil
                }
                self.hide()
                return nil
            }

            if self.previewClip != nil {
                if event.keyCode == 49 /* Space */ {
                    self.previewClip = nil
                    return nil
                }
                return event
            }

            let flags = event.modifierFlags

            // ⇧⌘N : Create new collection
            if flags.contains(.command) && flags.contains(.shift) && event.keyCode == 45 /* 'N' */ {
                self.showNewCollectionSheet = true
                return nil
            }

            // ⌘N : Create new text item
            if flags.contains(.command) && !flags.contains(.shift) && event.keyCode == 45 /* 'N' */ {
                self.showNewClipSheet = true
                return nil
            }

            // ⌘F : Search clipboard
            if flags.contains(.command) && event.keyCode == 3 /* 'F' */ {
                self.focusSearchTrigger?()
                return nil
            }

            // ⌘E : Edit selected item
            if flags.contains(.command) && event.keyCode == 14 /* 'E' */ {
                self.editSelected()
                return nil
            }

            // ⌘R : Rename selected item
            if flags.contains(.command) && event.keyCode == 15 /* 'R' */ {
                self.renameSelected()
                return nil
            }

            // ⌘T : Pause clipboard monitoring
            if flags.contains(.command) && event.keyCode == 17 /* 'T' */ {
                ClipboardMonitor.shared.togglePause()
                let status = ClipboardMonitor.shared.isPaused ? "Monitoring Paused (⌘T)" : "Monitoring Resumed (⌘T)"
                self.showToast(message: status)
                return nil
            }

            // ⌘Z : Undo last deletion
            if flags.contains(.command) && !flags.contains(.shift) && event.keyCode == 6 /* 'Z' */ {
                if self.undoLastDelete() {
                    return nil
                }
            }

            // ⌘1 through ⌘9 Quick Paste
            if flags.contains(.command),
               let chars = event.charactersIgnoringModifiers,
               let firstChar = chars.first,
               let num = Int(String(firstChar)),
               (1...9).contains(num) {
                let index = num - 1
                let items = self.filteredClips()
                if index < items.count {
                    self.selectedIndex = index
                    if self.selectedFilter == .deleted {
                        self.restoreClip(items[index])
                    } else {
                        self.pasteSelected(forcePlainText: flags.contains(.shift))
                    }
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
                if self.selectedFilter == .deleted {
                    let items = self.filteredClips()
                    if self.selectedIndex >= 0 && self.selectedIndex < items.count {
                        self.restoreClip(items[self.selectedIndex])
                        return nil
                    }
                } else if !self.multiSelectedIds.isEmpty {
                    self.pasteMultiSelected(forcePlainText: flags.contains(.shift))
                    return nil
                } else {
                    self.pasteSelected(forcePlainText: flags.contains(.shift))
                    return nil
                }

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

            case 43: // ','
                if flags.contains(.command) {
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
        if let gMonitor = globalKeyMonitor {
            NSEvent.removeMonitor(gMonitor)
            globalKeyMonitor = nil
        }
    }

    public var isSearchFocused: Bool = false

    public func showToast(message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        toastDismissWorkItem?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.toastMessage = message
            self.toastActionTitle = actionTitle
            self.toastAction = action
        }

        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.dismissToast()
            }
        }
        toastDismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: item)
    }

    public func dismissToast() {
        toastDismissWorkItem?.cancel()
        toastDismissWorkItem = nil
        withAnimation(.easeOut(duration: 0.2)) {
            self.toastMessage = nil
            self.toastActionTitle = nil
            self.toastAction = nil
        }
    }

    public func filteredClips() -> [ClipItem] {
        if selectedFilter == .deleted {
            let deleted = StorageService.shared.deletedClips
            return deleted.filter { $0.matches(query: searchText) }
        }

        var list = StorageService.shared.clips

        // Filter by Tab
        switch selectedFilter {
        case .all:
            break
        case .pinned:
            list = list.filter { $0.isPinned }
        case .text:
            list = list.filter { $0.type == .text || $0.type == .richText || $0.type == .html }
        case .code:
            list = list.filter { $0.type == .code || $0.detectedLanguage != nil }
        case .links:
            list = list.filter { $0.type == .link }
        case .images:
            list = list.filter { $0.type == .image }
        case .files:
            list = list.filter { $0.type == .file }
        case .colors:
            list = list.filter { $0.type == .color }
        case .deleted:
            break
        }

        // Filter by Collection
        if let colId = selectedCollectionId {
            list = list.filter { $0.collectionId == colId }
        }

        // Filter by App
        if let app = selectedAppFilter, !app.isEmpty {
            list = list.filter { $0.sourceAppName == app }
        }

        // Filter by Date
        let calendar = Calendar.current
        let now = Date()
        switch selectedDateFilter {
        case .allTime:
            break
        case .today:
            list = list.filter { calendar.isDateInToday($0.createdAt) }
        case .yesterday:
            list = list.filter { calendar.isDateInYesterday($0.createdAt) }
        case .pastWeek:
            if let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now) {
                list = list.filter { $0.createdAt >= oneWeekAgo }
            }
        case .pastMonth:
            if let oneMonthAgo = calendar.date(byAdding: .day, value: -30, to: now) {
                list = list.filter { $0.createdAt >= oneMonthAgo }
            }
        }

        // Search query
        if !searchText.isEmpty {
            list = list.filter { $0.matches(query: searchText) }
        }

        return list
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

    public func pasteMultiSelected(forcePlainText: Bool = false) {
        let items = filteredClips()
        let selected = items.filter { multiSelectedIds.contains($0.id) }
        guard !selected.isEmpty else { return }
        let target = self.previousApp
        hide()
        PasteService.shared.pasteMultipleClips(selected, targetApp: target, delimiter: "\n", forcePlainText: forcePlainText)
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
        deleteClip(toDelete)
    }

    public func deleteClip(_ clip: ClipItem) {
        if selectedFilter == .deleted {
            StorageService.shared.deleteClip(id: clip.id, permanent: true)
            showToast(message: loc("toast.permanentlyDeleted"), actionTitle: nil, action: nil)
        } else {
            let title = clip.displayTitle
            StorageService.shared.deleteClip(id: clip.id, permanent: false)
            showToast(
                message: "\(loc("toast.deleted")): \(title)",
                actionTitle: loc("toast.undo"),
                action: { [weak self] in
                    self?.undoLastDelete()
                }
            )
        }

        let items = filteredClips()
        if selectedIndex >= items.count {
            selectedIndex = max(0, items.count - 1)
        }
    }

    @discardableResult
    public func undoLastDelete() -> Bool {
        if let restored = StorageService.shared.undoLastDelete() {
            showToast(
                message: "\(loc("toast.restored")): \(restored.displayTitle)",
                actionTitle: nil,
                action: nil
            )
            let items = filteredClips()
            if let idx = items.firstIndex(where: { $0.id == restored.id }) {
                selectedIndex = idx
            }
            return true
        }
        return false
    }

    public func restoreClip(_ clip: ClipItem) {
        if let restored = StorageService.shared.restoreClip(id: clip.id) {
            showToast(
                message: "\(loc("toast.restored")): \(restored.displayTitle)",
                actionTitle: nil,
                action: nil
            )
            let items = filteredClips()
            if selectedIndex >= items.count {
                selectedIndex = max(0, items.count - 1)
            }
        }
    }

    public func restoreAllDeleted() {
        let count = StorageService.shared.restoreAllDeleted()
        showToast(message: "\(loc("toast.restored")): \(count) items")
        self.selectedFilter = .all
        self.selectedIndex = 0
    }

    public func editSelected() {
        let items = filteredClips()
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }
        editingClip = items[selectedIndex]
    }

    public func renameSelected() {
        let items = filteredClips()
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }
        renamingClip = items[selectedIndex]
    }
}
