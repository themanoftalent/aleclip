import SwiftUI
import AppKit

// MARK: - Watermark View

public struct WatermarkView: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        let opacity = colorScheme == .dark ? 0.07 : 0.05
        Text("ALE")
            .font(.system(size: 72, weight: .heavy, design: .rounded))
            .foregroundColor(.primary.opacity(opacity))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

public struct ClipboardBarView: View {
    @ObservedObject private var controller = FloatingPanelController.shared
    @ObservedObject private var storage = StorageService.shared

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init() {}

    public var body: some View {
        let items = controller.filteredClips()

        ZStack {
            // Main Panel Content
            VStack(spacing: 8) {
                // Header Bar: Search & Filter Tabs
                headerBar(itemsCount: items.count)
                    .padding(.top, 4)

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
                                        isDeleted: controller.selectedFilter == .deleted,
                                        onSelect: {
                                            controller.selectedIndex = index
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

                // Footer Bar: Keyboard shortcuts info
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

            // Overlays: Quick Look
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
            }

            // Overlays: Edit Sheet
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
            }
        }
        .frame(width: 880, height: 260)
    }

    // MARK: - Watermark Layer

    @ViewBuilder
    private func watermarkLayer(itemsCount: Int) -> some View {
        GeometryReader { geo in
            let cardsWidth = CGFloat(itemsCount) * (190 + 12) + 32
            let remainingWidth = geo.size.width - cardsWidth

            ZStack {
                if itemsCount == 0 {
                    WatermarkView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if remainingWidth > 180 {
                    HStack(spacing: 0) {
                        Spacer().frame(width: cardsWidth)
                        WatermarkView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                } else {
                    WatermarkView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Header Bar

    private func headerBar(itemsCount: Int) -> some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))

                TextField(loc("panel.searchPlaceholder"), text: $controller.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onReceive(NotificationCenter.default.publisher(for: NSControl.textDidBeginEditingNotification)) { _ in
                        controller.isSearchFocused = true
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSControl.textDidEndEditingNotification)) { _ in
                        controller.isSearchFocused = false
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
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
            )
            .frame(width: 200)

            // Filter Tabs
            HStack(spacing: 4) {
                ForEach(FloatingPanelController.FilterTab.allCases) { tab in
                    Button(action: {
                        controller.selectedFilter = tab
                        controller.selectedIndex = 0
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 10))
                            Text(tab.title)
                                .font(.system(size: 11, weight: controller.selectedFilter == tab ? .semibold : .regular))
                            if tab == .deleted && storage.deletedClips.count > 0 {
                                Text("\(storage.deletedClips.count)")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 0.5)
                                    .background(Capsule().fill(controller.selectedFilter == tab ? Color.accentColor : Color.primary.opacity(0.12)))
                                    .foregroundColor(controller.selectedFilter == tab ? .white : .secondary)
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4.5)
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

            // Empty Trash button if in deleted tab
            if controller.selectedFilter == .deleted && !storage.deletedClips.isEmpty {
                Button(action: {
                    storage.emptyTrash()
                    controller.selectedIndex = 0
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "trash.slash")
                            .font(.system(size: 10))
                        Text(loc("menu.emptyTrash"))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.red.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.red.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help(loc("menu.emptyTrash"))
            }

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

            // Clear unpinned button (when not in deleted tab)
            if controller.selectedFilter != .deleted {
                Button(action: {
                    storage.clearUnpinned()
                    controller.selectedIndex = 0
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(loc("menu.clearUnpinned"))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Footer Bar

    private func footerBar(itemsCount: Int) -> some View {
        HStack {
            Text("\(itemsCount) \(loc(itemsCount == 1 ? "footer.clip" : "footer.clips"))")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 12) {
                keyTip(key: "← →", desc: loc("footer.navigate"))
                if controller.selectedFilter == .deleted {
                    keyTip(key: "↵", desc: loc("card.restore"))
                    keyTip(key: "⌫", desc: loc("card.permanentlyDelete"))
                } else {
                    keyTip(key: "↵", desc: loc("footer.paste"))
                    keyTip(key: "Space", desc: loc("footer.preview"))
                    keyTip(key: "⌘Z", desc: loc("toast.undo"))
                }
                keyTip(key: "Esc", desc: loc("footer.close"))

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
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)))
            Text(desc)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    private var shortcutsPopoverView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "keyboard")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 12, weight: .semibold))
                Text(loc("settings.shortcuts.guideTitle"))
                    .font(.system(size: 12, weight: .bold))
            }

            Divider()

            VStack(spacing: 6) {
                popoverShortcutRow(keys: ["⌥", "V"], action: loc("settings.shortcuts.togglePanel"))
                popoverShortcutRow(keys: ["←", "→"], action: loc("settings.shortcuts.navigateCards"))
                popoverShortcutRow(keys: ["↵"], action: loc("settings.shortcuts.pasteClip"))
                popoverShortcutRow(keys: ["⌘", "1...9"], action: loc("settings.shortcuts.quickPaste"))
                popoverShortcutRow(keys: ["⇧", "↵"], action: loc("settings.shortcuts.plainPaste"))
                popoverShortcutRow(keys: ["Space"], action: loc("settings.shortcuts.quickLook"))
                popoverShortcutRow(keys: ["⌘", "E"], action: loc("settings.shortcuts.editClip"))
                popoverShortcutRow(keys: ["⌫"], action: loc("settings.shortcuts.deleteClip"))
                popoverShortcutRow(keys: ["⌘", "Z"], action: loc("settings.shortcuts.undoDelete"))
                popoverShortcutRow(keys: ["⌘", ","], action: loc("settings.shortcuts.openSettings"))
                popoverShortcutRow(keys: ["Esc"], action: loc("settings.shortcuts.dismissPanel"))
            }
        }
        .padding(12)
        .frame(width: 250)
    }

    private func popoverShortcutRow(keys: [String], action: String) -> some View {
        HStack {
            Text(action)
                .font(.system(size: 11))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: controller.selectedFilter == .deleted ? "trash" : (controller.searchText.isEmpty ? "tray" : "magnifyingglass"))
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.7))

            Text(controller.selectedFilter == .deleted
                 ? loc("empty.noDeletedClips")
                 : (controller.searchText.isEmpty ? loc("empty.noClips") : loc("empty.noMatch")))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(width: 848, height: 145, alignment: .center)
    }
}
