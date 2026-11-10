import Foundation
import AppKit

public struct AppSettings: Codable, Sendable {
    public var historyLimit: Int = 0 // 0 = Unlimited
    public var unlimitedHistory: Bool = true
    public var pasteIntoActiveApp: Bool = true
    public var plainTextAlways: Bool = false
    public var soundEffects: Bool = true
    public var launchAtLogin: Bool = true
    public var selectedShortcut: String = "⌥V (Option + V)"
    public var screenShieldPrivacy: Bool = false
    public var maskSensitiveData: Bool = true
    public var excludedBundleIds: [String] = [
        "com.agilebits.onepassword",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.apple.keychainaccess"
    ]

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.historyLimit = try container.decodeIfPresent(Int.self, forKey: .historyLimit) ?? 0
        self.unlimitedHistory = try container.decodeIfPresent(Bool.self, forKey: .unlimitedHistory) ?? (self.historyLimit == 0)
        self.pasteIntoActiveApp = try container.decodeIfPresent(Bool.self, forKey: .pasteIntoActiveApp) ?? true
        self.plainTextAlways = try container.decodeIfPresent(Bool.self, forKey: .plainTextAlways) ?? false
        self.soundEffects = try container.decodeIfPresent(Bool.self, forKey: .soundEffects) ?? true
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        self.selectedShortcut = try container.decodeIfPresent(String.self, forKey: .selectedShortcut) ?? "⌥V (Option + V)"
        self.screenShieldPrivacy = try container.decodeIfPresent(Bool.self, forKey: .screenShieldPrivacy) ?? false
        self.maskSensitiveData = try container.decodeIfPresent(Bool.self, forKey: .maskSensitiveData) ?? true
        self.excludedBundleIds = try container.decodeIfPresent([String].self, forKey: .excludedBundleIds) ?? [
            "com.agilebits.onepassword",
            "com.bitwarden.desktop",
            "org.keepassxc.keepassxc",
            "com.apple.keychainaccess"
        ]
    }
}

@MainActor
public final class StorageService: ObservableObject {
    public static let shared = StorageService()

    @Published public private(set) var clips: [ClipItem] = []
    @Published public private(set) var deletedClips: [ClipItem] = []
    @Published public private(set) var collections: [ClipCollection] = []
    @Published public var settings: AppSettings = AppSettings()

    private let fileManager = FileManager.default
    private let appSupportURL: URL
    private let historyFileURL: URL
    private let deletedHistoryFileURL: URL
    private let collectionsFileURL: URL
    private let settingsFileURL: URL
    private let blobsDirectoryURL: URL
    private let backupsDirectoryURL: URL

    private var undoStack: [(clip: ClipItem, originalIndex: Int)] = []

    /// Sync tombstones: contentHash -> when it was deleted. Shared with other devices so a
    /// deletion on one device removes the clip everywhere instead of being merged back.
    @Published public private(set) var tombstones: [String: Date] = [:]
    private var tombstonesFileURL: URL { appSupportURL.appendingPathComponent("sync_tombstones.json") }
    private static let tombstoneLifetime: TimeInterval = 60 * 60 * 24 * 60 // 60 days

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.appSupportURL = appSupport.appendingPathComponent("AleClip", isDirectory: true)
        self.historyFileURL = appSupportURL.appendingPathComponent("history.json")
        self.deletedHistoryFileURL = appSupportURL.appendingPathComponent("deleted_history.json")
        self.collectionsFileURL = appSupportURL.appendingPathComponent("collections.json")
        self.settingsFileURL = appSupportURL.appendingPathComponent("settings.json")
        self.blobsDirectoryURL = appSupportURL.appendingPathComponent("blobs", isDirectory: true)
        self.backupsDirectoryURL = appSupportURL.appendingPathComponent("backups", isDirectory: true)

        createDirectoriesIfNeeded()
        loadSettings()
        loadCollections()
        loadHistory()
        loadDeletedHistory()
        loadTombstones()
    }

    // MARK: - Sync Tombstones

    private func recordTombstones(for items: [ClipItem]) {
        guard !items.isEmpty else { return }
        let now = Date()
        for item in items {
            // Restores use a whole-second revision so ISO8601 legacy readers preserve it.
            // A subsequent deletion must not predate that revision.
            tombstones[item.contentHash] = max(now, item.lastUsedAt, tombstones[item.contentHash] ?? .distantPast)
        }
        saveTombstones()
        if CloudSyncService.shared.isConnected && CloudSyncService.shared.isSyncEnabled {
            CloudSyncService.shared.scheduleSync()
        }
    }

    private func clearTombstones(for items: [ClipItem]) {
        var changed = false
        for item in items where tombstones.removeValue(forKey: item.contentHash) != nil { changed = true }
        if changed {
            saveTombstones()
            if CloudSyncService.shared.isConnected && CloudSyncService.shared.isSyncEnabled {
                CloudSyncService.shared.scheduleSync()
            }
        }
    }

    private func saveTombstones() {
        let cutoff = Date().addingTimeInterval(-Self.tombstoneLifetime)
        tombstones = tombstones.filter { $0.value > cutoff }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(tombstones) {
            try? data.write(to: tombstonesFileURL, options: .atomic)
        }
    }

    private func loadTombstones() {
        guard let data = try? Data(contentsOf: tombstonesFileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        tombstones = (try? decoder.decode([String: Date].self, from: data)) ?? [:]
    }

    /// Merges another device's clips and deletions. Never triggers a sync itself.
    @discardableResult
    public func applyRemote(clips remoteClips: [ClipItem], tombstones remoteTombstones: [String: Date]) -> (added: Int, removed: Int) {
        var tombstonesChanged = false
        for (hash, deletedAt) in remoteTombstones {
            if let existing = tombstones[hash], existing >= deletedAt { continue }
            tombstones[hash] = deletedAt
            tombstonesChanged = true
        }

        var localHashes = Set(clips.map(\.contentHash))
        var pinsChanged = false
        var added = 0
        for clip in remoteClips {
            if let index = clips.firstIndex(where: { $0.contentHash == clip.contentHash }) {
                // Never replace the local model: another platform may omit its rich metadata.
                // Legacy payloads have no revision and cannot undo an explicit pin change.
                if let revision = clip.pinModifiedAt, revision.isFinite,
                   revision > (clips[index].pinModifiedAt ?? 0) ||
                    (revision == clips[index].pinModifiedAt && clip.isPinned && !clips[index].isPinned) {
                    clips[index].isPinned = clip.isPinned
                    clips[index].pinModifiedAt = revision
                    pinsChanged = true
                }
                continue
            }
            guard !localHashes.contains(clip.contentHash) else { continue }
            if let deletedAt = tombstones[clip.contentHash], deletedAt >= clip.lastUsedAt { continue }
            clips.append(clip)
            localHashes.insert(clip.contentHash)
            added += 1
        }
        // Reevaluate retained tombstones after pin changes. A deletion received while
        // pinned must still apply once a newer remote unpin arrives, in either order.
        let removed = clips.filter { clip in
            guard !clip.isPinned, let deletedAt = tombstones[clip.contentHash] else { return false }
            return clip.lastUsedAt <= deletedAt
        }
        if !removed.isEmpty {
            let ids = Set(removed.map(\.id))
            clips.removeAll { ids.contains($0.id) }
            deletedClips.removeAll { ids.contains($0.id) }
            deletedClips.insert(contentsOf: removed, at: 0)
            // Sync never purges recoverable history to enforce a trash size cap.
        }
        if added > 0 { clips.sort { $0.createdAt > $1.createdAt } }

        if tombstonesChanged { saveTombstones() }
        if added > 0 || !removed.isEmpty || pinsChanged {
            saveHistory()
            saveDeletedHistory()
        }
        return (added, removed.count)
    }

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: blobsDirectoryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: backupsDirectoryURL, withIntermediateDirectories: true)
    }

    // MARK: - History Operations

    private var saveDebounceWorkItem: DispatchWorkItem?

    public func scheduleSaveHistory() {
        saveDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.saveHistory()
                CloudSyncService.shared.scheduleSync()
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
            if clip.ocrText != nil { existing.ocrText = clip.ocrText }
            if clip.detectedLanguage != nil { existing.detectedLanguage = clip.detectedLanguage }
            clips.insert(existing, at: 0)
        } else {
            clips.insert(clip, at: 0)
        }
        clearTombstones(for: [clip])

        pruneHistoryIfNeeded()
        scheduleSaveHistory()

        // Sync new clip as .txt to Google Drive / Sync folder
        if CloudSyncService.shared.isConnected && CloudSyncService.shared.isSyncEnabled {
            CloudSyncService.shared.exportSingleClip(clip)
            if CloudSyncService.shared.syncFrequency == .realTime {
                CloudSyncService.shared.scheduleSync()
            }
        }
    }

    public func updateClip(_ clip: ClipItem) {
        guard let index = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        var changed = clip
        if clips[index].isPinned != clip.isPinned {
            changed.pinModifiedAt = Date().timeIntervalSince1970
        }
        clips[index] = changed
        scheduleSaveHistory()
    }

    public func togglePin(for clipId: UUID) {
        guard let index = clips.firstIndex(where: { $0.id == clipId }) else { return }
        clips[index].isPinned.toggle()
        clips[index].pinModifiedAt = Date().timeIntervalSince1970
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

    public func duplicateClip(id: UUID) {
        guard let original = clips.first(where: { $0.id == id }) else { return }
        let duplicate = original
        let newId = UUID()
        let copy = ClipItem(
            id: newId,
            type: duplicate.type,
            plainText: duplicate.plainText,
            htmlContent: duplicate.htmlContent,
            rtfData: duplicate.rtfData,
            imageFileName: duplicate.imageFileName,
            url: duplicate.url,
            colorHex: duplicate.colorHex,
            title: (duplicate.title ?? duplicate.displayTitle) + " (Copy)",
            sourceAppBundleId: duplicate.sourceAppBundleId,
            sourceAppName: duplicate.sourceAppName,
            createdAt: Date(),
            lastUsedAt: Date(),
            isPinned: false,
            contentHash: UUID().uuidString,
            ocrText: duplicate.ocrText,
            detectedLanguage: duplicate.detectedLanguage,
            isSensitive: duplicate.isSensitive,
            collectionId: duplicate.collectionId,
            sourceDevice: duplicate.sourceDevice
        )
        clips.insert(copy, at: 0)
        scheduleSaveHistory()
    }

    @discardableResult
    public func deleteClip(id: UUID, permanent: Bool = false) -> ClipItem? {
        if permanent {
            if let index = deletedClips.firstIndex(where: { $0.id == id }) {
                let removed = deletedClips.remove(at: index)
                undoStack.removeAll { $0.clip.id == id }
                cleanupBlobIfNotReferenced(filename: removed.imageFileName)
                saveDeletedHistory()
                return removed
            }
            if let index = clips.firstIndex(where: { $0.id == id }) {
                let removed = clips.remove(at: index)
                recordTombstones(for: [removed])
                undoStack.removeAll { $0.clip.id == id }
                cleanupBlobIfNotReferenced(filename: removed.imageFileName)
                scheduleSaveHistory()
                return removed
            }
            return nil
        }

        // Soft deletion
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = clips.remove(at: index)
        recordTombstones(for: [removed])

        undoStack.append((clip: removed, originalIndex: index))
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }

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
        var restored = deletedClips.remove(at: index)
        restored.lastUsedAt = Date(timeIntervalSince1970: max(ceil(Date().timeIntervalSince1970), floor(tombstones[restored.contentHash]?.timeIntervalSince1970 ?? 0) + 1))
        clearTombstones(for: [restored])
        undoStack.removeAll { $0.clip.id == id }

        clips.removeAll { $0.id == restored.id }
        clips.insert(restored, at: 0)

        scheduleSaveHistory()
        saveDeletedHistory()
        return restored
    }

    @discardableResult
    public func restoreAllDeleted() -> Int {
        guard !deletedClips.isEmpty else { return 0 }
        let count = deletedClips.count
        let restoreRevision = max(ceil(Date().timeIntervalSince1970), floor(tombstones.values.map(\.timeIntervalSince1970).max() ?? 0) + 1)
        clearTombstones(for: deletedClips)
        for var item in deletedClips.reversed() {
            item.lastUsedAt = Date(timeIntervalSince1970: restoreRevision)
            clips.removeAll { $0.id == item.id }
            clips.insert(item, at: 0)
        }
        deletedClips.removeAll()
        undoStack.removeAll()

        scheduleSaveHistory()
        saveDeletedHistory()
        return count
    }

    @discardableResult
    public func undoLastDelete() -> ClipItem? {
        guard let last = undoStack.popLast() else { return nil }
        var clip = last.clip
        clip.lastUsedAt = Date(timeIntervalSince1970: max(ceil(Date().timeIntervalSince1970), floor(tombstones[clip.contentHash]?.timeIntervalSince1970 ?? 0) + 1))
        clearTombstones(for: [clip])
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
        if CloudSyncService.shared.isConnected && CloudSyncService.shared.isSyncEnabled {
            CloudSyncService.shared.scheduleSync()
        }
    }

    public func clearUnpinned() {
        let unpinned = clips.filter { !$0.isPinned }
        recordTombstones(for: unpinned)
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

    /// Deletes many clips in one pass and saves once (fast even with very large histories).
    /// Soft deletion moves clips to the Deleted bin (capped at 100, newest kept);
    /// permanent deletion removes them from the Deleted bin and/or history for good.
    @discardableResult
    public func deleteClips(ids: Set<UUID>, permanent: Bool = false) -> Int {
        guard !ids.isEmpty else { return 0 }

        if permanent {
            let removedDeleted = deletedClips.filter { ids.contains($0.id) }
            let removedActive = clips.filter { ids.contains($0.id) }
            recordTombstones(for: removedActive)
            deletedClips.removeAll { ids.contains($0.id) }
            clips.removeAll { ids.contains($0.id) }
            undoStack.removeAll { ids.contains($0.clip.id) }
            for item in removedDeleted + removedActive {
                cleanupBlobIfNotReferenced(filename: item.imageFileName)
            }
            if !removedActive.isEmpty { saveHistory() }
            saveDeletedHistory()
            return removedDeleted.count + removedActive.count
        }

        let removed = clips.filter { ids.contains($0.id) }
        recordTombstones(for: removed)
        guard !removed.isEmpty else { return 0 }
        clips.removeAll { ids.contains($0.id) }
        undoStack.removeAll()

        deletedClips.removeAll { ids.contains($0.id) }
        deletedClips.insert(contentsOf: removed, at: 0)
        if deletedClips.count > 100 {
            let overflow = Array(deletedClips.suffix(from: 100))
            deletedClips = Array(deletedClips.prefix(100))
            for item in overflow {
                cleanupBlobIfNotReferenced(filename: item.imageFileName)
            }
        }

        saveHistory()
        saveDeletedHistory()
        return removed.count
    }

    // MARK: - Collections Management

    public func addCollection(_ collection: ClipCollection) {
        let trimmed = collection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        collections.removeAll { $0.id == collection.id || $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
        collections.append(collection)
        saveCollections()
    }

    public func removeCollection(id: UUID) {
        collections.removeAll { $0.id == id }
        // Unlink clips
        for i in clips.indices {
            if clips[i].collectionId == id {
                clips[i].collectionId = nil
            }
        }
        saveCollections()
        scheduleSaveHistory()
    }

    public func assignClip(clipId: UUID, to collectionId: UUID?) {
        guard let index = clips.firstIndex(where: { $0.id == clipId }) else { return }
        clips[index].collectionId = collectionId
        scheduleSaveHistory()
    }

    public func saveCollections() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(collections)
            try data.write(to: collectionsFileURL, options: .atomic)
        } catch {
            print("Failed to save collections: \(error)")
        }
    }

    private func loadCollections() {
        if fileManager.fileExists(atPath: collectionsFileURL.path) {
            do {
                let data = try Data(contentsOf: collectionsFileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let loaded = try decoder.decode([ClipCollection].self, from: data)

                // Deduplicate by case-insensitive name
                var unique: [ClipCollection] = []
                var seen = Set<String>()
                for col in loaded {
                    let key = col.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if !seen.contains(key) {
                        seen.insert(key)
                        unique.append(col)
                    }
                }
                self.collections = unique
            } catch {
                print("Failed to load collections: \(error)")
            }
        }

        // If empty or only test leftovers, seed the authentic diverse Paste collections with unique colors!
        if collections.isEmpty || (collections.count == 1 && collections.first?.name == "Dev Snippets") {
            self.collections = [
                ClipCollection(name: "Useful Links", icon: "link", colorHex: "#0A84FF"),
                ClipCollection(name: "Code Snippets", icon: "curlybraces", colorHex: "#30D158"),
                ClipCollection(name: "Signatures", icon: "signature", colorHex: "#FF9F0A"),
                ClipCollection(name: "Work Notes", icon: "doc.text", colorHex: "#BF5AF2")
            ]
            saveCollections()
        }
    }

    // MARK: - History Limit & Pruning

    private func pruneHistoryIfNeeded() {
        // If unlimited history is on or limit is 0, do not prune!
        if settings.unlimitedHistory || settings.historyLimit <= 0 {
            return
        }

        guard clips.count > settings.historyLimit else { return }

        // Keep pinned clips safe
        let unpinnedIndices = clips.indices.filter { !clips[$0].isPinned }
        let overflow = clips.count - settings.historyLimit

        if overflow > 0 && !unpinnedIndices.isEmpty {
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

    private func cleanupBlobIfNotReferenced(filename: String?) {
        guard let filename = filename else { return }
        let referencedInClips = clips.contains { $0.imageFileName == filename }
        let referencedInDeleted = deletedClips.contains { $0.imageFileName == filename }
        if !referencedInClips && !referencedInDeleted {
            deleteBlob(named: filename)
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

    // MARK: - Export, Import & Backups

    public func createBackup() -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: Date())
        let dest = backupsDirectoryURL.appendingPathComponent("aleclip_backup_\(dateString).json")

        do {
            try exportJSON(to: dest)
            return dest
        } catch {
            print("Backup failed: \(error)")
            return nil
        }
    }

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
