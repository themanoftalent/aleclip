import Foundation
import AppKit

public enum ClipType: String, Codable, CaseIterable, Sendable {
    case text
    case richText
    case html
    case image
    case link
    case file
    case color

    public var displayName: String {
        switch self {
        case .text: return "Text"
        case .richText: return "Rich Text"
        case .html: return "HTML"
        case .image: return "Image"
        case .link: return "Link"
        case .file: return "File"
        case .color: return "Color"
        }
    }

    public var iconName: String {
        switch self {
        case .text: return "doc.text"
        case .richText: return "text.quote"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        case .link: return "link"
        case .file: return "doc"
        case .color: return "paintpalette"
        }
    }
}

public struct ClipItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var type: ClipType
    public var plainText: String
    public var htmlContent: String?
    public var rtfData: Data?
    public var imageFileName: String?
    public var url: String?
    public var colorHex: String?
    public var title: String?
    public var sourceAppBundleId: String?
    public var sourceAppName: String?
    public var createdAt: Date
    public var lastUsedAt: Date
    public var isPinned: Bool
    public var contentHash: String

    public init(
        id: UUID = UUID(),
        type: ClipType,
        plainText: String,
        htmlContent: String? = nil,
        rtfData: Data? = nil,
        imageFileName: String? = nil,
        url: String? = nil,
        colorHex: String? = nil,
        title: String? = nil,
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        isPinned: Bool = false,
        contentHash: String
    ) {
        self.id = id
        self.type = type
        self.plainText = plainText
        self.htmlContent = htmlContent
        self.rtfData = rtfData
        self.imageFileName = imageFileName
        self.url = url
        self.colorHex = colorHex
        self.title = title
        self.sourceAppBundleId = sourceAppBundleId
        self.sourceAppName = sourceAppName
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.isPinned = isPinned
        self.contentHash = contentHash
    }

    public var displayTitle: String {
        if let customTitle = title, !customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customTitle
        }
        switch type {
        case .color:
            return colorHex ?? "Color"
        case .file:
            if let url = url, let lastComp = URL(string: url)?.lastPathComponent {
                return lastComp
            }
            return plainText
        case .link:
            return url ?? plainText
        default:
            let firstLine = plainText.components(separatedBy: .newlines).first ?? ""
            let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? type.displayName : trimmed
        }
    }

    public var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    public func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty { return true }
        if let title = title, title.lowercased().contains(trimmed) { return true }
        if plainText.lowercased().contains(trimmed) { return true }
        if let url = url, url.lowercased().contains(trimmed) { return true }
        if let colorHex = colorHex, colorHex.lowercased().contains(trimmed) { return true }
        if let appName = sourceAppName, appName.lowercased().contains(trimmed) { return true }
        return false
    }
}
