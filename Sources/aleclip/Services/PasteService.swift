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

        case .text:
            pasteboard.setString(clip.plainText, forType: .string)
        }
    }

    public func pasteClip(_ clip: ClipItem, targetApp: NSRunningApplication?, forcePlainText: Bool = false) {
        copyToClipboard(clip, forcePlainText: forcePlainText)

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

    public func simulatePasteKeystroke() {
        guard isAccessibilityTrusted else {
            print("AleClip: Accessibility permission not granted. Clip copied to clipboard for manual ⌘V.")
            return
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        // Keycode 9 is the standard ANSI 'V' key
        let vKeyCode: CGKeyCode = 9

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func colorFromHex(_ hex: String) -> NSColor? {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }
        guard cleanHex.count == 6, let rgbValue = UInt32(cleanHex, radix: 16) else { return nil }

        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
