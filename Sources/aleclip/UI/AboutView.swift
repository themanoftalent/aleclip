import SwiftUI
import AppKit

public struct AboutView: View {
    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
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

            Text("A modern, lightweight native clipboard manager for macOS.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Divider().padding(.horizontal, 24)

            VStack(spacing: 4) {
                Text("Based on [Clipbara by mobrava](https://github.com/mobrava/Clipbara). Licensed under [GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.html).")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)

            Spacer().frame(height: 6)
        }
        .frame(width: 360, height: 260)
        .padding(16)
    }
}
