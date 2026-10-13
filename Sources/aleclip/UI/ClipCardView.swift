import SwiftUI
import AppKit

final class HoverViewModel: ObservableObject {
    @Published var isHovered: Bool = false
}

public struct ClipCardView: View {
    public let clip: ClipItem
    public let isSelected: Bool
    public let onSelect: () -> Void
    public let onPaste: () -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void
    public let onQuickLook: () -> Void
    public let onEdit: () -> Void

    @StateObject private var hoverModel = HoverViewModel()

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Type badge & Pin & Relative Time
            HStack(spacing: 6) {
                Image(systemName: clip.type.iconName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(typeColor)

                Text(clip.type.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Text(clip.relativeTimeString)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                Button(action: onTogglePin) {
                    Image(systemName: clip.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10))
                        .foregroundColor(clip.isPinned ? .orange : .secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            // Body Preview
            contentPreview
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

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
                        Button(action: onQuickLook) {
                            Image(systemName: "eye")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Quick Look (Space)")

                        if clip.type == .text || clip.type == .richText {
                            Button(action: onEdit) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Edit (⌘E)")
                        }

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help("Delete (⌫)")
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 190, height: 135)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color(nsColor: .controlBackgroundColor).opacity(0.9) : Color(nsColor: .windowBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor : (hoverModel.isHovered ? Color.primary.opacity(0.2) : Color.primary.opacity(0.08)),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: isSelected ? Color.accentColor.opacity(0.25) : Color.black.opacity(0.1), radius: isSelected ? 6 : 2, x: 0, y: 2)
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
            Button("Paste into Active App") {
                onPaste()
            }
            Button("Copy to Clipboard") {
                PasteService.shared.copyToClipboard(clip)
            }
            Button(clip.isPinned ? "Unpin Clip" : "Pin Clip") {
                onTogglePin()
            }
            if clip.type == .text || clip.type == .richText {
                Button("Edit Text...") {
                    onEdit()
                }
            }
            Button("Quick Look Preview") {
                onQuickLook()
            }
            Divider()
            Button("Delete Clip", role: .destructive) {
                onDelete()
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
                    Text("RGB Color")
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
            VStack(alignment: .leading, spacing: 2) {
                if let title = clip.title {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                Text(clip.plainText)
                    .font(.system(size: 10, design: .default))
                    .foregroundColor(.primary.opacity(0.85))
                    .lineLimit(clip.title != nil ? 3 : 4)
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
        case .color: return .pink
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
