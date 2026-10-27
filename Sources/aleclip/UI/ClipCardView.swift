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

    // The signature Paste header banner gradient
    private var headerGradient: LinearGradient {
        if let hex = accentColorHex {
            let base = Color(hex: hex)
            return LinearGradient(
                colors: [base, base.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        switch clip.type {
        case .link:
            return LinearGradient(
                colors: [Color(red: 0.00, green: 0.58, blue: 1.00), Color(red: 0.00, green: 0.46, blue: 0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .text, .richText, .html:
            return LinearGradient(
                colors: [Color(red: 1.00, green: 0.72, blue: 0.00), Color(red: 0.98, green: 0.60, blue: 0.00)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .file:
            return LinearGradient(
                colors: [Color(red: 0.00, green: 0.72, blue: 0.98), Color(red: 0.00, green: 0.58, blue: 0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .code:
            return LinearGradient(
                colors: [Color(red: 0.62, green: 0.36, blue: 0.94), Color(red: 0.48, green: 0.24, blue: 0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .image:
            return LinearGradient(
                colors: [Color(red: 0.12, green: 0.80, blue: 0.48), Color(red: 0.06, green: 0.68, blue: 0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .color:
            let col = Color(hex: clip.colorHex ?? "#FF2D55")
            return LinearGradient(
                colors: [col, col.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var activeBorderColor: Color {
        if isSelected || isMultiSelected {
            return (accentColorHex != nil ? Color(hex: accentColorHex!) : Color.accentColor)
        }
        if clip.isPinned {
            return Color.orange.opacity(0.55)
        }
        if hoverModel.isHovered {
            return Color.primary.opacity(0.28)
        }
        return Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08)
    }

    private var targetAppName: String {
        FloatingPanelController.shared.previousApp?.localizedName ?? "Active App"
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Header Banner (Paste signature colorful banner)
            ZStack(alignment: .topTrailing) {
                // Banner background
                headerGradient
                    .frame(height: 60)

                // Header content: Title & Timestamp (Left) and Large App Icon (Right)
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headerTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 1)

                        Text(clip.relativeTimeString)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.88))
                    }

                    Spacer()

                    // Quick Paste Number Badge (if 1...9)
                    if let num = shortcutNumber {
                        Text("⌘\(num)")
                            .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule().fill(Color.black.opacity(0.22))
                            )
                            .foregroundColor(.white)
                    }

                    // Large App Icon
                    if let bundleId = clip.sourceAppBundleId,
                       let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                            .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1.5)
                    } else {
                        Image(systemName: clip.type.iconName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(width: 36, height: 36)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
            }
            .frame(height: 60)

            // MARK: - Card Body Preview
            ZStack(alignment: .topLeading) {
                // Card Background (Light: clean white; Dark: rich dark slate)
                Color(nsColor: .controlBackgroundColor)
                    .opacity(colorScheme == .dark ? 0.92 : 1.0)

                // Preview Content
                VStack(alignment: .leading, spacing: 0) {
                    contentPreview
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                        .blur(radius: privacy.isShieldActive ? 14 : 0)

                    Spacer(minLength: 0)

                    Divider()
                        .opacity(0.3)

                    // Card Footer: Details (e.g. "223 characters", "1.2 MB") & Hover Actions
                    HStack(spacing: 4) {
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
                        } else {
                            Text(footerDetailText)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.75))
                        }

                        if clip.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.orange)
                        }

                        Spacer()

                        // Hover Actions
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }

                // Privacy Shield Overlay
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 215, height: 225)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(activeBorderColor, lineWidth: (isSelected || isMultiSelected) ? 2.5 : 1)
        )
        .shadow(
            color: isSelected
                ? (accentColorHex != nil ? Color(hex: accentColorHex!) : Color.accentColor).opacity(0.35)
                : Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08),
            radius: isSelected ? 8 : 4,
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

    private var headerTitle: String {
        if let custom = clip.title, !custom.isEmpty {
            return custom
        }
        switch clip.type {
        case .link: return "Link"
        case .file: return "File"
        case .color: return "Color"
        case .image: return "Image"
        case .code: return "Code"
        case .text, .richText, .html: return "Text"
        }
    }

    private var footerDetailText: String {
        switch clip.type {
        case .file:
            return "File"
        case .color:
            return clip.colorHex ?? "RGB"
        case .image:
            return "Image"
        default:
            return "\(clip.plainText.count) characters"
        }
    }

    // Context Menu matching Paste for Mac (shown in user's screenshot)
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
                Label("Paste to \(targetAppName)", systemImage: "arrow.right.doc.on.clipboard")
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
                Label("Copy", systemImage: "doc.on.doc")
            }

            Divider()

            // Pin To >
            Menu("Pin To") {
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

            Button(action: onRename) {
                Label("Rename", systemImage: "character.cursor.ibeam")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }

            Divider()

            Button(action: onQuickLook) {
                Label("Quick Look", systemImage: "eye")
            }

            Button(action: {
                let sharePicker = NSSharingServicePicker(items: [clip.plainText])
                if let view = NSApp.keyWindow?.contentView {
                    sharePicker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
                }
            }) {
                Label("Share…", systemImage: "square.and.arrow.up")
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
        VStack(alignment: .leading, spacing: 4) {
            Text(clip.displayTitle)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)

            let lines = clip.plainText.components(separatedBy: .newlines).dropFirst()
            let remainingText = lines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

            if !remainingText.isEmpty {
                Text(remainingText)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .lineLimit(5)
                    .lineSpacing(2)
            }
        }
    }

    private var codePreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(clip.displayTitle)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.purple)
                .lineLimit(1)

            Text(clip.plainText)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundColor(.primary.opacity(0.85))
                .lineLimit(6)
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
                        .frame(maxHeight: 110)
                        .cornerRadius(6)

                    Text("\(Int(nsImage.size.width)) × \(Int(nsImage.size.height)) pixels")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("Image")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var colorPreview: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: clip.colorHex ?? "#000000"))
                .frame(height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(clip.colorHex ?? "#000000")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)

                Text("RGB Color")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var linkPreview: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(clip.displayTitle)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(3)

            Text(clip.url ?? clip.plainText)
                .font(.system(size: 10))
                .foregroundColor(.blue)
                .lineLimit(2)
        }
    }

    private var filePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 32))
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

            Text(clip.plainText)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
    }
}
