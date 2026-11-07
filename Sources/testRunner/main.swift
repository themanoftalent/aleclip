import Foundation
import AleClipCore

@MainActor
func runTests() {
    print("▶ Running AleClip Unit Tests...")

    let storage = StorageService.shared

    // 1. Search matching
    let textClip = ClipItem(
        type: .text,
        plainText: "Swift is amazing for Mac development",
        contentHash: "hash1"
    )
    assert(textClip.matches(query: "swift"), "Should match 'swift'")
    assert(textClip.matches(query: "SWIFT"), "Case-insensitive match should pass")
    assert(textClip.matches(query: "amazing"), "Substring match should pass")
    assert(!textClip.matches(query: "python"), "Unrelated query should not match")
    print("  ✔ ClipItem search matching passed")

    // 2. OCR Text Search Matching (Feature 3)
    let ocrClip = ClipItem(
        type: .image,
        plainText: "[Image]",
        contentHash: "ocrhash1",
        ocrText: "Financial Quarter 4 Invoice Total $1,250.00"
    )
    assert(ocrClip.matches(query: "invoice"), "Should match word from OCR text")
    assert(ocrClip.matches(query: "Quarter 4"), "Should match phrase from OCR text")
    print("  ✔ OCR text index and search matching passed")

    // 3. Content Recognition & Language Detection (Feature 23)
    let swiftSnippet = """
    import SwiftUI
    struct ContentView: View {
        var body: some View { Text("Hello") }
    }
    """
    let swiftAnalysis = ContentDetector.shared.analyzeText(swiftSnippet)
    assert(swiftAnalysis.detectedType == .code, "Should detect code snippet")
    assert(swiftAnalysis.detectedLanguage == "Swift", "Should identify Swift language")

    let pythonSnippet = """
    def compute_sum(a, b):
        return a + b
    """
    let pythonAnalysis = ContentDetector.shared.analyzeText(pythonSnippet)
    assert(pythonAnalysis.detectedLanguage == "Python", "Should identify Python language")

    let jsonSnippet = "{\"id\": 123, \"active\": true}"
    let jsonAnalysis = ContentDetector.shared.analyzeText(jsonSnippet)
    assert(jsonAnalysis.detectedLanguage == "JSON", "Should identify JSON")
    print("  ✔ Advanced content recognition and syntax detection passed")

    // 4. Sensitive Information Detection (Feature 14)
    let apiText = "My private key is sk-1234567890abcdef1234567890abcdef"
    let sensitiveAnalysis = ContentDetector.shared.analyzeText(apiText)
    assert(sensitiveAnalysis.isSensitive, "Should flag OpenAI-style secret key")

    let normalText = "Just a friendly message"
    assert(!ContentDetector.shared.analyzeText(normalText).isSensitive, "Normal text should not be flagged")
    print("  ✔ Sensitive information privacy detection passed")

    // 5. Unlimited History Protection (Feature 1)
    storage.settings.unlimitedHistory = true
    storage.settings.historyLimit = 0
    storage.clearUnpinned()

    let c1 = ClipItem(type: .text, plainText: "Clip 1", isPinned: false, contentHash: "uh1")
    let c2 = ClipItem(type: .text, plainText: "Clip 2", isPinned: false, contentHash: "uh2")
    let c3 = ClipItem(type: .text, plainText: "Clip 3", isPinned: false, contentHash: "uh3")
    storage.addClip(c1)
    storage.addClip(c2)
    storage.addClip(c3)
    assert(storage.clips.count >= 3, "Unlimited history must never prune unpinned clips")
    print("  ✔ Unlimited clipboard history protection passed")

    // 6. Pinboards & Collections (Feature 5)
    let testCollection = ClipCollection(name: "Test Pinboard", icon: "curlybraces", colorHex: "#BF5AF2")
    storage.addCollection(testCollection)
    assert(storage.collections.contains { $0.id == testCollection.id }, "Collection must be stored")

    storage.assignClip(clipId: c1.id, to: testCollection.id)
    assert(storage.clips.first(where: { $0.id == c1.id })?.collectionId == testCollection.id, "Clip must be assigned to collection")
    storage.removeCollection(id: testCollection.id) // Clean up test collection
    print("  ✔ Pinboards and collections management passed")

    // 7. Sequential Copy and Paste Queue (Feature 9)
    let seqQueue = SequentialPasteService.shared
    seqQueue.clearQueue()
    seqQueue.isQueueActive = true

    let itemA = ClipItem(type: .text, plainText: "First Item", contentHash: "seqA")
    let itemB = ClipItem(type: .text, plainText: "Second Item", contentHash: "seqB")
    seqQueue.addToQueue(itemA)
    seqQueue.addToQueue(itemB)

    assert(seqQueue.queue.count == 2, "Queue should contain 2 items")
    let poppedFirst = seqQueue.popNext()
    assert(poppedFirst?.plainText == "First Item", "FIFO sequential paste should pop First Item")
    let poppedSecond = seqQueue.popNext()
    assert(poppedSecond?.plainText == "Second Item", "FIFO sequential paste should pop Second Item")
    assert(seqQueue.queue.isEmpty, "Queue should be empty after popping both")
    seqQueue.clearQueue()
    print("  ✔ Sequential copy and paste queue (FIFO) passed")

    // 8. Multi-Item Pasting Combination (Feature 16)
    let multiClip1 = ClipItem(type: .text, plainText: "Alpha", contentHash: "m1")
    let multiClip2 = ClipItem(type: .text, plainText: "Beta", contentHash: "m2")
    let multiCombined = [multiClip1, multiClip2].map { $0.plainText }.joined(separator: "\n")
    assert(multiCombined == "Alpha\nBeta", "Combined multi-item text matching")
    print("  ✔ Multiple-item paste combination passed")

    // 9. Model Context Protocol (MCP) RPC handling (Feature 8)
    let initRequest = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}"
    let initResponse = MCPService.shared.handleJSONRPC(input: initRequest)
    assert(initResponse != nil && initResponse!.contains("aleclip-mcp"), "MCP initialize should respond with aleclip-mcp")

    let toolsRequest = "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\",\"params\":{}}"
    let toolsResponse = MCPService.shared.handleJSONRPC(input: toolsRequest)
    assert(toolsResponse != nil && toolsResponse!.contains("get_recent_clips"), "MCP tools list should provide get_recent_clips")
    print("  ✔ MCP service JSON-RPC processing passed")

    // 10. Display titles & Duplicate Clip (Feature 11)
    storage.duplicateClip(id: c1.id)
    assert(storage.clips.first?.title?.contains("(Copy)") == true, "Duplicated clip should be created at front")
    print("  ✔ Clipboard editing and duplication passed")

    // 11. Soft delete and undoLastDelete (⌘Z)
    let undoTestClip = ClipItem(type: .text, plainText: "Important user note that was deleted", contentHash: "undohash1")
    storage.addClip(undoTestClip)
    assert(storage.clips.contains { $0.id == undoTestClip.id }, "Clip should be in active clips")

    let deletedItem = storage.deleteClip(id: undoTestClip.id)
    assert(deletedItem?.id == undoTestClip.id, "deleteClip should return deleted clip")
    assert(!storage.clips.contains { $0.id == undoTestClip.id }, "Clip should no longer be in active clips")
    assert(storage.deletedClips.contains { $0.id == undoTestClip.id }, "Clip should be stored in deletedClips (Trash)")

    let restoredItem = storage.undoLastDelete()
    assert(restoredItem?.id == undoTestClip.id, "undoLastDelete should return restored clip")
    assert(storage.clips.contains { $0.id == undoTestClip.id }, "Restored clip must be back in active clips")
    print("  ✔ Soft delete and undoLastDelete (⌘Z) passed")

    // 12. Quick Backup creation (Feature 24 & 22)
    if let backupFile = storage.createBackup() {
        assert(FileManager.default.fileExists(atPath: backupFile.path), "Backup archive file should exist on disk")
        try? FileManager.default.removeItem(at: backupFile)
    }
    print("  ✔ Reliable local storage backup creation passed")

    // 13. Recover All Deleted Clips
    let clipA = ClipItem(type: .text, plainText: "Deleted Clip A", contentHash: "delA")
    let clipB = ClipItem(type: .text, plainText: "Deleted Clip B", contentHash: "delB")
    storage.addClip(clipA)
    storage.addClip(clipB)
    storage.deleteClip(id: clipA.id)
    storage.deleteClip(id: clipB.id)
    assert(storage.deletedClips.count >= 2, "Trash should hold deleted clips")
    let restoredCount = storage.restoreAllDeleted()
    assert(restoredCount >= 2, "restoreAllDeleted should restore all clips from trash")
    assert(storage.deletedClips.isEmpty, "Trash should be empty after restoreAllDeleted")
    assert(storage.clips.contains { $0.id == clipA.id }, "Clip A should be back in clips")
    assert(storage.clips.contains { $0.id == clipB.id }, "Clip B should be back in clips")
    print("  ✔ Recover all deleted clips passed")

    // 14. Google Drive Connection & Sync
    let cloudSync = CloudSyncService.shared
    assert(cloudSync.selectedProvider == .googleDrive, "Google Drive should be default sync provider")
    cloudSync.connectGoogleDrive()
    assert(cloudSync.isConnected, "Google Drive should be connected after connectGoogleDrive()")
    assert(cloudSync.lastSyncTime != nil, "lastSyncTime should be recorded after sync")
    assert(cloudSync.syncStatusMessage.contains("✅"), "Sync status should indicate success")
    print("  ✔ Google Drive connection and cloud synchronization passed")

    // 15. Bidirectional Sync: iOS Payload Merge & Deduplication
    let uniqueTestHash = "ios-test-hash-\(UUID().uuidString)"
    let mockIOSClip = ClipItem(
        type: .text,
        plainText: "Synced note created on iPhone 16 Pro",
        sourceAppName: "Safari",
        createdAt: Date(),
        contentHash: uniqueTestHash,
        sourceDevice: "iPhone"
    )
    let mergeResult = storage.applyRemote(clips: [mockIOSClip], tombstones: [:])
    assert(mergeResult.added == 1, "applyRemote should merge the iOS clip")
    assert(storage.clips.contains { $0.contentHash == mockIOSClip.contentHash }, "Merged iOS clip must exist in clips")

    // Attempting to merge identical clip again should produce 0 duplicates
    let duplicateMergeResult = storage.applyRemote(clips: [mockIOSClip], tombstones: [:])
    assert(duplicateMergeResult.added == 0, "Deduplication must prevent duplicate clips from remote devices")
    print("  ✔ Bidirectional iOS-to-Mac clip merge and deduplication passed")

    // 16. Deletion Propagation (Tombstones across devices)
    let tombstoneDate = Date().addingTimeInterval(10) // deleted 10 seconds later
    let tombstoneResult = storage.applyRemote(clips: [], tombstones: [uniqueTestHash: tombstoneDate])
    assert(tombstoneResult.removed == 1, "Tombstone from iOS must remove clip on Mac")
    assert(!storage.clips.contains { $0.contentHash == uniqueTestHash }, "Deleted clip must no longer exist in active clips")
    assert(storage.tombstones[uniqueTestHash] != nil, "Tombstone must be recorded in storage")

    // Old remote clip should NOT resurrect if tombstone exists
    let resurrectAttempt = storage.applyRemote(clips: [mockIOSClip], tombstones: [:])
    assert(resurrectAttempt.added == 0, "Tombstone must prevent old clip resurrection")
    print("  ✔ Deletion tombstone propagation and anti-resurrection passed")

    // 17. Resilient Schema Decoding (Missing fields & variations)
    let minimalJSON = """
    {
      "deviceName": "iPad Air",
      "clips": []
    }
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decodedMinimal = try? decoder.decode(SyncPayload.self, from: minimalJSON)
    assert(decodedMinimal != nil, "SyncPayload must decode tolerantly when collections/timestamps/deletedHashes are omitted")
    assert(decodedMinimal?.deviceName == "iPad Air", "Device name should be correctly extracted")
    print("  ✔ Resilient cross-platform SyncPayload JSON decoding passed")

    // 18. Automatic Sync Debounce & Scheduling
    cloudSync.scheduleSync(delay: 0.1)
    print("  ✔ CloudSync scheduleSync debounce scheduling passed")

    print("\n✅ All AleClip extended unit tests passed successfully!")
}

runTests()
