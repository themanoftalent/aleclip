import Foundation
import AppKit
import ApplicationServices

@MainActor
public final class PasteService {
    public static let shared = PasteService()

    private init() {}

    public var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    public func promptAccessibilityIfNeeded() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true as CFBoolean] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func copyToClipboard(_ clip: ClipItem, forcePlainText: Bool = false) {
        ClipboardMonitor.shared.isInternalCopy = true

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let usePlainText = forcePlainText || StorageService.shared.settings.plainTextAlways

        if usePlainText {
            pasteboard.setString(clip.plainText, forType: .string)
            return
        }

        switch clip.type {
        case .color:
            if let hex = clip.colorHex, let color = colorFromHex(hex) {
                color.write(to: pasteboard)
            }
            pasteboard.setString(clip.plainText, forType: .string)

        case .file:
            if let urlString = clip.url, let fileURL = URL(string: urlString) {
                pasteboard.writeObjects([fileURL as NSURL])
            }
            pasteboard.setString(clip.plainText, forType: .string)

        case .image:
            if let filename = clip.imageFileName,
               let image = StorageService.shared.loadImageBlob(named: filename),
               let tiffData = image.tiffRepresentation {
                pasteboard.setData(tiffData, forType: .tiff)
                if let rep = NSBitmapImageRep(data: tiffData),
                   let pngData = rep.representation(using: .png, properties: [:]) {
                    pasteboard.setData(pngData, forType: .png)
                }
            }

        case .link:
            if let urlString = clip.url, let url = URL(string: urlString) {
                pasteboard.writeObjects([url as NSURL])
            }
            pasteboard.setString(clip.plainText, forType: .string)

        case .html:
            if let html = clip.htmlContent {
                pasteboard.setString(html, forType: .html)
            }
            pasteboard.setString(clip.plainText, forType: .string)

        case .richText:
            if let rtfData = clip.rtfData {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            pasteboard.setString(clip.plainText, forType: .string)

        case .text, .code:
            pasteboard.setString(clip.plainText, forType: .string)
        }
    }

    public func pasteClip(_ clip: ClipItem, targetApp: NSRunningApplication?, forcePlainText: Bool = false) {
        copyToClipboard(clip, forcePlainText: forcePlainText)

        if StorageService.shared.settings.soundEffects {
            NSSound(named: "Pop")?.play()
        }

        guard StorageService.shared.settings.pasteIntoActiveApp else { return }

        // If target app is provided, activate it first
        if let targetApp = targetApp, targetApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            targetApp.activate()
        }

        // Delay slightly for window focus to switch, then synthesize ⌘V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.simulatePasteKeystroke()
        }
    }

    public func pasteMultipleClips(_ clips: [ClipItem], targetApp: NSRunningApplication?, delimiter: String = "\n", forcePlainText: Bool = false) {
        guard !clips.isEmpty else { return }

        let combinedText = clips.map { $0.plainText }.joined(separator: delimiter)
        let combinedClip = ClipItem(
            type: .text,
            plainText: combinedText,
            contentHash: UUID().uuidString
        )

        pasteClip(combinedClip, targetApp: targetApp, forcePlainText: forcePlainText)
    }

    public func pasteNextInQueue(targetApp: NSRunningApplication?) -> Bool {
        guard let next = SequentialPasteService.shared.popNext() else {
            return false
        }
        pasteClip(next, targetApp: targetApp)
        return true
    }

    private func simulatePasteKeystroke() {
        guard isAccessibilityTrusted else {
            promptAccessibilityIfNeeded()
            return
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 9 // ANSI 'V'

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func colorFromHex(_ hex: String) -> NSColor? {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }

        guard cleanHex.count == 6, let rgb = UInt32(cleanHex, radix: 16) else { return nil }
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
