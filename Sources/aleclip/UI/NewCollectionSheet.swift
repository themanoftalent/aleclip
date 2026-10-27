import SwiftUI

final class NewCollectionViewModel: ObservableObject {
    @Published var collectionName: String = ""
    @Published var selectedIcon: String = "folder.fill"
    @Published var selectedColor: String = "blue"
}

public struct NewCollectionSheet: View {
    @StateObject private var model = NewCollectionViewModel()

    public let onSave: (String, String, String) -> Void
    public let onCancel: () -> Void

    private let availableIcons = [
        "folder.fill", "tag.fill", "star.fill", "bookmark.fill",
        "curlybraces", "doc.text.fill", "link", "sparkles"
    ]

    public init(onSave: @escaping (String, String, String) -> Void, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("New Collection")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Collection Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g. Work Snippets, Templates", text: $model.collectionName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Icon")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button(action: { model.selectedIcon = icon }) {
                            Image(systemName: icon)
                                .font(.system(size: 16))
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(model.selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.06))
                                )
                                .foregroundColor(model.selectedIcon == icon ? .accentColor : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Create Collection") {
                    let trimmed = model.collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed, model.selectedIcon, model.selectedColor)
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
