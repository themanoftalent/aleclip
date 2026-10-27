import SwiftUI
import AppKit

final class HoverViewModel: ObservableObject {
    @Published var isHovered: Bool = false
}

public struct ClipCardView: View {
    public let clip: ClipItem
    public let shortcutNumber: Int?
    public let isSelected: Bool
    public let isMultiSelected: Bool
    public let isDeleted: Bool
    public let onSelect: () -> Void
    public let onToggleMultiSelect: () -> Void
    public let onPaste: () -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void
    public let onRestore: (() -> Void)?
    public let onQuickLook: () -> Void
    public let onEdit: () -> Void
    public let onRename: () -> Void

    public init(
        clip: ClipItem,
        shortcutNumber: Int? = nil,
        isSelected: Bool,
        isMultiSelected: Bool = false,
        isDeleted: Bool = false,
        onSelect: @escaping () -> Void,
        onToggleMultiSelect: @escaping () -> Void = {},
        onPaste: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onRestore: (() -> Void)? = nil,
        onQuickLook: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onRename: @escaping () -> Void = {}
    ) {
        self.clip = clip
        self.shortcutNumber = shortcutNumber
        self.isSelected = isSelected
        self.isMultiSelected = isMultiSelected
        self.isDeleted = isDeleted
        self.onSelect = onSelect
        self.onToggleMultiSelect = onToggleMultiSelect
        self.onPaste = onPaste
        self.onTogglePin = onTogglePin
        self.onDelete = onDelete
        self.onRestore = onRestore
        self.onQuickLook = onQuickLook
        self.onEdit = onEdit
        self.onRename = onRename
    }

    @StateObject private var hoverModel = HoverViewModel()
    @ObservedObject private var privacy = ScreenPrivacyService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Type badge & Pin & Relative Time
            HStack(spacing: 5) {
                if isMultiSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: clip.type.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(typeColor)
                }

                Text(clip.type.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.85))

                if let lang = clip.detectedLanguage {
                    Text(lang)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.purple.opacity(0.18)))
                        .foregroundColor(.purple)
                }

                if clip.ocrText != nil {
                    Text("OCR")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.blue.opacity(0.18)))
                        .foregroundColor(.blue)
                }

                if let num = shortcutNumber {
                    Text("⌘\(num)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.08))
                        )
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }

                if clip.isPinned {
                    HStack(spacing: 2) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                        Text(loc("card.pinnedBadge"))
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .foregroundColor(.orange)
                    .background(
                        Capsule().fill(Color.orange.opacity(0.18))
                    )
                }

                Spacer()

                Text(clip.relativeTimeString)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                if isDeleted, let onRestore = onRestore {
                    Button(action: onRestore) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 8, weight: .bold))
                            Text(loc("card.restore"))
                                .font(.system(size: 8, weight: .bold))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color.accentColor.opacity(0.18)))
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help(loc("card.restore"))
                } else {
                    Button(action: onTogglePin) {
                        Image(systemName: clip.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 10))
                            .foregroundColor(clip.isPinned ? .orange : .secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help(loc(clip.isPinned ? "card.unpin" : "card.pin"))
                }
            }

            // Body Preview (with Screen Privacy shield when enabled)
            ZStack {
                contentPreview
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .blur(radius: privacy.isShieldActive ? 12 : 0)

                if privacy.isShieldActive {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 10))
                        Text("Protected")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(nsColor: .windowBackgroundColor).opacity(0.9)))
                    .foregroundColor(.secondary)
                }
            }

            // Footer: Source App & Actions
            HStack(spacing: 5) {
                // Source App Icon
                if let bundleId = clip.sourceAppBundleId,
                   let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                        .resizable()
                        .frame(width: 12, height: 12)
                }

                if let appName = clip.sourceAppName {
                    Text(appName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if hoverModel.isHovered || isSelected {
                    HStack(spacing: 6) {
                        if isDeleted, let onRestore = onRestore {
                            Button(action: onRestore) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help(loc("card.restore"))
                        } else {
                            Button(action: onQuickLook) {
                                Image(systemName: "eye")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(loc("card.quickLook"))

                            if clip.type == .text || clip.type == .richText || clip.type == .code {
                                Button(action: onEdit) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help(loc("card.edit"))
                            }
                        }

                        Button(action: onDelete) {
                            Image(systemName: isDeleted ? "xmark.circle.fill" : "trash")
                                .font(.system(size: 10))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help(loc(isDeleted ? "card.permanentlyDelete" : "card.delete"))
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 200, height: 140)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? Color(nsColor: .controlBackgroundColor)
                            : (reduceTransparency ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.95 : 0.90))
                    )

                if isSelected || isMultiSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                }

                if clip.isPinned {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.06))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isSelected || isMultiSelected
                        ? Color.accentColor
                        : (clip.isPinned
                            ? Color.orange.opacity(0.4)
                            : (hoverModel.isHovered
                                ? Color.primary.opacity(0.28)
                                : Color.primary.opacity(colorSchemeContrast == .increased ? 0.35 : 0.15))),
                    lineWidth: (isSelected || isMultiSelected) ? (colorSchemeContrast == .increased ? 2.5 : 2) : 1
                )
        )
        .shadow(
            color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08),
            radius: isSelected ? 5 : 2,
            x: 0,
            y: 1
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.shift) {
                onToggleMultiSelect()
            } else {
                onSelect()
            }
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onPaste()
            }
        )
        .onHover { hovering in
            hoverModel.isHovered = hovering
        }
        .contextMenu {
            contextMenuContent
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if isDeleted {
            if let onRestore = onRestore {
                Button(action: onRestore) {
                    Label(loc("card.restore"), systemImage: "arrow.uturn.backward")
                }
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label(loc("card.permanentlyDelete"), systemImage: "trash.fill")
            }
        } else {
            Button(action: onPaste) {
                Label(loc("context.paste"), systemImage: "arrow.right.doc.on.clipboard")
            }
            Button(action: {
                PasteService.shared.pasteClip(clip, targetApp: FloatingPanelController.shared.previousApp, forcePlainText: true)
                FloatingPanelController.shared.hide()
            }) {
                Label("Paste as Plain Text", systemImage: "doc.text")
            }
            Button(action: {
                PasteService.shared.copyToClipboard(clip)
            }) {
                Label(loc("context.copy"), systemImage: "doc.on.doc")
            }

            Divider()

            Button(action: {
                StorageService.shared.duplicateClip(id: clip.id)
            }) {
                Label("Duplicate Item", systemImage: "plus.square.on.square")
            }

            Button(action: onRename) {
                Label("Rename (⌘R)", systemImage: "character.cursor.ibeam")
            }

            // Assign to Collection Submenu
            if !StorageService.shared.collections.isEmpty {
                Menu("Assign to Collection") {
                    Button("None") {
                        StorageService.shared.assignClip(clipId: clip.id, to: nil)
                    }
                    Divider()
                    ForEach(StorageService.shared.collections) { col in
                        Button(col.name) {
                            StorageService.shared.assignClip(clipId: clip.id, to: col.id)
                        }
                    }
                }
            }

            Divider()

            Button(action: onTogglePin) {
                Label(
                    loc(clip.isPinned ? "card.unpin" : "card.pin"),
                    systemImage: clip.isPinned ? "pin.slash" : "pin"
                )
            }
            Button(action: onQuickLook) {
                Label(loc("card.quickLook"), systemImage: "eye")
            }
            if clip.type == .text || clip.type == .richText || clip.type == .code {
                Button(action: onEdit) {
                    Label(loc("card.edit"), systemImage: "pencil")
                }
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label(loc("card.delete"), systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch clip.type {
        case .color:
            colorPreview
        case .image:
            imagePreview
        case .file:
            filePreview
        case .link:
            linkPreview
        case .code:
            codePreview
        case .text, .richText, .html:
            textPreview
        }
    }

    private var colorPreview: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: clip.colorHex ?? "#000000"))
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(clip.colorHex ?? "#000000")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)

                Text(loc("card.rgbColor"))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var imagePreview: some View {
        Group {
            if let filename = clip.imageFileName,
               let nsImage = StorageService.shared.loadImageBlob(named: filename) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 64)
                    .cornerRadius(4)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Text(loc("filter.images"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var filePreview: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.fill")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(clip.displayTitle)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2)
                    .foregroundColor(.primary)

                if let urlString = clip.url, let url = URL(string: urlString) {
                    Text(url.pathExtension.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var linkPreview: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)

                Text(clip.url ?? clip.plainText)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.blue)
            }

            Text(clip.displayTitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
    }

    private var codePreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(clip.displayTitle)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .foregroundColor(.purple)

            Text(clip.plainText)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.primary.opacity(0.85))
                .lineLimit(3)
        }
    }

    private var textPreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(clip.displayTitle)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(.primary)

            let lines = clip.plainText.components(separatedBy: .newlines).dropFirst()
            let remainingText = lines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

            if !remainingText.isEmpty {
                Text(remainingText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var typeColor: Color {
        switch clip.type {
        case .color: return .pink
        case .file: return .orange
        case .image: return .green
        case .link: return .blue
        case .code: return .purple
        case .text, .richText, .html: return .accentColor
        }
    }
}

private extension Color {
    init(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }
        let scanner = Scanner(string: cleanHex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
