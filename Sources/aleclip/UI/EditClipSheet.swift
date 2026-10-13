import SwiftUI

final class EditClipViewModel: ObservableObject {
    @Published var title: String
    @Published var content: String

    init(title: String, content: String) {
        self.title = title
        self.content = content
    }
}

public struct EditClipSheet: View {
    public let clip: ClipItem
    public let onSave: (String, String) -> Void
    public let onCancel: () -> Void

    @StateObject private var model: EditClipViewModel

    public init(clip: ClipItem, onSave: @escaping (String, String) -> Void, onCancel: @escaping () -> Void) {
        self.clip = clip
        self.onSave = onSave
        self.onCancel = onCancel
        _model = StateObject(wrappedValue: EditClipViewModel(
            title: clip.title ?? "",
            content: clip.plainText
        ))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Edit Clip")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Title (Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Clip title...", text: $model.title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Content")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $model.content)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )
            }

            HStack {
                Spacer()
                Button("Save Changes") {
                    onSave(model.title, model.content)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 480, height: 340)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
