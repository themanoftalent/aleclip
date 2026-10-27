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

    private var availableApps: [String] {
        let names = Set(storage.clips.compactMap { $0.sourceAppName?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        return Array(names).sorted()
    }

    private func countForTab(_ tab: FloatingPanelController.FilterTab) -> Int {
        switch tab {
        case .all:
            return storage.clips.count
        case .pinned:
            return storage.clips.filter { $0.isPinned }.count
        case .text:
            return storage.clips.filter { $0.type == .text || $0.type == .richText || $0.type == .html }.count
        case .code:
            return storage.clips.filter { $0.type == .code || $0.detectedLanguage != nil }.count
        case .links:
            return storage.clips.filter { $0.type == .link }.count
        case .images:
            return storage.clips.filter { $0.type == .image }.count
        case .files:
            return storage.clips.filter { $0.type == .file }.count
        case .colors:
            return storage.clips.filter { $0.type == .color }.count
        case .deleted:
            return storage.deletedClips.count
        }
    }

    public var body: some View {
        let items = controller.filteredClips()

        ZStack(alignment: .bottom) {
            // Edge-to-Edge Shelf Window
            VStack(spacing: 6) {
                // MARK: - Row 1: Brand & Search + Pinboards Bar (Paste style) + Tools
                pinboardHeaderBar(itemsCount: items.count)
                    .padding(.top, 8)
                    .padding(.horizontal, 24)

                // MARK: - Row 2: AleClip Content Type Filters & App/Date Filters
                filterSubHeaderBar
                    .padding(.horizontal, 24)

                // Status Strip (if Paste Stack or Screen Privacy or Pause active)
                statusNotificationStrip
                    .padding(.horizontal, 24)

                // MARK: - Card Deck (Horizontal Carousel)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
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
                        .padding(.horizontal, 24)
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
                .frame(height: 228)

                // MARK: - Footer Bar
                footerBar(itemsCount: items.count)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: 350)
            .background(
                ZStack {
                    Rectangle()
                        .fill(reduceTransparency ? Color(nsColor: .windowBackgroundColor) : Color(nsColor: .windowBackgroundColor).opacity(0.88))
                        .background(
                            Rectangle()
                                .fill(.ultraThinMaterial)
                        )
                    watermarkLayer(itemsCount: items.count)
                }
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.primary.opacity(colorSchemeContrast == .increased ? 0.35 : (colorScheme == .dark ? 0.18 : 0.10)))
                    .frame(height: 1)
            }

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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 10, x: 0, y: 4)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.top, 8)

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
                        controller.showToast(message: "Created new text clip")
                    },
                    onCancel: {
                        controller.showNewClipSheet = false
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(340)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 350)
        .onAppear {
            isSearchFieldFocused = false
            controller.isSearchFocused = false
            controller.focusSearchTrigger = {
                isSearchFieldFocused = true
                controller.isSearchFocused = true
            }
        }
    }

    // MARK: - Row 1: Brand, Search, Pinboards Bar & Actions

    private func pinboardHeaderBar(itemsCount: Int) -> some View {
        HStack(spacing: 12) {
            // Brand Mark & Search Input Field
            HStack(spacing: 10) {
                WatermarkView(isCompact: true)

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11.5))

                    TextField(loc("panel.searchPlaceholder"), text: $controller.searchText)
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
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                )
                .frame(width: 180)
            }

            Spacer()

            // Centered Pinboards Bar (Paste style)
            HStack(spacing: 8) {
                // Clipboard History (Default tab)
                let isHistorySelected = controller.selectedCollectionId == nil && controller.selectedFilter != .deleted
                Button(action: {
                    controller.selectedCollectionId = nil
                    controller.selectedFilter = .all
                    controller.selectedIndex = 0
                }) {
                    Text(loc("filter.all"))
                        .font(.system(size: 12, weight: isHistorySelected ? .bold : .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .foregroundColor(isHistorySelected ? .white : .primary)
                        .background(
                            Capsule()
                                .fill(isHistorySelected ? Color.secondary.opacity(0.8) : Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)

                // Custom Pinboard Pills (with colorful dots matching Paste screenshot!)
                ForEach(storage.collections) { pinboard in
                    let isSelected = controller.selectedCollectionId == pinboard.id
                    let pinboardColor = Color(hex: pinboard.colorHex)

                    Button(action: {
                        controller.selectedCollectionId = pinboard.id
                        controller.selectedFilter = .all
                        controller.selectedIndex = 0
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(pinboardColor)
                                .frame(width: 9, height: 9)

                            Text(pinboard.name)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .foregroundColor(isSelected ? .white : .primary)
                        .background(
                            Capsule()
                                .fill(isSelected ? pinboardColor : Color.primary.opacity(0.06))
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

                // Add Pinboard Button (+)
                Button(action: {
                    controller.showNewCollectionSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("New Pinboard (⇧⌘N)")
            }

            Spacer()

            // Right side: Quick Action Tools & Options Menu (•••)
            HStack(spacing: 8) {
                // Paste Stack toggle button
                Button(action: {
                    seqQueue.toggleQueueMode()
                    controller.showToast(message: seqQueue.isQueueActive ? "Paste Stack Active" : "Paste Stack Deactivated")
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: seqQueue.isQueueActive ? "square.stack.3d.down.right.fill" : "square.stack.3d.down.right")
                            .font(.system(size: 12))
                        if seqQueue.isQueueActive {
                            Text("\(seqQueue.queue.count)")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                    }
                    .foregroundColor(seqQueue.isQueueActive ? .accentColor : .secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(seqQueue.isQueueActive ? Color.accentColor.opacity(0.18) : Color.clear))
                }
                .buttonStyle(.plain)
                .help(seqQueue.isQueueActive ? "Paste Stack Active" : "Activate Paste Stack")

                // Screen Privacy Shield button
                Button(action: {
                    privacy.toggleShield()
                }) {
                    Image(systemName: privacy.isShieldActive ? "eye.slash.fill" : "eye")
                        .font(.system(size: 12))
                        .foregroundColor(privacy.isShieldActive ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle Screen Privacy Shield")

                // More Options Menu (••• like Paste)
                Menu {
                    Button(action: {
                        controller.showNewClipSheet = true
                    }) {
                        Label("New Text Item (⌘N)", systemImage: "plus")
                    }

                    Button(action: {
                        monitor.togglePause()
                        let status = monitor.isPaused ? "Monitoring Paused (⌘T)" : "Monitoring Resumed (⌘T)"
                        controller.showToast(message: status)
                    }) {
                        Label(monitor.isPaused ? "Resume Monitoring (⌘T)" : "Pause Monitoring (⌘T)", systemImage: monitor.isPaused ? "play.circle" : "pause.circle")
                    }

                    Divider()

                    Button(action: {
                        controller.selectedFilter = (controller.selectedFilter == .deleted) ? .all : .deleted
                        controller.selectedIndex = 0
                    }) {
                        Label("Trash (\(storage.deletedClips.count))", systemImage: "trash")
                    }

                    Divider()

                    Button(action: {
                        controller.hide()
                        MenuBarController.shared.openSettingsAction()
                    }) {
                        Label("Settings… (⌘,)", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(5)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    // MARK: - Row 2: Content Type Filters & Metadata Filters (AleClip Features)

    private var filterSubHeaderBar: some View {
        HStack(spacing: 8) {
            // Type Filter Pills
            HStack(spacing: 4) {
                ForEach(FloatingPanelController.FilterTab.allCases) { tab in
                    let isSelected = controller.selectedFilter == tab
                    let count = countForTab(tab)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            controller.selectedFilter = tab
                            controller.selectedIndex = 0
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))

                            Text(tab.title)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))

                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 0.5)
                                    .background(Capsule().fill(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.08)))
                                    .foregroundColor(isSelected ? .white : .secondary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .foregroundColor(isSelected ? .white : .primary)
                        .background(
                            Capsule()
                                .fill(isSelected ? (tab == .deleted ? Color.red.opacity(0.85) : Color.accentColor) : Color.primary.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Filter by Application Menu
            if !availableApps.isEmpty {
                Menu {
                    Button(loc("filter.all")) {
                        controller.selectedAppFilter = nil
                    }
                    Divider()
                    ForEach(availableApps, id: \.self) { app in
                        Button(app) {
                            controller.selectedAppFilter = app
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "app.badge")
                            .font(.system(size: 10))
                        Text(controller.selectedAppFilter ?? "App: All")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(controller.selectedAppFilter != nil ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05)))
                    .foregroundColor(controller.selectedAppFilter != nil ? .accentColor : .secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            // Filter by Date Menu
            Menu {
                ForEach(DateFilterOption.allCases) { opt in
                    Button(opt.rawValue) {
                        controller.selectedDateFilter = opt
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(controller.selectedDateFilter.rawValue)
                        .font(.system(size: 10.5, weight: .medium))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(controller.selectedDateFilter != .allTime ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05)))
                .foregroundColor(controller.selectedDateFilter != .allTime ? .accentColor : .secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    // MARK: - Watermark Layer

    @ViewBuilder
    private func watermarkLayer(itemsCount: Int) -> some View {
        GeometryReader { geo in
            let cardsWidth = CGFloat(itemsCount) * (210 + 16) + 48
            let remainingWidth = geo.size.width - cardsWidth

            ZStack {
                if itemsCount == 0 {
                    EmptyView()
                } else if remainingWidth > 260 {
                    HStack(spacing: 0) {
                        Spacer().frame(width: max(0, cardsWidth))
                        WatermarkView(isCompact: false)
                            .opacity(0.30)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                } else {
                    WatermarkView(isCompact: false)
                        .opacity(0.05)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
            .padding(.top, -2)
        }
    }

    // MARK: - Footer Bar

    private func footerBar(itemsCount: Int) -> some View {
        HStack {
            if controller.selectedFilter == .deleted {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 11))
                    Text("Trash Bin (\(storage.deletedClips.count))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)

                    if !storage.deletedClips.isEmpty {
                        Button(action: {
                            controller.restoreAllDeleted()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                Text("Recover All (Tümünü Geri Yükle)")
                                    .fontWeight(.bold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)

                        Button("Empty Trash") {
                            storage.emptyTrash()
                            controller.showToast(message: "Trash emptied")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }

                    Button("Back to All") {
                        controller.selectedFilter = .all
                        controller.selectedIndex = 0
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                }
            } else if !controller.multiSelectedIds.isEmpty {
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
                if controller.selectedFilter == .deleted {
                    keyTip(key: "↵", desc: loc("card.restore"))
                    keyTip(key: "⌫", desc: loc("card.permanentlyDelete"))
                } else {
                    keyTip(key: "↵", desc: "Paste to \(controller.previousApp?.localizedName ?? "App")")
                    keyTip(key: "⇧↵", desc: "Plain Text")
                    keyTip(key: "Space", desc: "Quick Look")
                    keyTip(key: "⌘E", desc: "Edit")
                    keyTip(key: "⌘R", desc: "Rename")
                    keyTip(key: "⌫", desc: "Delete")
                    keyTip(key: "⌘Z", desc: "Undo")
                }
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
                    .font(.system(size: 38))
                    .foregroundColor(.secondary.opacity(0.6))

                Text(loc("empty.noDeletedClips"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            } else if !controller.searchText.isEmpty {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 34))
                    .foregroundColor(.secondary.opacity(0.6))

                Text(loc("empty.noSearchResults"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                WatermarkView(isCompact: false)
                    .padding(.bottom, 6)

                Text(loc("empty.noClips"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 220, alignment: .center)
    }
}
