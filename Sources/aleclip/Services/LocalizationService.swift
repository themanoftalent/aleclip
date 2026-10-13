import Foundation
import AppKit
import SwiftUI

public final class LocalizationService: ObservableObject, @unchecked Sendable {
    public static let shared = LocalizationService()

    private let lock = NSLock()
    @Published public private(set) var currentLanguage: String = "en"
    private var bundle: Bundle = .main

    private init() {
        updateLanguageBundle()
    }

    public func setLanguage(_ lang: String) {
        if lang == "system" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([lang], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
        updateLanguageBundle()
    }

    public func getSelectedLanguageSetting() -> String {
        guard let preferred = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
              let first = preferred.first else {
            return "system"
        }
        if first.hasPrefix("tr") { return "tr" }
        if first.hasPrefix("en") { return "en" }
        return "system"
    }

    public func updateLanguageBundle() {
        lock.lock()
        defer { lock.unlock() }

        let preferred = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        let selectedLang = preferred?.first ?? Locale.current.language.languageCode?.identifier ?? "en"
        let effectiveLang = (selectedLang.hasPrefix("tr")) ? "tr" : "en"

        if Thread.isMainThread {
            self.currentLanguage = effectiveLang
        } else {
            DispatchQueue.main.async {
                self.currentLanguage = effectiveLang
            }
        }

        if let path = Bundle.main.path(forResource: effectiveLang, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            self.bundle = langBundle
        } else if let fallbackBundle = Bundle(path: "Resources/\(effectiveLang).lproj") {
            self.bundle = fallbackBundle
        } else {
            self.bundle = .main
        }
    }

    public func localized(_ key: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    public func localizedFormat(_ key: String, _ args: [CVarArg]) -> String {
        lock.lock()
        defer { lock.unlock() }
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        return String(format: format, locale: Locale(identifier: currentLanguage), arguments: args)
    }

    @MainActor
    public static func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", bundleURL.path]
        try? process.run()
        NSApplication.shared.terminate(nil)
    }
}

public func loc(_ key: String) -> String {
    LocalizationService.shared.localized(key)
}

public func locF(_ key: String, _ args: CVarArg...) -> String {
    LocalizationService.shared.localizedFormat(key, args)
}
