import SwiftUI
import AppKit

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case shortcuts = "Shortcuts"
    case exclusions = "Exclusions"
    case backup = "Backup"
    case about = "About"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: return loc("settings.tab.general")
        case .shortcuts: return loc("settings.tab.shortcuts")
        case .exclusions: return loc("settings.tab.exclusions")
        case .backup: return loc("settings.tab.backup")
        case .about: return loc("settings.tab.about")
        }
    }

    public var iconName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .shortcuts: return "keyboard.fill"
        case .exclusions: return "hand.raised.fill"
        case .backup: return "arrow.triangle.2.circlepath"
        case .about: return "info.circle.fill"
        }
    }
}

enum SettingsAlertItem: Identifiable {
    case info(String)
    case languageRestart

    var id: String {
        switch self {
        case .info(let m): return "info-\(m)"
        case .languageRestart: return "restart"
        }
    }
}

final class SettingsViewModel: ObservableObject {
    @Published var selectedTab: SettingsTab = .general
    @Published var newBundleId: String = ""
    @Published var activeAlert: SettingsAlertItem? = nil
}

public struct SettingsView: View {
    @ObservedObject private var storage = StorageService.shared
    @ObservedObject private var l10n = LocalizationService.shared
    @StateObject private var model = SettingsViewModel()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top Tab Bar
            topTabBar
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Main Tab Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    switch model.selectedTab {
                    case .general:
                        generalContent
                    case .shortcuts:
                        shortcutsContent
                    case .exclusions:
                        exclusionsContent
                    case .backup:
                        backupContent
                    case .about:
                        aboutContent
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        }
        .frame(width: 620, height: 530)
        .alert(item: $model.activeAlert) { item in
            switch item {
            case .info(let message):
                return Alert(
                    title: Text("AleClip"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            case .languageRestart:
                return Alert(
                    title: Text(loc("settings.alert.langRestartTitle")),
                    message: Text(loc("settings.alert.langRestartMsg")),
                    primaryButton: .default(Text(loc("settings.alert.restartNow")), action: {
                        LocalizationService.relaunchApp()
                    }),
                    secondaryButton: .cancel(Text(loc("settings.alert.later")))
                )
            }
        }
    }

    // MARK: - Top Tab Bar

    private var topTabBar: some View {
        HStack(spacing: 6) {
            ForEach(SettingsTab.allCases) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        model.selectedTab = tab
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 12))
                        Text(tab.title)
                            .font(.system(size: 13, weight: model.selectedTab == tab ? .semibold : .regular))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundColor(model.selectedTab == tab ? .white : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(model.selectedTab == tab ? Color.accentColor : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - General Content

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Language Picker Card
            settingsCard(title: loc("settings.general.language"), icon: "globe") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(loc("settings.general.language") + ":")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { LocalizationService.shared.getSelectedLanguageSetting() },
                            set: { newValue in
                                LocalizationService.shared.setLanguage(newValue)
                                model.activeAlert = .languageRestart
                            }
                        )) {
                            Text(loc("settings.general.langSystem")).tag("system")
                            Text(loc("settings.general.langEn")).tag("en")
                            Text(loc("settings.general.langTr")).tag("tr")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                }
            }

            // History Limits Card
            settingsCard(title: loc("settings.general.historyLimits"), icon: "clock.arrow.circlepath") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(loc("settings.general.maxItems"))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $storage.settings.historyLimit) {
                            Text(locF("footer.clips", 50)).tag(50)
                            Text(locF("footer.clips", 100)).tag(100)
                            Text(locF("footer.clips", 200)).tag(200)
                            Text(locF("footer.clips", 500)).tag(500)
                            Text(locF("footer.clips", 1000)).tag(1000)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                        .onChange(of: storage.settings.historyLimit) { _, _ in
                            storage.saveSettings()
                        }
                    }

                    Text(loc("settings.general.historyHelp"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Paste Behavior Card
            settingsCard(title: loc("settings.general.pasteBehavior"), icon: "doc.on.clipboard") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(loc("settings.general.pasteDirectly"), isOn: $storage.settings.pasteIntoActiveApp)
                        .font(.system(size: 13))
                        .onChange(of: storage.settings.pasteIntoActiveApp) { _, _ in
                            storage.saveSettings()
                        }

                    if storage.settings.pasteIntoActiveApp {
                        HStack(spacing: 8) {
                            Image(systemName: PasteService.shared.isAccessibilityTrusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(PasteService.shared.isAccessibilityTrusted ? .green : .orange)
                                .font(.system(size: 15))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc(PasteService.shared.isAccessibilityTrusted ? "settings.general.accessGranted" : "settings.general.accessRequired"))
                                    .font(.system(size: 12, weight: .semibold))
                                Text(loc(PasteService.shared.isAccessibilityTrusted ? "settings.general.accessGrantedDesc" : "settings.general.accessRequiredDesc"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if !PasteService.shared.isAccessibilityTrusted {
                                Button(loc("settings.general.openSysSettings")) {
                                    PasteService.shared.promptAccessibilityIfNeeded()
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .windowBackgroundColor))
                        )
                    }

                    Divider()

                    Toggle(loc("settings.general.plainTextAlways"), isOn: $storage.settings.plainTextAlways)
                        .font(.system(size: 13))
                        .onChange(of: storage.settings.plainTextAlways) { _, _ in
                            storage.saveSettings()
                        }
                }
            }

            // Sound Effects Card
            settingsCard(title: loc("settings.general.audioFeedback"), icon: "speaker.wave.2") {
                Toggle(loc("settings.general.soundEffects"), isOn: $storage.settings.soundEffects)
                    .font(.system(size: 13))
                    .onChange(of: storage.settings.soundEffects) { _, _ in
                        storage.saveSettings()
                    }
            }
        }
    }

    // MARK: - Shortcuts Content

    private var shortcutsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Global Hotkey Card
            settingsCard(title: loc("settings.shortcuts.globalTitle"), icon: "command") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(loc("settings.shortcuts.globalDesc"))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $storage.settings.selectedShortcut) {
                            ForEach(GlobalShortcutOption.allCases) { option in
                                Text(option.rawValue).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 220)
                        .onChange(of: storage.settings.selectedShortcut) { _, _ in
                            storage.saveSettings()
                            HotkeyManager.shared.applyConfiguredHotkey()
                        }
                    }

                    Text(loc("settings.shortcuts.globalHelp"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Keyboard Shortcuts Guide Card
            settingsCard(title: loc("settings.shortcuts.guideTitle"), icon: "keyboard") {
                VStack(spacing: 8) {
                    shortcutRow(keys: ["⌥", "V"], action: loc("settings.shortcuts.togglePanel"))
                    shortcutRow(keys: ["←", "→"], action: loc("settings.shortcuts.navigateCards"))
                    shortcutRow(keys: ["↵"], action: loc("settings.shortcuts.pasteClip"))
                    shortcutRow(keys: ["⇧", "↵"], action: loc("settings.shortcuts.plainPaste"))
                    shortcutRow(keys: ["Space"], action: loc("settings.shortcuts.quickLook"))
                    shortcutRow(keys: ["⌘", "E"], action: loc("settings.shortcuts.editClip"))
                    shortcutRow(keys: ["⌫"], action: loc("settings.shortcuts.deleteClip"))
                    shortcutRow(keys: ["Esc"], action: loc("settings.shortcuts.dismissPanel"))
                }
            }
        }
    }

    private func shortcutRow(keys: [String], action: String) -> some View {
        HStack {
            Text(action)
                .font(.system(size: 12))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(nsColor: .windowBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Exclusions Content

    private var exclusionsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: loc("settings.exclusions.title"), icon: "hand.raised") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc("settings.exclusions.help"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // App List
                    ScrollView {
                        VStack(spacing: 6) {
                            if storage.settings.excludedBundleIds.isEmpty {
                                Text(loc("settings.exclusions.empty"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(storage.settings.excludedBundleIds, id: \.self) { bundleId in
                                    HStack {
                                        Image(systemName: "app.dashed")
                                            .foregroundColor(.secondary)
                                        Text(bundleId)
                                            .font(.system(size: 12, design: .monospaced))
                                        Spacer()
                                        Button(action: {
                                            storage.settings.excludedBundleIds.removeAll { $0 == bundleId }
                                            storage.saveSettings()
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 11))
                                                .foregroundColor(.red.opacity(0.8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(nsColor: .windowBackgroundColor))
                                    )
                                }
                            }
                        }
                    }
                    .frame(height: 140)

                    Divider()

                    // Add Buttons
                    HStack(spacing: 8) {
                        Button(loc("settings.exclusions.chooseApp")) {
                            chooseApplication()
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }

                    HStack(spacing: 8) {
                        TextField(loc("settings.exclusions.enterBundle"), text: $model.newBundleId)
                            .textFieldStyle(.roundedBorder)

                        Button(loc("settings.exclusions.add")) {
                            let trimmed = model.newBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            if !storage.settings.excludedBundleIds.contains(trimmed) {
                                storage.settings.excludedBundleIds.append(trimmed)
                                storage.saveSettings()
                            }
                            model.newBundleId = ""
                        }
                        .disabled(model.newBundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
                    if !storage.settings.excludedBundleIds.contains(bundleId) {
                        storage.settings.excludedBundleIds.append(bundleId)
                    }
                }
            }
            storage.saveSettings()
        }
    }

    // MARK: - Backup Content

    private var backupContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: loc("settings.backup.title"), icon: "arrow.triangle.2.circlepath") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc("settings.backup.help"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button(loc("settings.backup.exportBtn")) {
                            exportHistory()
                        }
                        .buttonStyle(.borderedProminent)

                        Button(loc("settings.backup.importBtn")) {
                            importHistory()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            settingsCard(title: loc("settings.backup.manageTitle"), icon: "trash") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc("settings.backup.manageHelp"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(loc("settings.backup.clearUnpinnedBtn"), role: .destructive) {
                        storage.clearUnpinned()
                        model.activeAlert = .info(loc("settings.backup.clearSuccess"))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "AleClip-Backup-\(ISO8601DateFormatter().string(from: Date())).json"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try storage.exportJSON(to: url)
                model.activeAlert = .info(loc("settings.backup.exportSuccess"))
            } catch {
                model.activeAlert = .info(locF("settings.backup.exportFailed", error.localizedDescription))
            }
        }
    }

    private func importHistory() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let count = try storage.importJSON(from: url)
                model.activeAlert = .info(locF("settings.backup.importSuccess", count))
            } catch {
                model.activeAlert = .info(locF("settings.backup.importFailed", error.localizedDescription))
            }
        }
    }

    // MARK: - About Content

    private var aboutContent: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 6)

            if let image = NSApp.applicationIconImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 84, height: 84)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            } else {
                Image(systemName: "paperclip")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 3) {
                Text("AleClip")
                    .font(.system(size: 22, weight: .bold))
                Text(locF("about.version", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0", Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "2"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Developer Credit
            Text(loc("about.developedBy"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            Text(loc("about.tagline"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            // Philosophy & Highlights
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "hand.raised.slash.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 11))
                    Text(loc("settings.about.zeroData"))
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )

                HStack(spacing: 5) {
                    Image(systemName: "gift.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 11))
                    Text(loc("settings.about.freeEveryone"))
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )

                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text(loc("settings.about.freeFork"))
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }

            Divider().frame(width: 360)

            VStack(spacing: 4) {
                Text(locF("settings.about.clipsStats", storage.clips.count, storage.clips.filter { $0.isPinned }.count))
                    .font(.caption.bold())
                Text(loc("settings.about.localOnly"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(loc("settings.about.techStack"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Reusable Settings Card

    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
