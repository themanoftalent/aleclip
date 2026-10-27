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
    public let accentColorHex: String?
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
        accentColorHex: String? = nil,
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
        self.accentColorHex = accentColorHex
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

    private var cardBorderColor: Color {
        if isSelected || isMultiSelected {
            if let hex = accentColorHex {
                return Color(hex: hex)
            }
            return Color.accentColor
        }
        if clip.isPinned {
            return Color.orange.opacity(0.5)
        }
        if hoverModel.isHovered {
            return Color.primary.opacity(0.3)
        }
        return Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Row: App Icon + App Name + Time + Quick Paste Badge
            HStack(spacing: 6) {
                // Source App Icon
                if let bundleId = clip.sourceAppBundleId,
                   let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                        .resizable()
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: clip.type.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }

                if let appName = clip.sourceAppName {
                    Text(appName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary.opacity(0.85))
                        .lineLimit(1)
                } else {
                    Text(clip.type.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let num = shortcutNumber {
                    Text("⌘\(num)")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.08))
                        )
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }

                Text(clip.relativeTimeString)
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()
                .opacity(0.4)

            // Body Content Area (The iconic Paste preview)
            ZStack(alignment: .topLeading) {
                contentPreview
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .blur(radius: privacy.isShieldActive ? 14 : 0)

                if privacy.isShieldActive {
                    VStack {
                        Spacer()
                        HStack(spacing: 5) {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 11))
                            Text("Protected")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Spacer(minLength: 0)

            Divider()
                .opacity(0.3)

            // Card Footer: Details & Actions
            HStack(spacing: 6) {
                // Details (character count, language, ocr)
                if let lang = clip.detectedLanguage {
                    HStack(spacing: 3) {
                        Image(systemName: "curlybraces")
                            .font(.system(size: 7))
                        Text(lang)
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.purple.opacity(0.18)))
                    .foregroundColor(.purple)
                } else if clip.ocrText != nil {
                    HStack(spacing: 2) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 7))
                        Text("OCR")
                            .font(.system(size: 8, weight: .heavy))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.blue.opacity(0.18)))
                    .foregroundColor(.blue)
                } else if clip.type == .text || clip.type == .richText {
                    Text("\(clip.plainText.count) chars")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.75))
                }

                if clip.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                }

                Spacer()

                // Action buttons on hover / selected
                if hoverModel.isHovered || isSelected {
                    HStack(spacing: 8) {
                        if isDeleted, let onRestore = onRestore {
                            Button(action: onRestore) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help(loc("card.restore"))
                        } else {
                            Button(action: onQuickLook) {
                                Image(systemName: "eye")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Quick Look (Space)")

                            if clip.type == .text || clip.type == .richText || clip.type == .code {
                                Button(action: onEdit) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Edit (⌘E)")
                            }

                            Button(action: onTogglePin) {
                                Image(systemName: clip.isPinned ? "pin.fill" : "pin")
                                    .font(.system(size: 11))
                                    .foregroundColor(clip.isPinned ? .orange : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help(clip.isPinned ? "Unpin clip" : "Pin clip")
                        }

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                        .help("Delete (⌫)")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 220, height: 175)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.85 : 0.95))
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )

                if isSelected || isMultiSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill((accentColorHex != nil ? Color(hex: accentColorHex!) : Color.accentColor).opacity(0.08))
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardBorderColor, lineWidth: (isSelected || isMultiSelected) ? 2 : 1)
        )
        .shadow(
            color: isSelected
                ? (accentColorHex != nil ? Color(hex: accentColorHex!) : Color.accentColor).opacity(0.28)
                : Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08),
            radius: isSelected ? 8 : 3,
            x: 0,
            y: isSelected ? 3 : 1
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
                Label("Paste (↵)", systemImage: "arrow.right.doc.on.clipboard")
            }
            Button(action: {
                PasteService.shared.pasteClip(clip, targetApp: FloatingPanelController.shared.previousApp, forcePlainText: true)
                FloatingPanelController.shared.hide()
            }) {
                Label("Paste as Plain Text (⇧↵)", systemImage: "doc.text")
            }
            Button(action: {
                PasteService.shared.copyToClipboard(clip)
            }) {
                Label("Copy to Clipboard (⌘C)", systemImage: "doc.on.doc")
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

            // Move to Pinboard Submenu
            Menu("Move to Pinboard") {
                Button("Clipboard History (Default)") {
                    StorageService.shared.assignClip(clipId: clip.id, to: nil)
                }
                Divider()
                ForEach(StorageService.shared.collections) { pinboard in
                    Button(pinboard.name) {
                        StorageService.shared.assignClip(clipId: clip.id, to: pinboard.id)
                    }
                }
            }

            Divider()

            Button(action: onTogglePin) {
                Label(
                    clip.isPinned ? "Unpin clip" : "Pin clip",
                    systemImage: clip.isPinned ? "pin.slash" : "pin"
                )
            }
            Button(action: onQuickLook) {
                Label("Quick Look (Space)", systemImage: "eye")
            }
            if clip.type == .text || clip.type == .richText || clip.type == .code {
                Button(action: onEdit) {
                    Label("Edit (⌘E)", systemImage: "pencil")
                }
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete (⌫)", systemImage: "trash")
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

    private var textPreview: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(clip.displayTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)

            let lines = clip.plainText.components(separatedBy: .newlines).dropFirst()
            let remainingText = lines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

            if !remainingText.isEmpty {
                Text(remainingText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .lineSpacing(2)
            }
        }
    }

    private var codePreview: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(clip.displayTitle)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.purple)
                .lineLimit(1)

            Text(clip.plainText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary.opacity(0.85))
                .lineLimit(4)
                .lineSpacing(2)
        }
    }

    private var imagePreview: some View {
        Group {
            if let filename = clip.imageFileName,
               let nsImage = StorageService.shared.loadImageBlob(named: filename) {
                VStack(spacing: 4) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 74)
                        .cornerRadius(6)

                    if let ocr = clip.ocrText, !ocr.isEmpty {
                        Text(ocr)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                    Text("Image")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var colorPreview: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: clip.colorHex ?? "#000000"))
                .frame(width: 52, height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                )
                .shadow(radius: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(clip.colorHex ?? "#000000")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)

                Text("RGB Color Swatch")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var linkPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.blue)

                if let host = URL(string: clip.url ?? clip.plainText)?.host {
                    Text(host)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                }
            }

            Text(clip.displayTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)

            Text(clip.url ?? clip.plainText)
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private var filePreview: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .font(.system(size: 30))
                .foregroundColor(.orange)

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
}
