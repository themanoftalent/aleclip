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
    case code

    public var displayName: String {
        switch self {
        case .text: return loc("filter.text")
        case .richText: return loc("filter.text")
        case .html: return "HTML"
        case .image: return loc("filter.images")
        case .link: return loc("filter.links")
        case .file: return loc("filter.files")
        case .color: return loc("filter.colors")
        case .code: return "Code"
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
        case .code: return "curlybraces"
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

    // New Extended Attributes
    public var ocrText: String?
    public var detectedLanguage: String?
    public var isSensitive: Bool
    public var collectionId: UUID?
    public var sourceDevice: String?

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
        contentHash: String,
        ocrText: String? = nil,
        detectedLanguage: String? = nil,
        isSensitive: Bool = false,
        collectionId: UUID? = nil,
        sourceDevice: String? = "Mac"
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
        self.ocrText = ocrText
        self.detectedLanguage = detectedLanguage
        self.isSensitive = isSensitive
        self.collectionId = collectionId
        self.sourceDevice = sourceDevice
    }

    enum CodingKeys: String, CodingKey {
        case id, type, plainText, htmlContent, rtfData, imageFileName, url, colorHex
        case title, sourceAppBundleId, sourceAppName, createdAt, lastUsedAt, isPinned, contentHash
        case ocrText, detectedLanguage, isSensitive, collectionId, sourceDevice
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.type = try container.decodeIfPresent(ClipType.self, forKey: .type) ?? .text
        self.plainText = try container.decodeIfPresent(String.self, forKey: .plainText) ?? ""
        self.htmlContent = try container.decodeIfPresent(String.self, forKey: .htmlContent)
        self.rtfData = try container.decodeIfPresent(Data.self, forKey: .rtfData)
        self.imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.sourceAppBundleId = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleId)
        self.sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt) ?? Date()
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.contentHash = try container.decodeIfPresent(String.self, forKey: .contentHash) ?? UUID().uuidString
        self.ocrText = try container.decodeIfPresent(String.self, forKey: .ocrText)
        self.detectedLanguage = try container.decodeIfPresent(String.self, forKey: .detectedLanguage)
        self.isSensitive = try container.decodeIfPresent(Bool.self, forKey: .isSensitive) ?? false
        self.collectionId = try container.decodeIfPresent(UUID.self, forKey: .collectionId)
        self.sourceDevice = try container.decodeIfPresent(String.self, forKey: .sourceDevice) ?? "Mac"
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
        case .image:
            if let ocr = ocrText, !ocr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let firstLine = ocr.components(separatedBy: .newlines).first ?? ""
                let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return "OCR: \(trimmed)" }
            }
            return type.displayName
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
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        if let title = title, title.localizedStandardContains(trimmed) { return true }
        if plainText.localizedStandardContains(trimmed) { return true }
        if let ocr = ocrText, ocr.localizedStandardContains(trimmed) { return true }
        if let lang = detectedLanguage, lang.localizedStandardContains(trimmed) { return true }
        if let url = url, url.localizedStandardContains(trimmed) { return true }
        if let colorHex = colorHex, colorHex.localizedStandardContains(trimmed) { return true }
        if let appName = sourceAppName, appName.localizedStandardContains(trimmed) { return true }
        if let dev = sourceDevice, dev.localizedStandardContains(trimmed) { return true }
        return false
    }
}
