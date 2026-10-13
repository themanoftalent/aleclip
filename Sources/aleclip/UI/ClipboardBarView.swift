import SwiftUI
import AppKit

// MARK: - Watermark View

public struct WatermarkView: View {
    // MARK: - Configuration Constants
    public static let text: String = "ALE"
    public static let opacity: Double = 0.06
    public static let heightRatio: CGFloat = 0.70

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            Text(Self.text)
                .font(.system(size: geo.size.height * Self.heightRatio, weight: .heavy, design: .rounded))
                .foregroundColor(.primary.opacity(Self.opacity))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

public struct ClipboardBarView: View {
    @ObservedObject private var controller = FloatingPanelController.shared
    @ObservedObject private var storage = StorageService.shared

    public init() {}

    public var body: some View {
        let items = controller.filteredClips()

        ZStack {
            // Main Panel Content
            VStack(spacing: 10) {
                // Header Bar: Search & Filter Tabs
                headerBar(itemsCount: items.count)

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
                                        isSelected: index == controller.selectedIndex,
                                        onSelect: {
                                            controller.selectedIndex = index
                                        },
                                        onPaste: {
                                            controller.selectedIndex = index
                                            controller.pasteSelected()
                                        },
                                        onTogglePin: {
                                            storage.togglePin(for: clip.id)
                                        },
                                        onDelete: {
                                            storage.deleteClip(id: clip.id)
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
            }
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    WatermarkView()
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)

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
        .padding(8)
    }

    // MARK: - Header Bar

    private func headerBar(itemsCount: Int) -> some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))

                TextField("Search clips...", text: $controller.searchText)
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
            .frame(width: 220)

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
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: controller.selectedFilter == tab ? .semibold : .regular))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
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
            .help("AleClip Settings (⌘,)")

            // Clear unpinned button
            Button(action: {
                storage.clearUnpinned()
                controller.selectedIndex = 0
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear Unpinned History")
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Footer Bar

    private func footerBar(itemsCount: Int) -> some View {
        HStack {
            Text("\(itemsCount) clips")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 11) {
                keyTip(key: "← →", desc: "Navigate")
                keyTip(key: "↵", desc: "Paste")
                keyTip(key: "⇧↵", desc: "Plain Text")
                keyTip(key: "Space", desc: "Preview")
                keyTip(key: "⌘E", desc: "Edit")
                keyTip(key: "⌫", desc: "Delete")
                keyTip(key: "⌘,", desc: "Settings")
                keyTip(key: "Esc", desc: "Close")
            }
        }
        .padding(.horizontal, 18)
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

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.6))
            Text("No clips found")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text("Copy text, images, links, or colors to see them here.")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(width: 840, height: 130)
    }
}
