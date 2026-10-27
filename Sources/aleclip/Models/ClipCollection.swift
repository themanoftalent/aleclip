import Foundation

public struct ClipCollection: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var icon: String
    public var color: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder.fill",
        color: String = "blue",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.createdAt = createdAt
    }
}
