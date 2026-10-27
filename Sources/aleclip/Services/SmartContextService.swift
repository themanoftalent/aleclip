import Foundation
import AppKit

public enum AppWorkContext: String, Sendable {
    case development
    case browsing
    case communication
    case productivity
    case general

    public var title: String {
        switch self {
        case .development: return "Coding & Development"
        case .browsing: return "Web & Research"
        case .communication: return "Messaging & Email"
        case .productivity: return "Office & Documents"
        case .general: return "All Contexts"
        }
    }
}

@MainActor
public final class SmartContextService: ObservableObject {
    public static let shared = SmartContextService()

    private init() {}

    public func determineContext(for app: NSRunningApplication?) -> AppWorkContext {
        guard let bundleId = app?.bundleIdentifier?.lowercased() else { return .general }

        if bundleId.contains("xcode") || bundleId.contains("vscode") || bundleId.contains("cursor") ||
            bundleId.contains("terminal") || bundleId.contains("iterm") || bundleId.contains("clion") {
            return .development
        }

        if bundleId.contains("safari") || bundleId.contains("chrome") || bundleId.contains("firefox") ||
            bundleId.contains("brave") || bundleId.contains("arc") || bundleId.contains("edge") {
            return .browsing
        }

        if bundleId.contains("slack") || bundleId.contains("mail") || bundleId.contains("messages") ||
            bundleId.contains("discord") || bundleId.contains("telegram") || bundleId.contains("teams") {
            return .communication
        }

        if bundleId.contains("pages") || bundleId.contains("keynote") || bundleId.contains("numbers") ||
            bundleId.contains("word") || bundleId.contains("excel") || bundleId.contains("notes") {
            return .productivity
        }

        return .general
    }

    public func rankClipsForContext(_ clips: [ClipItem], context: AppWorkContext) -> [ClipItem] {
        switch context {
        case .development:
            return clips.filter { $0.type == .code || $0.type == .color || ($0.detectedLanguage != nil) }
        case .browsing:
            return clips.filter { $0.type == .link || $0.type == .image || $0.ocrText != nil }
        case .communication:
            return clips.filter { $0.type == .text || $0.type == .link }
        case .productivity:
            return clips.filter { $0.type == .text || $0.type == .file || $0.type == .richText }
        case .general:
            return clips
        }
    }
}
