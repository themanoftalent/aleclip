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
    case cmdShiftV = "⌘⇧V (Command + Shift + V)"
    case controlOptionV = "⌃⌥V (Control + Option + V)"
    case optionSpace = "⌥Space (Option + Space)"

    public var id: String { rawValue }

    public var keyCode: UInt32 {
        switch self {
        case .optionV, .cmdShiftV, .controlOptionV:
            return UInt32(kVK_ANSI_V)
        case .optionSpace:
            return UInt32(kVK_Space)
        }
    }

    public var modifiers: UInt32 {
        switch self {
        case .optionV:
            return UInt32(optionKey)
        case .cmdShiftV:
            return UInt32(cmdKey | shiftKey)
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

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    public func registerDefaultHotkey() {
        registerHotkey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey))
    }

    public func applyConfiguredHotkey() {
        let saved = StorageService.shared.settings.selectedShortcut
        if let option = GlobalShortcutOption(rawValue: saved) {
            registerHotkey(keyCode: option.keyCode, modifiers: option.modifiers)
        } else {
            registerDefaultHotkey()
        }
    }

    public func registerHotkey(keyCode: UInt32, modifiers: UInt32) {
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

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1) // 'CLIP'
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            print("Failed to register Carbon HotKey: \(registerStatus)")
        } else {
            print("AleClip: Global hotkey ⌥V successfully registered.")
        }
    }

    public func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        // In case of deallocation
    }
}
