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
    @Published public private(set) var deletedClips: [ClipItem] = []
    @Published public var settings: AppSettings = AppSettings()

    private let fileManager = FileManager.default
    private let appSupportURL: URL
    private let historyFileURL: URL
    private let deletedHistoryFileURL: URL
    private let settingsFileURL: URL
    private let blobsDirectoryURL: URL

    private var undoStack: [(clip: ClipItem, originalIndex: Int)] = []

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.appSupportURL = appSupport.appendingPathComponent("AleClip", isDirectory: true)
        self.historyFileURL = appSupportURL.appendingPathComponent("history.json")
        self.deletedHistoryFileURL = appSupportURL.appendingPathComponent("deleted_history.json")
        self.settingsFileURL = appSupportURL.appendingPathComponent("settings.json")
        self.blobsDirectoryURL = appSupportURL.appendingPathComponent("blobs", isDirectory: true)

        createDirectoriesIfNeeded()
        loadSettings()
        loadHistory()
        loadDeletedHistory()
    }

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: blobsDirectoryURL, withIntermediateDirectories: true)
    }

    // MARK: - History Operations

    private var saveDebounceWorkItem: DispatchWorkItem?

    public func scheduleSaveHistory() {
        saveDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.saveHistory()
            }
        }
        saveDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }

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
        scheduleSaveHistory()
    }

    public func togglePin(for clipId: UUID) {
        guard let index = clips.firstIndex(where: { $0.id == clipId }) else { return }
        clips[index].isPinned.toggle()
        scheduleSaveHistory()
    }

    public func renameClip(id: UUID, newTitle: String) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newTitle
        scheduleSaveHistory()
    }

    public func updatePlainText(id: UUID, newText: String) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].plainText = newText
        clips[index].lastUsedAt = Date()
        scheduleSaveHistory()
    }

    @discardableResult
    public func deleteClip(id: UUID, permanent: Bool = false) -> ClipItem? {
        if permanent {
            // Check in deletedClips first
            if let index = deletedClips.firstIndex(where: { $0.id == id }) {
                let removed = deletedClips.remove(at: index)
                undoStack.removeAll { $0.clip.id == id }
                cleanupBlobIfNotReferenced(filename: removed.imageFileName)
                saveDeletedHistory()
                return removed
            }
            // Check in active clips
            if let index = clips.firstIndex(where: { $0.id == id }) {
                let removed = clips.remove(at: index)
                undoStack.removeAll { $0.clip.id == id }
                cleanupBlobIfNotReferenced(filename: removed.imageFileName)
                scheduleSaveHistory()
                return removed
            }
            return nil
        }

        // Soft deletion: move from clips to deletedClips and push to undoStack
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = clips.remove(at: index)

        // Push to undo stack (capped at 50)
        undoStack.append((clip: removed, originalIndex: index))
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }

        // Add to deleted clips (at front, capped at 100)
        deletedClips.removeAll { $0.id == removed.id }
        deletedClips.insert(removed, at: 0)
        if deletedClips.count > 100 {
            let overflow = deletedClips.suffix(from: 100)
            for item in overflow {
                cleanupBlobIfNotReferenced(filename: item.imageFileName)
            }
            deletedClips = Array(deletedClips.prefix(100))
        }

        scheduleSaveHistory()
        saveDeletedHistory()
        return removed
    }

    @discardableResult
    public func restoreClip(id: UUID) -> ClipItem? {
        guard let index = deletedClips.firstIndex(where: { $0.id == id }) else { return nil }
        let restored = deletedClips.remove(at: index)
        undoStack.removeAll { $0.clip.id == id }

        clips.removeAll { $0.id == restored.id }
        clips.insert(restored, at: 0)

        scheduleSaveHistory()
        saveDeletedHistory()
        return restored
    }

    @discardableResult
    public func undoLastDelete() -> ClipItem? {
        guard let last = undoStack.popLast() else { return nil }
        let clip = last.clip
        let targetIndex = min(last.originalIndex, clips.count)

        deletedClips.removeAll { $0.id == clip.id }
        clips.removeAll { $0.id == clip.id }
        clips.insert(clip, at: targetIndex)

        scheduleSaveHistory()
        saveDeletedHistory()
        return clip
    }

    public func emptyTrash() {
        for item in deletedClips {
            cleanupBlobIfNotReferenced(filename: item.imageFileName)
        }
        deletedClips.removeAll()
        undoStack.removeAll()
        saveDeletedHistory()
    }

    public func clearUnpinned() {
        let unpinned = clips.filter { !$0.isPinned }
        for item in unpinned {
            deletedClips.removeAll { $0.id == item.id }
            deletedClips.insert(item, at: 0)
        }
        clips.removeAll { !$0.isPinned }

        if deletedClips.count > 100 {
            let overflow = deletedClips.suffix(from: 100)
            for item in overflow {
                cleanupBlobIfNotReferenced(filename: item.imageFileName)
            }
            deletedClips = Array(deletedClips.prefix(100))
        }

        saveHistory()
        saveDeletedHistory()
    }

    private func cleanupBlobIfNotReferenced(filename: String?) {
        guard let filename = filename else { return }
        let referencedInClips = clips.contains { $0.imageFileName == filename }
        let referencedInDeleted = deletedClips.contains { $0.imageFileName == filename }
        if !referencedInClips && !referencedInDeleted {
            deleteBlob(named: filename)
        }
    }

    private func pruneHistoryIfNeeded() {
        guard clips.count > settings.historyLimit else { return }

        // Keep pinned clips safe
        let unpinnedIndices = clips.indices.filter { !clips[$0].isPinned }
        let overflow = clips.count - settings.historyLimit

        if overflow > 0 && !unpinnedIndices.isEmpty {
            // Move excess oldest unpinned to deletedClips
            let toRemove = unpinnedIndices.suffix(overflow)
            var idsToRemove: Set<UUID> = []
            for idx in toRemove {
                idsToRemove.insert(clips[idx].id)
                deletedClips.removeAll { $0.id == clips[idx].id }
                deletedClips.insert(clips[idx], at: 0)
            }
            clips.removeAll { idsToRemove.contains($0.id) }

            if deletedClips.count > 100 {
                let extra = deletedClips.suffix(from: 100)
                for item in extra {
                    cleanupBlobIfNotReferenced(filename: item.imageFileName)
                }
                deletedClips = Array(deletedClips.prefix(100))
            }
            saveDeletedHistory()
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
            print("Failed to load history: \(error). Preserving corrupted file backup.")
            let timestamp = Int(Date().timeIntervalSince1970)
            let backupURL = appSupportURL.appendingPathComponent("history.corrupt.\(timestamp).bak")
            try? fileManager.copyItem(at: historyFileURL, to: backupURL)
            self.clips = []
        }
    }

    public func saveDeletedHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(deletedClips)
            try data.write(to: deletedHistoryFileURL, options: .atomic)
        } catch {
            print("Failed to save deleted history: \(error)")
        }
    }

    private func loadDeletedHistory() {
        guard fileManager.fileExists(atPath: deletedHistoryFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: deletedHistoryFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.deletedClips = try decoder.decode([ClipItem].self, from: data)
        } catch {
            print("Failed to load deleted history: \(error)")
            self.deletedClips = []
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
