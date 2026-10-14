import SwiftUI
import AppKit

final class HoverViewModel: ObservableObject {
    @Published var isHovered: Bool = false
}

public struct ClipCardView: View {
    public let clip: ClipItem
    public let shortcutNumber: Int?
    public let isSelected: Bool
    public let isDeleted: Bool
    public let onSelect: () -> Void
    public let onPaste: () -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void
    public let onRestore: (() -> Void)?
    public let onQuickLook: () -> Void
    public let onEdit: () -> Void

    public init(
        clip: ClipItem,
        shortcutNumber: Int? = nil,
        isSelected: Bool,
        isDeleted: Bool = false,
        onSelect: @escaping () -> Void,
        onPaste: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onRestore: (() -> Void)? = nil,
        onQuickLook: @escaping () -> Void,
        onEdit: @escaping () -> Void
    ) {
        self.clip = clip
        self.shortcutNumber = shortcutNumber
        self.isSelected = isSelected
        self.isDeleted = isDeleted
        self.onSelect = onSelect
        self.onPaste = onPaste
        self.onTogglePin = onTogglePin
        self.onDelete = onDelete
        self.onRestore = onRestore
        self.onQuickLook = onQuickLook
        self.onEdit = onEdit
    }

    @StateObject private var hoverModel = HoverViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Type badge & Pin & Relative Time
            HStack(spacing: 5) {
                Image(systemName: clip.type.iconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(typeColor)

                Text(clip.type.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.85))

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

            // Body Preview (vertically balanced with frame alignment)
            contentPreview
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            // Footer: Source App & Actions
            HStack(spacing: 4) {
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

                            if clip.type == .text || clip.type == .richText {
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
        .frame(width: 190, height: 135)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? Color(nsColor: .controlBackgroundColor)
                            : (reduceTransparency ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.95 : 0.90))
                    )

                if isSelected {
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
                    isSelected
                        ? Color.accentColor
                        : (clip.isPinned
                            ? Color.orange.opacity(0.4)
                            : (hoverModel.isHovered
                                ? Color.primary.opacity(0.28)
                                : Color.primary.opacity(colorSchemeContrast == .increased ? 0.35 : 0.15))),
                    lineWidth: isSelected ? (colorSchemeContrast == .increased ? 2.5 : 2) : 1
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
            onSelect()
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
            if isDeleted {
                if let onRestore = onRestore {
                    Button(loc("context.restore")) {
                        onRestore()
                    }
                }
                Button(loc("context.copy")) {
                    PasteService.shared.copyToClipboard(clip)
                }
                Button(loc("context.quickLook")) {
                    onQuickLook()
                }
                Divider()
                Button(loc("context.permanentlyDelete"), role: .destructive) {
                    onDelete()
                }
            } else {
                Button(loc("context.paste")) {
                    onPaste()
                }
                Button(loc("context.copy")) {
                    PasteService.shared.copyToClipboard(clip)
                }
                Button(loc(clip.isPinned ? "context.unpin" : "context.pin")) {
                    onTogglePin()
                }
                if clip.type == .text || clip.type == .richText {
                    Button(loc("context.editText")) {
                        onEdit()
                    }
                }
                Button(loc("context.quickLook")) {
                    onQuickLook()
                }
                Divider()
                Button(loc("context.delete"), role: .destructive) {
                    onDelete()
                }
            }
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch clip.type {
        case .color:
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorFromHex(clip.colorHex ?? "#000000"))
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(clip.colorHex ?? "#000000")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Text(loc("card.rgbColor"))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

        case .image:
            if let filename = clip.imageFileName,
               let nsImage = StorageService.shared.loadImageBlob(named: filename) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(6)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .file:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    Text(clip.displayTitle)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(2)
                }
                Text(clip.plainText)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

        case .link:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                    Text(URL(string: clip.url ?? "")?.host ?? "Website Link")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                Text(clip.url ?? clip.plainText)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

        case .text, .richText, .html:
            VStack(alignment: .leading, spacing: 3) {
                if let title = clip.title {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                Text(clip.plainText)
                    .font(.system(size: 10.5))
                    .foregroundColor(.primary)
                    .lineLimit(clip.title != nil ? 4 : 5)
                    .truncationMode(.tail)
            }
        }
    }

    private var typeColor: Color {
        switch clip.type {
        case .text: return .blue
        case .richText: return .indigo
        case .html: return .purple
        case .image: return .green
        case .link: return .teal
        case .file: return .orange
        case .color: return .cyan
        }
    }

    private func colorFromHex(_ hex: String) -> Color {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }
        guard cleanHex.count == 6, let rgbValue = UInt32(cleanHex, radix: 16) else { return .black }
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
