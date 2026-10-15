import SwiftUI
import AppKit

public struct QuickLookOverlay: View {
    public let clip: ClipItem
    public let onDismiss: () -> Void
    public let onPaste: () -> Void

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: clip.type.iconName)
                    .foregroundColor(.accentColor)
                Text(clip.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if let appName = clip.sourceAppName {
                    Text(appName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }

                Text(clip.relativeTimeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))

            Divider()

            // Main Preview Area
            Group {
                switch clip.type {
                case .image:
                    imagePreview
                case .color:
                    colorPreview
                case .link:
                    linkPreview
                case .file:
                    filePreview
                case .text, .richText, .html:
                    textPreview
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)

            Divider()

            // Footer
            HStack {
                Text(loc("quicklook.footerHint"))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Button(loc("quicklook.copy")) {
                    PasteService.shared.copyToClipboard(clip)
                    onDismiss()
                }
                .keyboardShortcut("c", modifiers: .command)

                Button(loc("quicklook.pasteIntoApp")) {
                    onPaste()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
        }
        .frame(width: 580, height: 380)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }

    private var textPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                Text(clip.plainText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            HStack {
                Text(locF("quicklook.stats", clip.plainText.count, clip.plainText.split { $0.isWhitespace }.count))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }

    private var imagePreview: some View {
        Group {
            if let filename = clip.imageFileName,
               let nsImage = StorageService.shared.loadImageBlob(named: filename) {
                VStack(spacing: 8) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Text("\(Int(nsImage.size.width)) × \(Int(nsImage.size.height)) px")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(loc("quicklook.noImageData"))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var colorPreview: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(colorFromHex(clip.colorHex ?? "#000000"))
                .frame(width: 120, height: 120)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.2), lineWidth: 1))
                .shadow(radius: 6)

            VStack(spacing: 4) {
                Text(clip.colorHex ?? "#000000")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))

                Button(loc("quicklook.copyHex")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(clip.colorHex ?? "", forType: .string)
                }
                .buttonStyle(.link)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var linkPreview: some View {
        VStack(spacing: 16) {
            Image(systemName: "safari.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text(clip.url ?? clip.plainText)
                .font(.headline)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .padding(.horizontal)

            if let urlString = clip.url, let url = URL(string: urlString) {
                Button(loc("quicklook.openBrowser")) {
                    NSWorkspace.shared.open(url)
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filePreview: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text(clip.displayTitle)
                .font(.headline)

            Text(clip.plainText)
                .font(.caption)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let urlString = clip.url, let fileURL = URL(string: urlString) {
                Button(loc("quicklook.revealFinder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
