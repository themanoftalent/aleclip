import SwiftUI

final class NewClipViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var content: String = ""
}

public struct NewClipSheet: View {
    @StateObject private var model = NewClipViewModel()

    public let onSave: (String, String) -> Void
    public let onCancel: () -> Void

    public init(onSave: @escaping (String, String) -> Void, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("New Text Item")
                    .font(.headline)
                Spacer()
                Button(loc("edit.cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(loc("edit.customTitle"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField(loc("edit.titlePlaceholder"), text: $model.title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(loc("edit.content"))
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
                Button(loc("edit.save")) {
                    let trimmed = model.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(model.title, trimmed)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
