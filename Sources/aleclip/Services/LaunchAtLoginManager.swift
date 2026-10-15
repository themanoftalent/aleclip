import Foundation
import ServiceManagement
import AppKit

public final class LaunchAtLoginManager: @unchecked Sendable {
    public static let shared = LaunchAtLoginManager()

    private init() {}

    public var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return isLoginItemConfiguredViaAppleScript()
        }
    }

    public func setEnabled(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("[AleClip] SMAppService registration note: \(error.localizedDescription). Using login item fallback.")
                setLoginItemViaAppleScript(enable)
            }
        } else {
            setLoginItemViaAppleScript(enable)
        }
    }

    public func syncWithSetting(_ settingEnabled: Bool) {
        if isEnabled != settingEnabled {
            setEnabled(settingEnabled)
        }
    }

    private func isLoginItemConfiguredViaAppleScript() -> Bool {
        let script = "tell application \"System Events\" to return (exists login item \"AleClip\")"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            return result.booleanValue
        }
        return false
    }

    private func setLoginItemViaAppleScript(_ enable: Bool) {
        let appPath = Bundle.main.bundlePath
        let script: String
        if enable {
            script = """
            tell application "System Events"
                if not (exists login item "AleClip") then
                    make new login item at end of login items with properties {path:"\(appPath)", hidden:false, name:"AleClip"}
                end if
            end tell
            """
        } else {
            script = """
            tell application "System Events"
                if (exists login item "AleClip") then
                    delete login item "AleClip"
                end if
            end tell
            """
        }
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let err = error {
                NSLog("[AleClip] AppleScript login item error: \(err)")
            }
        }
    }
}
