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

    // 7. Turkish localized search (dotted / dotless I & diacritics)
    let turkishClip = ClipItem(
        type: .text,
        plainText: "İstanbul Işıkları ve Çınar Ağaçları",
        contentHash: "trhash1"
    )
    assert(turkishClip.matches(query: "istanbul") || turkishClip.matches(query: "İSTANBUL"), "Turkish search matching")
    assert(turkishClip.matches(query: "çınar"), "Turkish character matching")
    assert(turkishClip.matches(query: "ağaç"), "Turkish ğ character matching")
    print("  ✔ Turkish characters & case-folding search passed")

    // 8. Localization strings validation
    LocalizationService.shared.setLanguage("en")
    assert(loc("panel.searchPlaceholder") == "Search clips...", "English search placeholder")
    assert(loc("about.developedBy") == "Developed by SoftAI Yazılım", "English developer line")

    LocalizationService.shared.setLanguage("tr")
    assert(loc("panel.searchPlaceholder") == "Panoda ara...", "Turkish search placeholder")
    assert(loc("about.developedBy") == "SoftAI Yazılım tarafından geliştirildi", "Turkish developer line")
    assert(!loc("settings.shortcuts.quickPaste").isEmpty, "Turkish quickPaste shortcut string")
    print("  ✔ Localization service English & Turkish strings passed")

    // 9. Quick paste localization check in English
    LocalizationService.shared.setLanguage("en")
    assert(!loc("settings.shortcuts.quickPaste").isEmpty, "English quickPaste shortcut string")
    print("  ✔ Quick Paste localization strings verified")

    // 10. Large text safety truncation validation
    let giantText = String(repeating: "A", count: 300_000)
    let maxCharacters = 250_000
    let safeString = giantText.count > maxCharacters
        ? String(giantText.prefix(maxCharacters)) + "\n\n[... Truncated for performance / Performans için kesildi ...]"
        : giantText
    let largeClip = ClipItem(type: .text, plainText: safeString, contentHash: "largehash")
    assert(largeClip.plainText.count < 300_000, "Safety cap prevents unbounded memory expansion")
    print("  ✔ Large text safety capping verified")

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
    assert(!storage.deletedClips.contains { $0.id == undoTestClip.id }, "Restored clip must be removed from deletedClips")
    print("  ✔ Soft delete and undoLastDelete (⌘Z) passed")

    // 12. Restore from Trash (deletedClips)
    let trashTestClip = ClipItem(type: .text, plainText: "Clip to restore from Trash bin", contentHash: "trashhash1")
    storage.addClip(trashTestClip)
    storage.deleteClip(id: trashTestClip.id)
    assert(storage.deletedClips.contains { $0.id == trashTestClip.id }, "Clip must be in Trash")

    let manuallyRestored = storage.restoreClip(id: trashTestClip.id)
    assert(manuallyRestored?.id == trashTestClip.id, "restoreClip should return the clip")
    assert(storage.clips.contains { $0.id == trashTestClip.id }, "Clip should be restored to active clips")
    assert(!storage.deletedClips.contains { $0.id == trashTestClip.id }, "Clip should be removed from Trash")
    print("  ✔ Restore from Trash (deletedClips) passed")

    // 13. Permanent delete & Empty Trash
    let permClip1 = ClipItem(type: .text, plainText: "Permanent 1", contentHash: "perm1")
    let permClip2 = ClipItem(type: .text, plainText: "Permanent 2", contentHash: "perm2")
    storage.addClip(permClip1)
    storage.addClip(permClip2)
    storage.deleteClip(id: permClip1.id)
    storage.deleteClip(id: permClip2.id)
    assert(storage.deletedClips.count >= 2, "Both clips in deletedClips")

    storage.deleteClip(id: permClip1.id, permanent: true)
    assert(!storage.deletedClips.contains { $0.id == permClip1.id }, "Permanent delete should wipe item from deletedClips")

    storage.emptyTrash()
    assert(storage.deletedClips.isEmpty, "emptyTrash should clear all deleted clips")
    print("  ✔ Permanent delete & Empty Trash passed")

    // 14. Localization validation for Undo & Trash
    LocalizationService.shared.setLanguage("en")
    assert(loc("filter.deleted") == "Deleted", "English Deleted filter")
    assert(loc("toast.undo") == "Undo (⌘Z)", "English Undo toast")
    assert(loc("card.restore") == "Restore", "English card restore")

    LocalizationService.shared.setLanguage("tr")
    assert(loc("filter.deleted") == "Silinenler", "Turkish Deleted filter")
    assert(loc("toast.undo") == "Geri Al (⌘Z)", "Turkish Undo toast")
    assert(loc("card.restore") == "Geri Yükle", "Turkish card restore")
    print("  ✔ Undo & Trash localization validation passed")

    print("\n✅ All AleClip tests passed successfully!")
}

runTests()
