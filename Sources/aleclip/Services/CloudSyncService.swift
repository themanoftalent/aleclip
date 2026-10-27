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

    @Published public var selectedProvider: SyncProvider = .googleDrive
    @Published public var isSyncEnabled: Bool = true
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncTime: Date? = nil
    @Published public var syncStatusMessage: String = "Ready to sync"
    @Published public var detectedGoogleDriveAccount: String? = nil
    @Published public var customSyncPath: String? = nil

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
        if let savedProvider = defaults.string(forKey: "AleClip_SyncProvider"),
           let provider = SyncProvider(rawValue: savedProvider) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .googleDrive
        }
        self.customSyncPath = defaults.string(forKey: "AleClip_CustomSyncPath")
        self.isSyncEnabled = defaults.bool(forKey: "AleClip_IsSyncEnabled")
        if defaults.object(forKey: "AleClip_IsSyncEnabled") == nil {
            self.isSyncEnabled = true
        }
    }

    public func saveSettings() {
        defaults.set(selectedProvider.rawValue, forKey: "AleClip_SyncProvider")
        defaults.set(customSyncPath, forKey: "AleClip_CustomSyncPath")
        defaults.set(isSyncEnabled, forKey: "AleClip_IsSyncEnabled")
    }

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

    public func syncNow() {
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

        let localPayload = SyncPayload(
            collections: StorageService.shared.collections,
            clips: StorageService.shared.clips
        )

        let syncFile = syncDir.appendingPathComponent("sync_payload_\(localPayload.deviceName).json")
        let mainSyncFile = syncDir.appendingPathComponent("sync_payload.json")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(localPayload)
            try data.write(to: syncFile, options: .atomic)
            try data.write(to: mainSyncFile, options: .atomic)

            // Look for any incoming payloads from other devices to merge
            var incomingMerged = 0
            if let files = try? fileManager.contentsOfDirectory(at: syncDir, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "json" && file.lastPathComponent != syncFile.lastPathComponent {
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
            syncNow()
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
}
