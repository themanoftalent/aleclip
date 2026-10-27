import SwiftUI

final class RenameClipViewModel: ObservableObject {
    @Published var title: String

    init(title: String) {
        self.title = title
    }
}

public struct RenameClipSheet: View {
    public let clip: ClipItem
    public let onSave: (String) -> Void
    public let onCancel: () -> Void

    @StateObject private var model: RenameClipViewModel

    public init(clip: ClipItem, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.clip = clip
        self.onSave = onSave
        self.onCancel = onCancel
        _model = StateObject(wrappedValue: RenameClipViewModel(title: clip.title ?? clip.displayTitle))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Rename Item")
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

            HStack {
                Spacer()
                Button(loc("edit.save")) {
                    onSave(model.title)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
