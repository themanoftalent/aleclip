import Foundation
import AppKit

@MainActor
public final class ScreenPrivacyService: ObservableObject {
    public static let shared = ScreenPrivacyService()

    @Published public var isShieldActive: Bool = false
    @Published public var autoShieldOnScreenShare: Bool = true

    private var checkTimer: Timer?

    private init() {
        startMonitoring()
    }

    public func toggleShield() {
        isShieldActive.toggle()
    }

    private func startMonitoring() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.detectScreenSharing()
            }
        }
    }

    private func detectScreenSharing() {
        guard autoShieldOnScreenShare else { return }

        let sharingApps = ["zoom.us", "com.microsoft.teams", "com.google.Chrome", "com.apple.FaceTime", "com.apple.QuickTimePlayerX"]
        let running = NSWorkspace.shared.runningApplications

        var sharingDetected = false
        for app in running {
            if let bid = app.bundleIdentifier, sharingApps.contains(bid) {
                // If conference / recording apps are running actively
                if app.isActive {
                    sharingDetected = true
                    break
                }
            }
        }

        if sharingDetected && !isShieldActive {
            isShieldActive = true
        }
    }
}
