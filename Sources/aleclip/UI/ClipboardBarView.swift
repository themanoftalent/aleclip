import SwiftUI
import AppKit

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

    private var activePinboardColorHex: String? {
        if let colId = controller.selectedCollectionId,
           let col = storage.collections.first(where: { $0.id == colId }) {
            return col.colorHex
        }
        return nil
    }

    public var body: some View {
        let items = controller.filteredClips()

        ZStack {
            // Main Panel Content
            VStack(spacing: 8) {
                // Top Row: Pinboards & Search Header (Iconic Paste Bar)
                pinboardHeaderBar(itemsCount: items.count)
                    .padding(.top, 6)

                // Secondary Status Notification Strip (Paste Stack / Shield / Paused)
                statusNotificationStrip

                // Middle: Horizontal Card Deck
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 14) {
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
                                        accentColorHex: activePinboardColorHex,
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
                        .padding(.horizontal, 18)
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
                .frame(height: 185)

                // Footer Bar: Paste Shortcuts Tips
                footerBar(itemsCount: items.count)
                    .padding(.bottom, 6)
            }
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(reduceTransparency ? Color(nsColor: .windowBackgroundColor) : Color(nsColor: .windowBackgroundColor).opacity(0.85))
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        Color.primary.opacity(colorSchemeContrast == .increased ? 0.35 : (colorScheme == .dark ? 0.18 : 0.10)),
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

            // New Pinboard Sheet Overlay
            if controller.showNewCollectionSheet {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        controller.showNewCollectionSheet = false
                    }

                NewCollectionSheet(
                    onSave: { name, icon, colorHex in
                        let col = ClipCollection(name: name, icon: icon, colorHex: colorHex)
                        storage.addCollection(col)
                        controller.selectedCollectionId = col.id
                        controller.showNewCollectionSheet = false
                        controller.showToast(message: "Created Pinboard: \(name)")
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
                            isSensitive: detected.isSensitive,
                            collectionId: controller.selectedCollectionId
                        )
                        storage.addClip(newClip)
                        controller.showNewClipSheet = false
                        controller.showToast(message: "Created item")
                    },
                    onCancel: {
                        controller.showNewClipSheet = false
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(340)
            }
        }
        .frame(width: 980, height: 290)
        .onAppear {
            controller.focusSearchTrigger = {
                isSearchFieldFocused = true
            }
        }
    }

    // MARK: - Pinboards Header Bar (Signature Paste Feature)

    private func pinboardHeaderBar(itemsCount: Int) -> some View {
        HStack(spacing: 8) {
            // Pinboards tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    // 1. Main Clipboard History Tab
                    Button(action: {
                        controller.selectedCollectionId = nil
                        controller.selectedFilter = .all
                        controller.selectedIndex = 0
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Clipboard History")
                                .font(.system(size: 11.5, weight: (controller.selectedCollectionId == nil && controller.selectedFilter != .deleted) ? .bold : .medium))

                            if controller.selectedCollectionId == nil && controller.selectedFilter != .deleted {
                                Text("\(storage.clips.count)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 4.5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.primary.opacity(0.12)))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundColor((controller.selectedCollectionId == nil && controller.selectedFilter != .deleted) ? .primary : .secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill((controller.selectedCollectionId == nil && controller.selectedFilter != .deleted) ? Color(nsColor: .selectedControlColor).opacity(0.35) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)

                    // 2. Custom Pinboards
                    ForEach(storage.collections) { pinboard in
                        let isSelected = controller.selectedCollectionId == pinboard.id
                        let pinboardColor = Color(hex: pinboard.colorHex)
                        let count = storage.clips.filter { $0.collectionId == pinboard.id }.count

                        Button(action: {
                            controller.selectedCollectionId = pinboard.id
                            controller.selectedFilter = .all
                            controller.selectedIndex = 0
                        }) {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(pinboardColor)
                                    .frame(width: 8, height: 8)

                                Text(pinboard.name)
                                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))

                                Text("\(count)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 4.5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(isSelected ? pinboardColor.opacity(0.25) : Color.primary.opacity(0.1)))
                                    .foregroundColor(isSelected ? pinboardColor : .secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundColor(isSelected ? .primary : .secondary)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(isSelected ? pinboardColor.opacity(0.15) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete Pinboard", role: .destructive) {
                                storage.removeCollection(id: pinboard.id)
                                if controller.selectedCollectionId == pinboard.id {
                                    controller.selectedCollectionId = nil
                                }
                            }
                        }
                    }

                    // 3. Add Pinboard Button (+)
                    Button(action: {
                        controller.showNewCollectionSheet = true
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("New Pinboard")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .foregroundColor(.secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Create New Pinboard (⇧⌘N)")
                }
            }

            Spacer()

            // Search Bar (Command + F)
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("Search history & OCR…", text: $controller.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isSearchFieldFocused)
                    .onChange(of: isSearchFieldFocused) { _, focused in
                        controller.isSearchFocused = focused
                    }

                if !controller.searchText.isEmpty {
                    Button(action: { controller.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
            )
            .frame(width: 175)

            // Content Type Filter Menu
            Menu {
                ForEach(FloatingPanelController.FilterTab.allCases) { tab in
                    Button(tab.title) {
                        controller.selectedFilter = tab
                        controller.selectedIndex = 0
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: controller.selectedFilter.iconName)
                        .font(.system(size: 10))
                    Text(controller.selectedFilter == .all ? "Type" : controller.selectedFilter.title)
                        .font(.system(size: 10.5))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Paste Stack toggle button (Feature 9)
            Button(action: {
                seqQueue.toggleQueueMode()
                controller.showToast(message: seqQueue.isQueueActive ? "Paste Stack Active" : "Paste Stack Deactivated")
            }) {
                HStack(spacing: 3) {
                    Image(systemName: seqQueue.isQueueActive ? "square.stack.3d.down.right.fill" : "square.stack.3d.down.right")
                        .font(.system(size: 11))
                    if seqQueue.isQueueActive {
                        Text("\(seqQueue.queue.count)")
                            .font(.system(size: 9, weight: .bold))
                    }
                }
                .foregroundColor(seqQueue.isQueueActive ? .accentColor : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(seqQueue.isQueueActive ? Color.accentColor.opacity(0.15) : Color.clear))
            }
            .buttonStyle(.plain)
            .help(seqQueue.isQueueActive ? "Paste Stack Active (Sequential Paste)" : "Activate Paste Stack")

            // Screen Privacy Shield toggle (Feature 15)
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

            // New Item button (Command + N)
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
            .help("Settings (⌘,)")
        }
        .padding(.horizontal, 18)
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
            .padding(.horizontal, 18)
            .padding(.top, -2)
        }
    }

    // MARK: - Footer Bar

    private func footerBar(itemsCount: Int) -> some View {
        HStack {
            if !controller.multiSelectedIds.isEmpty {
                HStack(spacing: 6) {
                    Text("\(controller.multiSelectedIds.count) items selected")
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
                Text("\(itemsCount) \(itemsCount == 1 ? "clip" : "clips")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                keyTip(key: "↵", desc: "Paste")
                keyTip(key: "⇧↵", desc: "Plain Text")
                keyTip(key: "Space", desc: "Quick Look")
                keyTip(key: "⌘E", desc: "Edit")
                keyTip(key: "⌘R", desc: "Rename")
                keyTip(key: "⌫", desc: "Delete")
                keyTip(key: "⌘Z", desc: "Undo")
                keyTip(key: "Esc", desc: "Close")

                Button(action: {
                    controller.showShortcutsPopover.toggle()
                }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Keyboard Shortcuts Guide")
                .popover(isPresented: $controller.showShortcutsPopover, arrowEdge: .top) {
                    shortcutsPopoverView
                }
            }
        }
        .padding(.horizontal, 18)
    }

    private func keyTip(key: String, desc: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 4)
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
                Text("Keyboard Shortcuts")
                    .font(.system(size: 12, weight: .bold))
            }

            Divider()

            VStack(spacing: 5) {
                popoverShortcutRow(keys: ["⇧", "⌘", "V"], action: "Open clipboard history")
                popoverShortcutRow(keys: ["⌘", "F"], action: "Search clipboard")
                popoverShortcutRow(keys: ["⌘", "E"], action: "Edit selected item")
                popoverShortcutRow(keys: ["⌘", "R"], action: "Rename selected item")
                popoverShortcutRow(keys: ["⇧", "⌘", "N"], action: "Create new Pinboard")
                popoverShortcutRow(keys: ["⌘", "N"], action: "Create new text item")
                popoverShortcutRow(keys: ["⌘", "T"], action: "Pause clipboard monitoring")
                popoverShortcutRow(keys: ["Space"], action: "Preview selected item (Quick Look)")
                popoverShortcutRow(keys: ["⌘", "1...9"], action: "Quick Paste items 1 to 9")
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
        VStack(spacing: 12) {
            if controller.selectedFilter == .deleted {
                Image(systemName: "trash")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary.opacity(0.6))

                Text("Trash is empty")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            } else if !controller.searchText.isEmpty {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.6))

                Text("No clips match your search")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "paperclip")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor.opacity(0.7))

                Text("No clips yet. Copy something to start.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 930, height: 180, alignment: .center)
    }
}
