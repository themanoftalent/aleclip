import SwiftUI
import AppKit

// MARK: - Colorful Logo Watermark View

public struct WatermarkView: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    private var spectrumGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.00, green: 0.88, blue: 1.00),
                Color(red: 0.05, green: 0.52, blue: 1.00),
                Color(red: 0.00, green: 0.90, blue: 0.65),
                Color(red: 0.12, green: 0.82, blue: 0.38),
                Color(red: 0.64, green: 0.90, blue: 0.10),
                Color(red: 1.00, green: 0.78, blue: 0.00),
                Color(red: 1.00, green: 0.44, blue: 0.00)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    public var body: some View {
        let isDark = colorScheme == .dark
        let textOpacity = isDark ? 0.65 : 0.52
        let glowOpacity = isDark ? 0.38 : 0.22

        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(spectrumGradient)
                    .frame(width: 58, height: 58)
                    .blur(radius: 16)
                    .opacity(glowOpacity)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.00, green: 0.88, blue: 1.00).opacity(isDark ? 0.24 : 0.15),
                                Color(red: 1.00, green: 0.44, blue: 0.00).opacity(isDark ? 0.24 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(spectrumGradient, lineWidth: 2)
                            .opacity(textOpacity + 0.25)
                    )

                Image(systemName: "paperclip")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(spectrumGradient)
                    .rotationEffect(.degrees(-45))
                    .opacity(textOpacity + 0.3)
            }

            VStack(alignment: .leading, spacing: -2) {
                ZStack(alignment: .leading) {
                    Text("ALE")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(spectrumGradient)
                        .blur(radius: 14)
                        .opacity(glowOpacity)

                    Text("ALE")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(spectrumGradient)
                        .opacity(textOpacity + 0.35)
                }

                HStack(spacing: 6) {
                    Text("CLIP")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(3.5)
                        .foregroundStyle(spectrumGradient)
                        .opacity(textOpacity + 0.25)

                    Capsule()
                        .fill(spectrumGradient)
                        .frame(width: 26, height: 2.5)
                        .opacity(textOpacity + 0.25)
                }
                .padding(.leading, 2)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

public struct ClipboardBarView: View {
    @ObservedObject private var controller = FloatingPanelController.shared
    @ObservedObject private var storage = StorageService.shared
    @ObservedObject private var monitor = ClipboardMonitor.shared
    @ObservedObject private var privacy = ScreenPrivacyService.shared
    @ObservedObject private var seqQueue = SequentialPasteService.shared

    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init() {}

    public var body: some View {
        let items = controller.filteredClips()

        ZStack {
            // Main Panel Content
            VStack(spacing: 8) {
                // Header Bar: Search, Filters & Controls
                headerBar(itemsCount: items.count)
                    .padding(.top, 4)

                // Status Strip (if queue, privacy shield, or paused is active)
                statusNotificationStrip

                // Middle: Horizontal Card Deck
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            if items.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, clip in
                                    ClipCardView(
                                        clip: clip,
                                        shortcutNumber: controller.selectedFilter == .deleted ? nil : (index < 9 ? (index + 1) : nil),
                                        isSelected: index == controller.selectedIndex,
                                        isMultiSelected: controller.multiSelectedIds.contains(clip.id),
                                        isDeleted: controller.selectedFilter == .deleted,
                                        onSelect: {
                                            controller.selectedIndex = index
                                        },
                                        onToggleMultiSelect: {
                                            if controller.multiSelectedIds.contains(clip.id) {
                                                controller.multiSelectedIds.remove(clip.id)
                                            } else {
                                                controller.multiSelectedIds.insert(clip.id)
                                            }
                                        },
                                        onPaste: {
                                            if controller.selectedFilter == .deleted {
                                                controller.restoreClip(clip)
                                            } else {
                                                controller.selectedIndex = index
                                                controller.pasteSelected()
                                            }
                                        },
                                        onTogglePin: {
                                            if controller.selectedFilter != .deleted {
                                                storage.togglePin(for: clip.id)
                                            }
                                        },
                                        onDelete: {
                                            controller.deleteClip(clip)
                                        },
                                        onRestore: {
                                            controller.restoreClip(clip)
                                        },
                                        onQuickLook: {
                                            controller.selectedIndex = index
                                            controller.toggleQuickLook()
                                        },
                                        onEdit: {
                                            controller.selectedIndex = index
                                            controller.editSelected()
                                        },
                                        onRename: {
                                            controller.selectedIndex = index
                                            controller.renameSelected()
                                        }
                                    )
                                    .id(clip.id)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                    .onChange(of: controller.selectedIndex) { _, newIndex in
                        if newIndex >= 0 && newIndex < items.count {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(items[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
                .frame(height: 145)

                // Footer Bar: Keyboard shortcuts info & Multi-Select banner
                footerBar(itemsCount: items.count)
                    .padding(.bottom, 4)
            }
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(reduceTransparency ? Color(nsColor: .windowBackgroundColor) : Color(nsColor: .windowBackgroundColor).opacity(0.85))
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                    watermarkLayer(itemsCount: items.count)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        Color.primary.opacity(colorSchemeContrast == .increased ? 0.35 : (colorScheme == .dark ? 0.20 : 0.12)),
                        lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                    )
            )

            // Floating Toast Notification Banner
            if let message = controller.toastMessage {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: controller.toastActionTitle != nil ? "arrow.counterclockwise.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 13, weight: .semibold))

                        Text(message)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if let actionTitle = controller.toastActionTitle, let action = controller.toastAction {
                            Button(action: action) {
                                Text(actionTitle)
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.accentColor))
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: { controller.dismissToast() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: 8, x: 0, y: 3)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.top, 6)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(200)
            }

            // Quick Look Overlay
            if let previewClip = controller.previewClip {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        controller.previewClip = nil
                    }

                QuickLookOverlay(
                    clip: previewClip,
                    onDismiss: {
                        controller.previewClip = nil
                    },
                    onPaste: {
                        controller.previewClip = nil
                        controller.pasteSelected()
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(300)
            }

            // Edit Sheet Overlay
            if let editingClip = controller.editingClip {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        controller.editingClip = nil
                    }

                EditClipSheet(
                    clip: editingClip,
                    onSave: { newTitle, newText in
                        storage.renameClip(id: editingClip.id, newTitle: newTitle)
                        storage.updatePlainText(id: editingClip.id, newText: newText)
                        controller.editingClip = nil
                    },
                    onCancel: {
                        controller.editingClip = nil
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(310)
            }

            // Rename Sheet Overlay
            if let renamingClip = controller.renamingClip {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        controller.renamingClip = nil
                    }

                RenameClipSheet(
                    clip: renamingClip,
                    onSave: { newTitle in
                        storage.renameClip(id: renamingClip.id, newTitle: newTitle)
                        controller.renamingClip = nil
                    },
                    onCancel: {
                        controller.renamingClip = nil
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(320)
            }

            // New Collection Sheet Overlay
            if controller.showNewCollectionSheet {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        controller.showNewCollectionSheet = false
                    }

                NewCollectionSheet(
                    onSave: { name, icon, color in
                        let col = ClipCollection(name: name, icon: icon, color: color)
                        storage.addCollection(col)
                        controller.selectedCollectionId = col.id
                        controller.showNewCollectionSheet = false
                        controller.showToast(message: "Created collection: \(name)")
                    },
                    onCancel: {
                        controller.showNewCollectionSheet = false
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(330)
            }

            // New Clip Sheet Overlay
            if controller.showNewClipSheet {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        controller.showNewClipSheet = false
                    }

                NewClipSheet(
                    onSave: { title, content in
                        let detected = ContentDetector.shared.analyzeText(content)
                        let newClip = ClipItem(
                            type: detected.detectedType,
                            plainText: content,
                            title: title.isEmpty ? nil : title,
                            sourceAppName: "AleClip",
                            contentHash: UUID().uuidString,
                            detectedLanguage: detected.detectedLanguage,
                            isSensitive: detected.isSensitive
                        )
                        storage.addClip(newClip)
                        controller.showNewClipSheet = false
                        controller.showToast(message: "Created new item")
                    },
                    onCancel: {
                        controller.showNewClipSheet = false
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(340)
            }
        }
        .frame(width: 920, height: 280)
        .onAppear {
            controller.focusSearchTrigger = {
                isSearchFieldFocused = true
            }
        }
    }

    // MARK: - Watermark Layer

    @ViewBuilder
    private func watermarkLayer(itemsCount: Int) -> some View {
        GeometryReader { geo in
            let cardsWidth = CGFloat(itemsCount) * (200 + 12) + 32
            let remainingWidth = geo.size.width - cardsWidth

            ZStack {
                if itemsCount == 0 {
                    EmptyView()
                } else if remainingWidth > 200 {
                    HStack(spacing: 0) {
                        Spacer().frame(width: cardsWidth)
                        WatermarkView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                } else {
                    WatermarkView()
                        .opacity(0.35)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Header Bar

    private func headerBar(itemsCount: Int) -> some View {
        HStack(spacing: 10) {
            // Search field (Command + F)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))

                TextField(loc("panel.searchPlaceholder"), text: $controller.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFieldFocused)
                    .onChange(of: isSearchFieldFocused) { _, focused in
                        controller.isSearchFocused = focused
                    }

                if !controller.searchText.isEmpty {
                    Button(action: { controller.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
            )
            .frame(width: 190)

            // Filter Tabs
            HStack(spacing: 3) {
                ForEach(FloatingPanelController.FilterTab.allCases) { tab in
                    Button(action: {
                        controller.selectedFilter = tab
                        controller.selectedIndex = 0
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 10))
                            Text(tab.title)
                                .font(.system(size: 10.5, weight: controller.selectedFilter == tab ? .semibold : .regular))
                            if tab == .deleted && storage.deletedClips.count > 0 {
                                Text("\(storage.deletedClips.count)")
                                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 0.5)
                                    .background(Capsule().fill(controller.selectedFilter == tab ? Color.accentColor : Color.primary.opacity(0.12)))
                                    .foregroundColor(controller.selectedFilter == tab ? .white : .secondary)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .foregroundColor(controller.selectedFilter == tab ? .primary : .secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(controller.selectedFilter == tab ? Color(nsColor: .selectedControlColor).opacity(0.4) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Date Filter Menu
            Menu {
                ForEach(DateFilterOption.allCases) { opt in
                    Button(opt.rawValue) {
                        controller.selectedDateFilter = opt
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(controller.selectedDateFilter == .allTime ? "Date" : controller.selectedDateFilter.rawValue)
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.06)))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Collections Menu
            Menu {
                Button("All Items") {
                    controller.selectedCollectionId = nil
                }
                Divider()
                ForEach(storage.collections) { col in
                    Button(col.name) {
                        controller.selectedCollectionId = col.id
                    }
                }
                Divider()
                Button("Create Collection… (⇧⌘N)") {
                    controller.showNewCollectionSheet = true
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                    Text(currentCollectionTitle)
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.06)))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Screen Shield toggle (Feature 15)
            Button(action: {
                privacy.toggleShield()
            }) {
                Image(systemName: privacy.isShieldActive ? "eye.slash.fill" : "eye")
                    .font(.system(size: 11))
                    .foregroundColor(privacy.isShieldActive ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .help(privacy.isShieldActive ? "Screen Privacy Active (Blurring content)" : "Toggle Screen Privacy")

            // Pause Monitoring toggle (Feature 14 & ⌘T)
            Button(action: {
                monitor.togglePause()
                let status = monitor.isPaused ? "Monitoring Paused (⌘T)" : "Monitoring Resumed (⌘T)"
                controller.showToast(message: status)
            }) {
                Image(systemName: monitor.isPaused ? "pause.circle.fill" : "play.circle")
                    .font(.system(size: 11))
                    .foregroundColor(monitor.isPaused ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .help(monitor.isPaused ? "Monitoring Paused (Click or ⌘T to resume)" : "Pause Monitoring (⌘T)")

            // New Clip button (Command + N)
            Button(action: {
                controller.showNewClipSheet = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("New Text Item (⌘N)")

            // Settings button
            Button(action: {
                controller.hide()
                MenuBarController.shared.openSettingsAction()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(loc("menu.settings"))
        }
        .padding(.horizontal, 16)
    }

    private var currentCollectionTitle: String {
        if let id = controller.selectedCollectionId,
           let col = storage.collections.first(where: { $0.id == id }) {
            return col.name
        }
        return "Collections"
    }

    // MARK: - Status Strip

    @ViewBuilder
    private var statusNotificationStrip: some View {
        if monitor.isPaused || privacy.isShieldActive || seqQueue.isQueueActive {
            HStack(spacing: 8) {
                if monitor.isPaused {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 8))
                        Text("Monitoring Paused (⌘T)")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red.opacity(0.2)))
                    .foregroundColor(.red)
                }

                if privacy.isShieldActive {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 8))
                        Text("Screen Privacy Active")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange.opacity(0.2)))
                    .foregroundColor(.orange)
                }

                if seqQueue.isQueueActive {
                    HStack(spacing: 4) {
                        Image(systemName: "list.number")
                            .font(.system(size: 8))
                        Text(seqQueue.queueStatusDescription)
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.blue.opacity(0.2)))
                    .foregroundColor(.blue)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, -2)
        }
    }

    // MARK: - Footer Bar

    private func footerBar(itemsCount: Int) -> some View {
        HStack {
            if !controller.multiSelectedIds.isEmpty {
                HStack(spacing: 6) {
                    Text("\(controller.multiSelectedIds.count) selected")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.accentColor)

                    Button("Paste Combined (↵)") {
                        controller.pasteMultiSelected()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)

                    Button("Clear") {
                        controller.multiSelectedIds.removeAll()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
            } else {
                Text("\(itemsCount) \(loc(itemsCount == 1 ? "footer.clip" : "footer.clips"))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                keyTip(key: "⌘F", desc: "Search")
                keyTip(key: "⌘E", desc: "Edit")
                keyTip(key: "⌘R", desc: "Rename")
                keyTip(key: "⇧⌘N", desc: "Collection")
                keyTip(key: "⌘N", desc: "New")
                keyTip(key: "⌘T", desc: "Pause")
                keyTip(key: "Space", desc: "Preview")
                keyTip(key: "↵", desc: "Paste")
                keyTip(key: "⇧↵", desc: "Plain")
                keyTip(key: "Esc", desc: "Close")

                Button(action: {
                    controller.showShortcutsPopover.toggle()
                }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(loc("settings.shortcuts.guideTitle"))
                .popover(isPresented: $controller.showShortcutsPopover, arrowEdge: .top) {
                    shortcutsPopoverView
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func keyTip(key: String, desc: String) -> some View {
        HStack(spacing: 2.5) {
            Text(key)
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 3.5)
                .padding(.vertical, 1.5)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.08)))
            Text(desc)
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
        }
    }

    private var shortcutsPopoverView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "keyboard")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 12, weight: .semibold))
                Text("AleClip Shortcuts")
                    .font(.system(size: 12, weight: .bold))
            }

            Divider()

            VStack(spacing: 5) {
                popoverShortcutRow(keys: ["⇧", "⌘", "V"], action: "Open clipboard history")
                popoverShortcutRow(keys: ["⌘", "F"], action: "Search clipboard")
                popoverShortcutRow(keys: ["⌘", "E"], action: "Edit selected item")
                popoverShortcutRow(keys: ["⌘", "R"], action: "Rename selected item")
                popoverShortcutRow(keys: ["⇧", "⌘", "N"], action: "Create new collection")
                popoverShortcutRow(keys: ["⌘", "N"], action: "Create new text item")
                popoverShortcutRow(keys: ["⌘", "T"], action: "Pause clipboard monitoring")
                popoverShortcutRow(keys: ["Space"], action: "Preview selected item")
                popoverShortcutRow(keys: ["⌘", "1...9"], action: "Quick Paste items 1-9")
                popoverShortcutRow(keys: ["⇧", "↵"], action: "Paste as Plain Text")
                popoverShortcutRow(keys: ["⌘", "Z"], action: "Undo last deletion")
                popoverShortcutRow(keys: ["Esc"], action: "Dismiss panel")
            }
        }
        .padding(12)
        .frame(width: 270)
    }

    private func popoverShortcutRow(keys: [String], action: String) -> some View {
        HStack {
            Text(action)
                .font(.system(size: 10.5))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 2) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1.5)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color(nsColor: .controlBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            if controller.selectedFilter == .deleted {
                Image(systemName: "trash")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.7))

                Text(loc("empty.noDeletedClips"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            } else if !controller.searchText.isEmpty {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary.opacity(0.7))

                Text(loc("empty.noMatch"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                WatermarkView()
                    .padding(.bottom, 2)

                Text(loc("empty.noClips"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 888, height: 145, alignment: .center)
    }
}
