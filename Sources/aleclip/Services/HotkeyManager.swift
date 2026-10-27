import Foundation
import AppKit
import Carbon

private func carbonHotKeyCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ theEvent: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    Task { @MainActor in
        HotkeyManager.shared.onHotkeyPressed?()
    }
    return noErr
}

public enum GlobalShortcutOption: String, CaseIterable, Identifiable, Codable, Sendable {
    case optionV = "⌥V (Option + V)"
    case cmdShiftV = "⇧⌘V (Shift + Command + V)"
    case controlOptionV = "⌃⌥V (Control + Option + V)"
    case optionSpace = "⌥Space (Option + Space)"

    public var id: String { rawValue }

    public var keyCode: UInt32 {
        switch self {
        case .cmdShiftV, .optionV, .controlOptionV:
            return UInt32(kVK_ANSI_V)
        case .optionSpace:
            return UInt32(kVK_Space)
        }
    }

    public var modifiers: UInt32 {
        switch self {
        case .cmdShiftV:
            return UInt32(cmdKey | shiftKey)
        case .optionV:
            return UInt32(optionKey)
        case .controlOptionV:
            return UInt32(controlKey | optionKey)
        case .optionSpace:
            return UInt32(optionKey)
        }
    }
}

@MainActor
public final class HotkeyManager: ObservableObject {
    public static let shared = HotkeyManager()

    public var onHotkeyPressed: (() -> Void)?

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    public func applyConfiguredHotkey() {
        unregisterHotkey()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyCallback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard status == noErr else {
            print("Failed to install Carbon event handler: \(status)")
            return
        }

        // Register ⌥V (Option + V) as requested by user
        registerSingleHotkey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey), id: 1)

        // Register ⇧⌘V (Shift + Command + V) as dual convenience
        registerSingleHotkey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey), id: 2)

        // Also register any custom option selected in Settings if different
        let saved = StorageService.shared.settings.selectedShortcut
        if let option = GlobalShortcutOption(rawValue: saved) {
            if option != .optionV && option != .cmdShiftV {
                registerSingleHotkey(keyCode: option.keyCode, modifiers: option.modifiers, id: 3)
            }
        }
    }

    public func registerDefaultHotkey() {
        applyConfiguredHotkey()
    }

    public func registerHotkey(keyCode: UInt32, modifiers: UInt32) {
        applyConfiguredHotkey()
    }

    private func registerSingleHotkey(keyCode: UInt32, modifiers: UInt32, id: UInt32) {
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: id) // 'CLIP'
        var ref: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if registerStatus == noErr, let validRef = ref {
            hotKeyRefs.append(validRef)
        } else {
            print("Failed to register Carbon HotKey ID \(id): \(registerStatus)")
        }
    }

    public func unregisterHotkey() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()

        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }
}
