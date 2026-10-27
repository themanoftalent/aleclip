import Foundation
import SwiftUI

public struct ClipCollection: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var icon: String
    public var colorHex: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "pin.fill",
        colorHex: String = "#0A84FF",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, icon, colorHex, color, createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Pinboard"
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "pin.fill"
        if let hex = try container.decodeIfPresent(String.self, forKey: .colorHex) {
            self.colorHex = hex
        } else if let colName = try container.decodeIfPresent(String.self, forKey: .color) {
            self.colorHex = ClipCollection.hexForColorName(colName)
        } else {
            self.colorHex = "#0A84FF"
        }
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(icon, forKey: .icon)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(createdAt, forKey: .createdAt)
    }

    public static func hexForColorName(_ name: String) -> String {
        switch name.lowercased() {
        case "blue": return "#0A84FF"
        case "purple": return "#BF5AF2"
        case "orange": return "#FF9F0A"
        case "green": return "#30D158"
        case "red", "pink": return "#FF375F"
        case "teal": return "#64D2FF"
        case "yellow": return "#FFD60A"
        case "indigo": return "#5E5CE6"
        default: return "#0A84FF"
        }
    }

    public var swiftColor: Color {
        Color(hex: colorHex)
    }
}

public extension Color {
    init(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }
        let scanner = Scanner(string: cleanHex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
