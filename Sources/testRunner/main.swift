import Foundation
import AleClipCore

@MainActor
func runTests() {
    print("▶ Running AleClip Unit Tests...")

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

    // 2. Display titles
    var clip = ClipItem(
        type: .text,
        plainText: "Line 1 of content\nLine 2 of content",
        contentHash: "hash2"
    )
    assert(clip.displayTitle == "Line 1 of content", "Multi-line text should show first line as title")
    clip.title = "Custom User Title"
    assert(clip.displayTitle == "Custom User Title", "Custom title should override first line")
    print("  ✔ ClipItem display title logic passed")

    // 3. Color clip properties
    let colorClip = ClipItem(
        type: .color,
        plainText: "#FF00AA",
        colorHex: "#FF00AA",
        contentHash: "colorhash"
    )
    assert(colorClip.type == .color)
    assert(colorClip.displayTitle == "#FF00AA")
    assert(colorClip.matches(query: "ff00aa"))
    print("  ✔ Color clip properties passed")

    // 4. Link clip properties
    let linkClip = ClipItem(
        type: .link,
        plainText: "https://apple.com/macos",
        url: "https://apple.com/macos",
        contentHash: "linkhash"
    )
    assert(linkClip.type == .link)
    assert(linkClip.displayTitle == "https://apple.com/macos")
    assert(linkClip.matches(query: "apple.com"))
    print("  ✔ Link clip properties passed")

    // 5. History Pruning & Pinned Item Protection
    let storage = StorageService.shared
    storage.settings.historyLimit = 3
    storage.clearUnpinned()

    let clip1 = ClipItem(type: .text, plainText: "Clip 1 Pinned", isPinned: true, contentHash: "h1")
    let clip2 = ClipItem(type: .text, plainText: "Clip 2 Unpinned", isPinned: false, contentHash: "h2")
    let clip3 = ClipItem(type: .text, plainText: "Clip 3 Unpinned", isPinned: false, contentHash: "h3")
    let clip4 = ClipItem(type: .text, plainText: "Clip 4 Unpinned", isPinned: false, contentHash: "h4")

    storage.addClip(clip1)
    storage.addClip(clip2)
    storage.addClip(clip3)
    storage.addClip(clip4)

    let remainingTexts = storage.clips.map { $0.plainText }
    assert(remainingTexts.contains("Clip 1 Pinned"), "Pinned clip must be preserved even when limit exceeded")
    print("  ✔ Storage pruning preserves pinned clips passed")

    // 6. JSON Export and Import
    let tempDir = FileManager.default.temporaryDirectory
    let backupFile = tempDir.appendingPathComponent("test-aleclip-backup.json")
    try! storage.exportJSON(to: backupFile)
    assert(FileManager.default.fileExists(atPath: backupFile.path), "Backup JSON file should exist")

    let importedCount = try! storage.importJSON(from: backupFile)
    assert(importedCount == 0, "Duplicate import should skip all existing hashes")
    try? FileManager.default.removeItem(at: backupFile)
    print("  ✔ JSON export/import and deduplication passed")

    print("\n✅ All AleClip tests passed successfully!")
}

runTests()
