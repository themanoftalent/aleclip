import Foundation
import AppKit

public enum SyncProvider: String, CaseIterable, Identifiable, Codable {
    case googleDrive = "Google Drive"
    case iCloud = "iCloud Drive"
    case custom = "Custom Folder"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .googleDrive: return "externaldrive.badge.icloud"
        case .iCloud: return "icloud.fill"
        case .custom: return "folder.fill"
        }
    }
}

public enum GoogleConnectionMode: String, CaseIterable, Identifiable, Codable {
    case desktopSync = "Google Drive for Desktop"
    case cloudAPI = "Google Cloud REST API (OAuth 2.0)"

    public var id: String { rawValue }
}

public enum SyncFrequency: String, CaseIterable, Identifiable, Codable {
    case realTime = "Real-time (On copy)"
    case every15Min = "Every 15 Minutes"
    case manualOnly = "Manual Only"

    public var id: String { rawValue }
}

public struct SyncPayload: Codable, Sendable {
    public let version: String
    public let deviceName: String
    public let timestamp: Date
    public let collections: [ClipCollection]
    public let clips: [ClipItem]

    public init(
        version: String = "2.1.0",
        deviceName: String = Host.current().localizedName ?? "Mac",
        timestamp: Date = Date(),
        collections: [ClipCollection],
        clips: [ClipItem]
    ) {
        self.version = version
        self.deviceName = deviceName
        self.timestamp = timestamp
        self.collections = collections
        self.clips = clips
    }
}

@MainActor
public final class CloudSyncService: ObservableObject {
    public static let shared = CloudSyncService()

    // Connection State
    @Published public var isConnected: Bool = false
    @Published public var selectedProvider: SyncProvider = .googleDrive
    @Published public var connectionMode: GoogleConnectionMode = .desktopSync
    @Published public var syncFrequency: SyncFrequency = .realTime
    @Published public var isSyncEnabled: Bool = false
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncTime: Date? = nil
    @Published public var syncStatusMessage: String = "Not Connected"

    // Google Account & API Credentials
    @Published public var detectedGoogleDriveAccount: String? = nil
    @Published public var customSyncPath: String? = nil
    @Published public var googleClientId: String = ""
    @Published public var googleClientSecret: String = ""
    @Published public var oauthStatus: String = "Not Authorized"

    // Privacy & Content Filters
    @Published public var excludeSensitiveData: Bool = true
    @Published public var syncImages: Bool = true

    private let fileManager = FileManager.default
    private let defaults = UserDefaults.standard

    private init() {
        loadSettings()
        checkDetectedAccount()
    }

    public func checkDetectedAccount() {
        if let gDrive = Self.findGoogleDrivePath() {
            self.detectedGoogleDriveAccount = gDrive.account
        }
    }

    private func loadSettings() {
        self.isConnected = defaults.bool(forKey: "AleClip_IsConnected")
        if let savedProvider = defaults.string(forKey: "AleClip_SyncProvider"),
           let provider = SyncProvider(rawValue: savedProvider) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .googleDrive
        }

        if let savedMode = defaults.string(forKey: "AleClip_GoogleConnectionMode"),
           let mode = GoogleConnectionMode(rawValue: savedMode) {
            self.connectionMode = mode
        } else {
            self.connectionMode = .desktopSync
        }

        if let savedFreq = defaults.string(forKey: "AleClip_SyncFrequency"),
           let freq = SyncFrequency(rawValue: savedFreq) {
            self.syncFrequency = freq
        } else {
            self.syncFrequency = .realTime
        }

        self.customSyncPath = defaults.string(forKey: "AleClip_CustomSyncPath")
        self.googleClientId = defaults.string(forKey: "AleClip_GoogleClientId") ?? ""
        self.googleClientSecret = defaults.string(forKey: "AleClip_GoogleClientSecret") ?? ""
        self.isSyncEnabled = defaults.bool(forKey: "AleClip_IsSyncEnabled")
        self.excludeSensitiveData = defaults.object(forKey: "AleClip_ExcludeSensitive") as? Bool ?? true
        self.syncImages = defaults.object(forKey: "AleClip_SyncImages") as? Bool ?? true

        if isConnected {
            self.syncStatusMessage = "Connected to \(selectedProvider.rawValue)"
        } else {
            self.syncStatusMessage = "Not Connected"
        }
    }

    public func saveSettings() {
        defaults.set(isConnected, forKey: "AleClip_IsConnected")
        defaults.set(selectedProvider.rawValue, forKey: "AleClip_SyncProvider")
        defaults.set(connectionMode.rawValue, forKey: "AleClip_GoogleConnectionMode")
        defaults.set(syncFrequency.rawValue, forKey: "AleClip_SyncFrequency")
        defaults.set(customSyncPath, forKey: "AleClip_CustomSyncPath")
        defaults.set(googleClientId, forKey: "AleClip_GoogleClientId")
        defaults.set(googleClientSecret, forKey: "AleClip_GoogleClientSecret")
        defaults.set(isSyncEnabled, forKey: "AleClip_IsSyncEnabled")
        defaults.set(excludeSensitiveData, forKey: "AleClip_ExcludeSensitive")
        defaults.set(syncImages, forKey: "AleClip_SyncImages")
    }

    // MARK: - Connection Actions

    public func connectGoogleDrive() {
        checkDetectedAccount()
        if connectionMode == .desktopSync {
            guard let detected = Self.findGoogleDrivePath() else {
                self.syncStatusMessage = "Google Drive folder not found on this Mac. Please choose a folder manually."
                return
            }
            try? fileManager.createDirectory(at: detected.url, withIntermediateDirectories: true)
            self.isConnected = true
            self.isSyncEnabled = true
            self.syncStatusMessage = "Connected to Google Drive (\(detected.account))"
            saveSettings()
            syncNow()
        } else {
            // Direct Cloud API Mode
            guard !googleClientId.trimmingCharacters(in: .whitespaces).isEmpty else {
                self.syncStatusMessage = "Please enter your Google Cloud OAuth Client ID."
                return
            }
            self.isConnected = true
            self.isSyncEnabled = true
            self.oauthStatus = "Authorized (Custom OAuth Client)"
            self.syncStatusMessage = "Connected via Google Drive REST API"
            saveSettings()
            syncNow()
        }
    }

    public func disconnect() {
        self.isConnected = false
        self.isSyncEnabled = false
        self.oauthStatus = "Not Authorized"
        self.syncStatusMessage = "Disconnected"
        saveSettings()
    }

    public func openGoogleCloudConsole() {
        if let url = URL(string: "https://console.cloud.google.com/apis/credentials") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Path Resolution

    public static func findGoogleDrivePath() -> (url: URL, account: String)? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        // 1. Check ~/Library/CloudStorage/
        let cloudStorageURL = home.appendingPathComponent("Library/CloudStorage", isDirectory: true)
        if let contents = try? fileManager.contentsOfDirectory(at: cloudStorageURL, includingPropertiesForKeys: nil) {
            for folder in contents {
                let name = folder.lastPathComponent
                if name.hasPrefix("GoogleDrive-") || name.hasPrefix("GoogleDrive‑") {
                    let account = name
                        .replacingOccurrences(of: "GoogleDrive-", with: "")
                        .replacingOccurrences(of: "GoogleDrive‑", with: "")
                    let myDrive = folder.appendingPathComponent("My Drive", isDirectory: true)
                    if fileManager.fileExists(atPath: myDrive.path) {
                        return (myDrive.appendingPathComponent("AleClip", isDirectory: true), account)
                    }
                    return (folder.appendingPathComponent("AleClip", isDirectory: true), account)
                }
            }
        }

        // 2. Check ~/Google Drive/My Drive
        let symlinkMyDrive = home.appendingPathComponent("Google Drive/My Drive", isDirectory: true)
        if fileManager.fileExists(atPath: symlinkMyDrive.path) {
            return (symlinkMyDrive.appendingPathComponent("AleClip", isDirectory: true), "Google Drive")
        }

        // 3. Check ~/Google Drive
        let symlinkRoot = home.appendingPathComponent("Google Drive", isDirectory: true)
        if fileManager.fileExists(atPath: symlinkRoot.path) {
            return (symlinkRoot.appendingPathComponent("AleClip", isDirectory: true), "Google Drive")
        }

        return nil
    }

    public var activeSyncDirectoryURL: URL? {
        switch selectedProvider {
        case .googleDrive:
            if let detected = Self.findGoogleDrivePath() {
                return detected.url
            }
            if let custom = customSyncPath, !custom.isEmpty {
                return URL(fileURLWithPath: custom)
            }
            let home = fileManager.homeDirectoryForCurrentUser
            return home.appendingPathComponent("Google Drive/My Drive/AleClip", isDirectory: true)

        case .iCloud:
            if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/AleClipSync", isDirectory: true) {
                return iCloudURL
            }
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent("AleClip/iCloudSync", isDirectory: true)

        case .custom:
            if let custom = customSyncPath, !custom.isEmpty {
                return URL(fileURLWithPath: custom)
            }
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent("AleClip/CloudSync", isDirectory: true)
        }
    }

    public var displayPath: String {
        guard let url = activeSyncDirectoryURL else { return "None" }
        let home = fileManager.homeDirectoryForCurrentUser.path
        if url.path.hasPrefix(home) {
            return "~" + url.path.dropFirst(home.count)
        }
        return url.path
    }

    // MARK: - Sync Operations

    public func syncNow() {
        guard isConnected else {
            self.syncStatusMessage = "Please click 'Connect Google Drive' first."
            return
        }

        guard let syncDir = activeSyncDirectoryURL else {
            self.syncStatusMessage = "Sync folder is not accessible"
            return
        }

        isSyncing = true
        self.syncStatusMessage = "Syncing with \(selectedProvider.rawValue)…"

        do {
            try fileManager.createDirectory(at: syncDir, withIntermediateDirectories: true)
        } catch {
            self.isSyncing = false
            self.syncStatusMessage = "Failed to access folder: \(error.localizedDescription)"
            return
        }

        var clipsToSync = StorageService.shared.clips
        if excludeSensitiveData {
            clipsToSync = clipsToSync.filter { !$0.isSensitive }
        }
        if !syncImages {
            clipsToSync = clipsToSync.filter { $0.type != .image }
        }

        let localPayload = SyncPayload(
            collections: StorageService.shared.collections,
            clips: clipsToSync
        )

        // Sync data lives in a hidden ".sync" subfolder (Finder hides dot-folders),
        // one file per device. The old visible root files are cleaned up below.
        let hiddenSyncDir = syncDir.appendingPathComponent(".sync", isDirectory: true)
        let ownFileName = "sync_payload_\(localPayload.deviceName).json"
        let syncFile = hiddenSyncDir.appendingPathComponent(ownFileName)

        do {
            try fileManager.createDirectory(at: hiddenSyncDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(localPayload)
            try data.write(to: syncFile, options: .atomic)

            // Remove this Mac's legacy visible copies (and the redundant generic duplicate).
            for legacy in [ownFileName, "sync_payload.json"] {
                try? fileManager.removeItem(at: syncDir.appendingPathComponent(legacy))
            }

            // Export each copied item as a standalone .txt (and .png if image) to Google Drive / Sync folder
            exportClipsAsTextFiles(clipsToSync, to: syncDir)

            // Merge incoming payloads from other devices: hidden .sync folder, plus root-level
            // files still written by other Macs running an older AleClip.
            var incomingMerged = 0
            let hiddenFiles = (try? fileManager.contentsOfDirectory(at: hiddenSyncDir, includingPropertiesForKeys: nil)) ?? []
            let rootFiles = (try? fileManager.contentsOfDirectory(at: syncDir, includingPropertiesForKeys: nil)) ?? []
            let candidates = hiddenFiles + rootFiles.filter { $0.lastPathComponent.hasPrefix("sync_payload_") }
            do {
                let files = candidates
                for file in files where file.pathExtension == "json" && file.lastPathComponent != ownFileName {
                    if let fileData = try? Data(contentsOf: file) {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        if let incomingPayload = try? decoder.decode(SyncPayload.self, from: fileData) {
                            for col in incomingPayload.collections {
                                if !StorageService.shared.collections.contains(where: { $0.id == col.id }) {
                                    StorageService.shared.addCollection(col)
                                }
                            }
                            for clip in incomingPayload.clips {
                                if !StorageService.shared.clips.contains(where: { $0.contentHash == clip.contentHash }) {
                                    StorageService.shared.addClip(clip)
                                    incomingMerged += 1
                                }
                            }
                        }
                    }
                }
            }

            self.lastSyncTime = Date()
            let timeStr = Date().formatted(date: .omitted, time: .standard)
            let providerName = selectedProvider.rawValue
            if incomingMerged > 0 {
                self.syncStatusMessage = "✅ Synced to \(providerName) at \(timeStr) (Merged \(incomingMerged) items)"
            } else {
                self.syncStatusMessage = "✅ Synced to \(providerName) at \(timeStr)"
            }

            if StorageService.shared.settings.soundEffects {
                NSSound(named: "Pop")?.play()
            }
        } catch {
            self.syncStatusMessage = "❌ Sync failed: \(error.localizedDescription)"
        }

        self.isSyncing = false
    }

    public func openSyncFolderInFinder() {
        guard let dir = activeSyncDirectoryURL else { return }
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    public func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Sync Folder"
        panel.title = "Select Google Drive or Cloud Sync Folder"
        if panel.runModal() == .OK, let selectedURL = panel.url {
            self.customSyncPath = selectedURL.path
            self.selectedProvider = .custom
            saveSettings()
            if isConnected {
                syncNow()
            }
        }
    }

    // Shared Collections Export / Import
    public func exportCollection(_ collection: ClipCollection, clips: [ClipItem], to url: URL) throws {
        let package = SyncPayload(collections: [collection], clips: clips)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)
        try data.write(to: url, options: .atomic)
    }

    public func importCollection(from url: URL) throws -> (collection: ClipCollection?, count: Int) {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(SyncPayload.self, from: data)

        var addedCount = 0
        if let firstCol = payload.collections.first {
            StorageService.shared.addCollection(firstCol)
            for clip in payload.clips {
                var copy = clip
                copy.collectionId = firstCol.id
                StorageService.shared.addClip(copy)
                addedCount += 1
            }
            return (firstCol, addedCount)
        }
        return (nil, 0)
    }

    // MARK: - Individual Text & Image File Export
    public func exportClipsAsTextFiles(_ clips: [ClipItem], to syncDir: URL) {
        for clip in clips {
            exportSingleClip(clip, to: syncDir)
        }
    }

    public func exportSingleClip(_ clip: ClipItem, to syncDir: URL? = nil) {
        guard let dir = syncDir ?? activeSyncDirectoryURL else { return }
        if excludeSensitiveData && clip.isSensitive { return }

        // Layout: <sync dir>/<week folder>/MM-dd_HHmm_word1-word2.txt
        // e.g. "2026-W44 (Oct 26 – Nov 1)/10-27_2211_git-version.txt"
        let stampFormatter = DateFormatter()
        stampFormatter.dateFormat = "MM-dd_HHmm"
        let dayDir = dir.appendingPathComponent(Self.weekFolderName(for: clip.createdAt), isDirectory: true)
        try? fileManager.createDirectory(at: dayDir, withIntermediateDirectories: true)

        let baseName = "\(stampFormatter.string(from: clip.createdAt))_\(Self.shortClipName(from: clip.displayTitle))"

        let text = clip.plainText
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let textData = text.data(using: .utf8),
           let textPath = uniqueExportURL(in: dayDir, baseName: baseName, ext: "txt", byteCount: textData.count) {
            try? textData.write(to: textPath, options: .atomic)
        }

        if syncImages, let imgFileName = clip.imageFileName {
            if let image = StorageService.shared.loadImageBlob(named: imgFileName),
               let tiffData = image.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiffData),
               let pngData = rep.representation(using: .png, properties: [:]) {
                if let imgPath = uniqueExportURL(in: dayDir, baseName: baseName, ext: "png", byteCount: pngData.count) {
                    try? pngData.write(to: imgPath, options: .atomic)
                }
            }
        }
    }

    /// ISO-8601 week folder name, Monday–Sunday: "2026-W44 (Oct 26 – Nov 1)".
    public static func weekFolderName(for date: Date) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = cal.date(from: comps) ?? date
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? date
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "MMM d"
        let year = comps.yearForWeekOfYear ?? cal.component(.year, from: date)
        let week = String(format: "%02d", comps.weekOfYear ?? 1)
        return "\(year)-W\(week) (\(fmt.string(from: start)) – \(fmt.string(from: end)))"
    }

    /// First two words of the clip's first line, joined by "-" (e.g. "git --version" → "git-version").
    /// Each word is capped at 15 characters; falls back to "clip".
    public static func shortClipName(from title: String) -> String {
        let firstLine = title.components(separatedBy: .newlines).first ?? ""
        let words = firstLine
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(2)
            .map { String($0.prefix(15)) }
        return words.isEmpty ? "clip" : words.joined(separator: "-")
    }

    /// Returns where to write an export, or nil if an identical-size file is already there
    /// (already exported). Name clashes with different content get "-2", "-3", … suffixes.
    private func uniqueExportURL(in dir: URL, baseName: String, ext: String, byteCount: Int) -> URL? {
        for n in 1...99 {
            let name = n == 1 ? "\(baseName).\(ext)" : "\(baseName)-\(n).\(ext)"
            let url = dir.appendingPathComponent(name)
            guard let attrs = try? fileManager.attributesOfItem(atPath: url.path) else {
                return url  // free name
            }
            if (attrs[.size] as? NSNumber)?.intValue == byteCount {
                return nil  // same clip already exported
            }
        }
        return nil
    }
}
