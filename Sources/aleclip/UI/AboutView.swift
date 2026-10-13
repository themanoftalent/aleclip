import SwiftUI
import AppKit

public struct AboutView: View {
    @ObservedObject private var l10n = LocalizationService.shared

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return locF("about.version", version, build)
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 4)

            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            } else {
                Image(systemName: "paperclip")
                    .font(.system(size: 54))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 3) {
                Text("AleClip")
                    .font(.system(size: 20, weight: .bold))
                Text(versionString)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Text(loc("about.tagline"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Divider().padding(.horizontal, 24)

            VStack(spacing: 4) {
                Text(loc("about.developedBy"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)

            Spacer().frame(height: 6)
        }
        .frame(width: 360, height: 260)
        .padding(16)
    }
}
