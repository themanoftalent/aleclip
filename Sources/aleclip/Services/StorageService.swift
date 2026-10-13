import Foundation
import AppKit

public struct AppSettings: Codable, Sendable {
    public var historyLimit: Int = 200
    public var pasteIntoActiveApp: Bool = true
    public var plainTextAlways: Bool = false
    public var soundEffects: Bool = true
    public var selectedShortcut: String = "⌥V (Option + V)"
    public var excludedBundleIds: [String] = [
        "com.agilebits.onepassword",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.apple.keychainaccess"
    ]
}

@MainActor
public final class StorageService: ObservableObject {
    public static let shared = StorageService()

    @Published public private(set) var clips: [ClipItem] = []
    @Published public var settings: AppSettings = AppSettings()

    private let fileManager = FileManager.default
    private let appSupportURL: URL
    private let historyFileURL: URL
    private let settingsFileURL: URL
    private let blobsDirectoryURL: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.appSupportURL = appSupport.appendingPathComponent("AleClip", isDirectory: true)
        self.historyFileURL = appSupportURL.appendingPathComponent("history.json")
        self.settingsFileURL = appSupportURL.appendingPathComponent("settings.json")
        self.blobsDirectoryURL = appSupportURL.appendingPathComponent("blobs", isDirectory: true)

        createDirectoriesIfNeeded()
        loadSettings()
        loadHistory()
    }

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: blobsDirectoryURL, withIntermediateDirectories: true)
    }

    // MARK: - History Operations

    public func addClip(_ clip: ClipItem) {
        // Check for deduplication
        if let existingIndex = clips.firstIndex(where: { $0.contentHash == clip.contentHash }) {
            var existing = clips.remove(at: existingIndex)
            existing.lastUsedAt = Date()
            existing.createdAt = Date() // Move to top of recent
            clips.insert(existing, at: 0)
        } else {
            clips.insert(clip, at: 0)
        }

        pruneHistoryIfNeeded()
        saveHistory()
    }

    public func togglePin(for clipId: UUID) {
        guard let index = clips.firstIndex(where: { $0.id == clipId }) else { return }
        clips[index].isPinned.toggle()
        saveHistory()
    }

    public func renameClip(id: UUID, newTitle: String) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newTitle
        saveHistory()
    }

    public func updatePlainText(id: UUID, newText: String) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].plainText = newText
        clips[index].lastUsedAt = Date()
        saveHistory()
    }

    public func deleteClip(id: UUID) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        let removed = clips.remove(at: index)
        if let imageFileName = removed.imageFileName {
            deleteBlob(named: imageFileName)
        }
        saveHistory()
    }

    public func clearUnpinned() {
        let unpinned = clips.filter { !$0.isPinned }
        for item in unpinned {
            if let imageFileName = item.imageFileName {
                deleteBlob(named: imageFileName)
            }
        }
        clips.removeAll { !$0.isPinned }
        saveHistory()
    }

    private func pruneHistoryIfNeeded() {
        guard clips.count > settings.historyLimit else { return }

        // Keep pinned clips safe
        let unpinnedIndices = clips.indices.filter { !clips[$0].isPinned }
        let overflow = clips.count - settings.historyLimit

        if overflow > 0 && !unpinnedIndices.isEmpty {
            // Remove from the end (oldest)
            let toRemove = unpinnedIndices.suffix(overflow)
            var idsToRemove: Set<UUID> = []
            for idx in toRemove {
                idsToRemove.insert(clips[idx].id)
                if let imageFileName = clips[idx].imageFileName {
                    deleteBlob(named: imageFileName)
                }
            }
            clips.removeAll { idsToRemove.contains($0.id) }
        }
    }

    // MARK: - Blob Storage (Images)

    public func saveImageBlob(_ data: Data) -> String? {
        let filename = "\(UUID().uuidString).png"
        let fileURL = blobsDirectoryURL.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return filename
        } catch {
            print("Failed to save image blob: \(error)")
            return nil
        }
    }

    public func loadImageBlob(named filename: String) -> NSImage? {
        let fileURL = blobsDirectoryURL.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return NSImage(contentsOf: fileURL)
    }

    private func deleteBlob(named filename: String) {
        let fileURL = blobsDirectoryURL.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    // MARK: - Persistence

    public func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(clips)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed to save history: \(error)")
        }
    }

    private func loadHistory() {
        guard fileManager.fileExists(atPath: historyFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.clips = try decoder.decode([ClipItem].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
        }
    }

    public func saveSettings() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(settings)
            try data.write(to: settingsFileURL, options: .atomic)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }

    private func loadSettings() {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else {
            saveSettings()
            return
        }
        do {
            let data = try Data(contentsOf: settingsFileURL)
            self.settings = try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            print("Failed to load settings: \(error)")
        }
    }

    // MARK: - Export & Import

    public func exportJSON(to targetURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(clips)
        try data.write(to: targetURL, options: .atomic)
    }

    public func importJSON(from sourceURL: URL) throws -> Int {
        let data = try Data(contentsOf: sourceURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode([ClipItem].self, from: data)

        var addedCount = 0
        let existingHashes = Set(clips.map { $0.contentHash })

        for item in imported {
            if !existingHashes.contains(item.contentHash) {
                clips.append(item)
                addedCount += 1
            }
        }

        pruneHistoryIfNeeded()
        saveHistory()
        return addedCount
    }
}
