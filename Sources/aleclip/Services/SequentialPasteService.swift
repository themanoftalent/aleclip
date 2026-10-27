import Foundation
import AppKit

@MainActor
public final class SequentialPasteService: ObservableObject {
    public static let shared = SequentialPasteService()

    @Published public var isQueueActive: Bool = false
    @Published public private(set) var queue: [ClipItem] = []
    @Published public var isFIFO: Bool = true // FIFO vs LIFO

    private init() {}

    public func toggleQueueMode() {
        isQueueActive.toggle()
        if !isQueueActive {
            queue.removeAll()
        }
    }

    public func addToQueue(_ clip: ClipItem) {
        guard isQueueActive else { return }
        queue.append(clip)
    }

    public func popNext() -> ClipItem? {
        guard isQueueActive, !queue.isEmpty else { return nil }
        if isFIFO {
            return queue.removeFirst()
        } else {
            return queue.removeLast()
        }
    }

    public func clearQueue() {
        queue.removeAll()
        isQueueActive = false
    }

    public var queueStatusDescription: String {
        guard isQueueActive else { return "" }
        if queue.isEmpty {
            return "Sequential Queue: Empty (copy items to queue)"
        }
        return "Sequential Queue: \(queue.count) item\(queue.count == 1 ? "" : "s") left"
    }
}
