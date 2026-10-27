import SwiftUI

final class NewCollectionViewModel: ObservableObject {
    @Published var collectionName: String = ""
    @Published var selectedIcon: String = "pin.fill"
    @Published var selectedColorHex: String = "#0A84FF"
}

public struct NewCollectionSheet: View {
    @StateObject private var model = NewCollectionViewModel()

    public let onSave: (String, String, String) -> Void
    public let onCancel: () -> Void

    private let availableIcons = [
        "pin.fill", "folder.fill", "tag.fill", "star.fill",
        "bookmark.fill", "curlybraces", "doc.text.fill", "sparkles", "link"
    ]

    private let colorPalette = [
        "#0A84FF", // Blue
        "#BF5AF2", // Purple
        "#FF9F0A", // Orange
        "#30D158", // Green
        "#FF375F", // Red/Pink
        "#64D2FF", // Teal
        "#FFD60A", // Gold
        "#5E5CE6"  // Indigo
    ]

    public init(onSave: @escaping (String, String, String) -> Void, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "pin.fill")
                        .foregroundColor(Color(hex: model.selectedColorHex))
                    Text("New Pinboard")
                        .font(.headline)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Pinboard Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g. Snippets, Work, Design, Templates", text: $model.collectionName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Theme Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 10) {
                    ForEach(colorPalette, id: \.self) { hex in
                        Button(action: { model.selectedColorHex = hex }) {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: model.selectedColorHex == hex ? 2.5 : 0)
                                )
                                .shadow(color: Color(hex: hex).opacity(0.4), radius: model.selectedColorHex == hex ? 4 : 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Icon")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 10) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button(action: { model.selectedIcon = icon }) {
                            Image(systemName: icon)
                                .font(.system(size: 14))
                                .frame(width: 30, height: 30)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(model.selectedIcon == icon ? Color(hex: model.selectedColorHex).opacity(0.2) : Color.primary.opacity(0.06))
                                )
                                .foregroundColor(model.selectedIcon == icon ? Color(hex: model.selectedColorHex) : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Create Pinboard") {
                    let trimmed = model.collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed, model.selectedIcon, model.selectedColorHex)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.collectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
