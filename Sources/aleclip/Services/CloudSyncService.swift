import Foundation

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

    @Published public var isSyncEnabled: Bool = false
    @Published public var lastSyncTime: Date? = nil
    @Published public var syncStatusMessage: String = "Ready"

    private let fileManager = FileManager.default
    private var syncDirectoryURL: URL? {
        // Default to iCloud Drive container or App Support sync container
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents/AleClipSync", isDirectory: true) {
            return iCloudURL
        }
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("AleClip/CloudSync", isDirectory: true)
    }

    private init() {}

    public func syncNow() {
        guard let syncDir = syncDirectoryURL else { return }
        try? fileManager.createDirectory(at: syncDir, withIntermediateDirectories: true)

        let localPayload = SyncPayload(
            collections: StorageService.shared.collections,
            clips: StorageService.shared.clips
        )

        let syncFile = syncDir.appendingPathComponent("sync_payload_\(localPayload.deviceName).json")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(localPayload)
            try data.write(to: syncFile, options: .atomic)
            self.lastSyncTime = Date()
            self.syncStatusMessage = "Synced at \(Date().formatted(date: .omitted, time: .standard))"
        } catch {
            self.syncStatusMessage = "Sync failed: \(error.localizedDescription)"
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
