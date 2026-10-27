import SwiftUI
import AppKit

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case shortcuts = "Shortcuts"
    case sequential = "Sequential"
    case mcp = "AI & MCP"
    case sync = "Cloud Sync"
    case exclusions = "Exclusions"
    case backup = "Backup"
    case about = "About"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: return loc("settings.tab.general")
        case .shortcuts: return loc("settings.tab.shortcuts")
        case .sequential: return "Sequential"
        case .mcp: return "AI & MCP"
        case .sync: return "Cloud Sync"
        case .exclusions: return loc("settings.tab.exclusions")
        case .backup: return loc("settings.tab.backup")
        case .about: return loc("settings.tab.about")
        }
    }

    public var iconName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .shortcuts: return "keyboard.fill"
        case .sequential: return "list.number"
        case .mcp: return "sparkles"
        case .sync: return "arrow.triangle.2.circlepath.icloud.fill"
        case .exclusions: return "hand.raised.fill"
        case .backup: return "externaldrive.fill"
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

struct SettingsTabButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : (configuration.isPressed ? Color.primary.opacity(0.10) : Color.clear))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .contentShape(Rectangle())
    }
}

public struct SettingsView: View {
    @ObservedObject private var storage = StorageService.shared
    @ObservedObject private var l10n = LocalizationService.shared
    @ObservedObject private var seqQueue = SequentialPasteService.shared
    @ObservedObject private var cloudSync = CloudSyncService.shared
    @ObservedObject private var privacy = ScreenPrivacyService.shared
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
                    case .sequential:
                        sequentialContent
                    case .mcp:
                        mcpContent
                    case .sync:
                        syncContent
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
        .frame(width: 740, height: 570)
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
        HStack(spacing: 4) {
            Spacer()
            ForEach(SettingsTab.allCases) { tab in
                let isSelected = model.selectedTab == tab
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        model.selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                            .frame(height: 20)

                        Text(tab.title)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minWidth: 72)
                    .foregroundColor(isSelected ? .accentColor : .primary.opacity(0.8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(SettingsTabButtonStyle(isSelected: isSelected))
                .onHover { isHovering in
                    if isHovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: - General Content

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // History Limits & Unlimited Card
            settingsCard(title: "Clipboard History Capacity", icon: "clock.arrow.circlepath") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Unlimited Clipboard History", isOn: $storage.settings.unlimitedHistory)
                        .font(.system(size: 13, weight: .medium))
                        .onChange(of: storage.settings.unlimitedHistory) { _, newValue in
                            if newValue {
                                storage.settings.historyLimit = 0
                            } else if storage.settings.historyLimit == 0 {
                                storage.settings.historyLimit = 200
                            }
                            storage.saveSettings()
                        }

                    if !storage.settings.unlimitedHistory {
                        HStack {
                            Text(loc("settings.general.maxItems"))
                                .font(.system(size: 13))
                            Spacer()
                            Picker("", selection: $storage.settings.historyLimit) {
                                Text("50 clips").tag(50)
                                Text("100 clips").tag(100)
                                Text("200 clips").tag(200)
                                Text("500 clips").tag(500)
                                Text("1,000 clips").tag(1000)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 140)
                            .onChange(of: storage.settings.historyLimit) { _, _ in
                                storage.saveSettings()
                            }
                        }
                    }

                    Text("When unlimited is enabled, all copied text, links, code, images, and colors are saved without losing previous entries.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Privacy & Sensitive Data Card
            settingsCard(title: "Privacy Controls", icon: "shield.lefthalf.filled") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Screen-Sharing Privacy (Auto-hide during screen sharing & presentations)", isOn: $privacy.autoShieldOnScreenShare)
                        .font(.system(size: 13))

                    Toggle("Automatically detect & mask sensitive info (API keys, tokens, credit cards)", isOn: $storage.settings.maskSensitiveData)
                        .font(.system(size: 13))
                        .onChange(of: storage.settings.maskSensitiveData) { _, _ in
                            storage.saveSettings()
                        }

                    Text("Sensitive pasteboards (such as password manager transients) are automatically ignored.")
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

                    Toggle(loc("settings.general.plainTextAlways"), isOn: $storage.settings.plainTextAlways)
                        .font(.system(size: 13))
                        .onChange(of: storage.settings.plainTextAlways) { _, _ in
                            storage.saveSettings()
                        }
                }
            }

            // Startup & Sound
            settingsCard(title: "Startup & Feedback", icon: "power") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(loc("settings.general.launchAtLogin"), isOn: $storage.settings.launchAtLogin)
                        .font(.system(size: 13))
                        .onChange(of: storage.settings.launchAtLogin) { _, newValue in
                            storage.saveSettings()
                            LaunchAtLoginManager.shared.setEnabled(newValue)
                        }

                    Toggle(loc("settings.general.soundEffects"), isOn: $storage.settings.soundEffects)
                        .font(.system(size: 13))
                        .onChange(of: storage.settings.soundEffects) { _, _ in
                            storage.saveSettings()
                        }
                }
            }
        }
    }

    // MARK: - Shortcuts Content

    private var shortcutsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Global Panel Shortcut", icon: "command") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Open Clipboard History:")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $storage.settings.selectedShortcut) {
                            ForEach(GlobalShortcutOption.allCases) { option in
                                Text(option.rawValue).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 240)
                        .onChange(of: storage.settings.selectedShortcut) { _, _ in
                            storage.saveSettings()
                            HotkeyManager.shared.applyConfiguredHotkey()
                        }
                    }
                }
            }

            settingsCard(title: "Configured Keyboard Shortcuts", icon: "keyboard") {
                VStack(spacing: 8) {
                    shortcutRow(keys: ["⇧", "⌘", "V"], action: "Open clipboard history")
                    shortcutRow(keys: ["⌘", "F"], action: "Search clipboard")
                    shortcutRow(keys: ["⌘", "E"], action: "Edit selected item")
                    shortcutRow(keys: ["⌘", "R"], action: "Rename selected item")
                    shortcutRow(keys: ["⇧", "⌘", "N"], action: "Create new collection")
                    shortcutRow(keys: ["⌘", "N"], action: "Create new text item")
                    shortcutRow(keys: ["⌘", "T"], action: "Pause clipboard monitoring")
                    shortcutRow(keys: ["Space"], action: "Preview selected item (Quick Look)")
                    shortcutRow(keys: ["⌘", "1...9"], action: "Quick Paste items 1 to 9")
                    shortcutRow(keys: ["⇧", "↵"], action: "Paste as Plain Text")
                    shortcutRow(keys: ["⌘", "Z"], action: "Undo last deletion")
                    shortcutRow(keys: ["Esc"], action: "Dismiss panel")
                }
            }
        }
    }

    // MARK: - Sequential Paste Content

    private var sequentialContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Sequential Copy & Paste (Queue Mode)", icon: "list.number") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Sequential Copy & Paste Queue", isOn: $seqQueue.isQueueActive)
                        .font(.system(size: 13, weight: .semibold))

                    Text("When active, copied items enter a queue. Pasting automatically inserts each item in order (FIFO or LIFO) and advances to the next.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    HStack {
                        Text("Queue Mode:")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $seqQueue.isFIFO) {
                            Text("First-In First-Out (FIFO)").tag(true)
                            Text("Last-In First-Out (LIFO)").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 250)
                    }

                    if !seqQueue.queue.isEmpty {
                        HStack {
                            Text("Currently Queued: \(seqQueue.queue.count) items")
                                .font(.caption.bold())
                            Spacer()
                            Button("Clear Queue") {
                                seqQueue.clearQueue()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    // MARK: - AI & MCP Content

    private var mcpContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Model Context Protocol (MCP) Integration", icon: "sparkles") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("AleClip includes native Model Context Protocol (MCP) server support, allowing AI assistants in Claude Desktop, Cursor, VS Code, and Codex to access clipboard history, perform OCR search, and insert clips.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Divider()

                    Text("How to Connect with Claude Desktop & Cursor:")
                        .font(.caption.bold())

                    Text("""
Add this entry to your `claude_desktop_config.json` or Cursor MCP settings:

```json
{
  "mcpServers": {
    "aleclip": {
      "command": "/Applications/AleClip.app/Contents/MacOS/aleclip",
      "args": ["--mcp"]
    }
  }
}
```
""")
                    .font(.system(size: 11, design: .monospaced))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                    .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Cloud Sync Content

    private var syncContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Google Drive / Cloud Sync Card
            settingsCard(title: "Google Drive & Cloud Sync", icon: "externaldrive.badge.icloud") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Synchronize your unlimited clipboard history, pinboards, and snippets securely across your devices via Google Drive or cloud storage.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    // Provider Picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sync Provider")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        Picker("", selection: $cloudSync.selectedProvider) {
                            ForEach(SyncProvider.allCases) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: cloudSync.selectedProvider) { _, _ in
                            cloudSync.saveSettings()
                        }
                    }

                    // Account & Folder Info Box
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: cloudSync.selectedProvider == .googleDrive ? "externaldrive.badge.checkmark" : "folder.fill")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 16))

                            VStack(alignment: .leading, spacing: 2) {
                                if cloudSync.selectedProvider == .googleDrive {
                                    HStack(spacing: 6) {
                                        Text("Google Drive Account:")
                                            .font(.system(size: 11.5, weight: .semibold))
                                        Text(cloudSync.detectedGoogleDriveAccount ?? "themanoftalent@gmail.com")
                                            .font(.system(size: 11.5, weight: .bold))
                                            .foregroundColor(.accentColor)
                                    }
                                }

                                HStack(spacing: 6) {
                                    Text("Sync Folder:")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text(cloudSync.displayPath)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Button("Choose Folder…") {
                                cloudSync.chooseCustomFolder()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                    }

                    // Auto-sync Toggle
                    Toggle("Automatically sync changes to \(cloudSync.selectedProvider.rawValue)", isOn: $cloudSync.isSyncEnabled)
                        .font(.system(size: 13, weight: .medium))
                        .onChange(of: cloudSync.isSyncEnabled) { _, _ in
                            cloudSync.saveSettings()
                        }

                    Divider()

                    // Action Buttons: Sync Now & Open in Finder
                    HStack(spacing: 12) {
                        Button(action: {
                            cloudSync.syncNow()
                        }) {
                            HStack(spacing: 6) {
                                if cloudSync.isSyncing {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                Text(cloudSync.isSyncing ? "Syncing…" : "Sync Now")
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(cloudSync.isSyncing)

                        Button(action: {
                            cloudSync.openSyncFolderInFinder()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "folder")
                                    .font(.system(size: 11))
                                Text("Open in Google Drive / Finder")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Text(cloudSync.syncStatusMessage)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(cloudSync.syncStatusMessage.contains("failed") ? .red : .secondary)
                            .lineLimit(1)
                    }
                }
            }

            // Shared Collections Card
            settingsCard(title: "Shared Collections", icon: "folder.badge.plus") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Export collections into shareable `.aleclipcollection` bundles for team collaboration or import shared collections from peers.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button("Export Collection Bundle…") {
                            exportFirstCollection()
                        }
                        .buttonStyle(.bordered)
                        .disabled(storage.collections.isEmpty)

                        Button("Import Shared Collection…") {
                            importSharedCollection()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func exportFirstCollection() {
        guard let col = storage.collections.first else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(col.name).aleclipcollection.json"
        if panel.runModal() == .OK, let url = panel.url {
            let colClips = storage.clips.filter { $0.collectionId == col.id }
            try? cloudSync.exportCollection(col, clips: colClips, to: url)
            model.activeAlert = .info("Exported collection '\(col.name)' successfully.")
        }
    }

    private func importSharedCollection() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let res = try cloudSync.importCollection(from: url)
                if let col = res.collection {
                    model.activeAlert = .info("Imported collection '\(col.name)' with \(res.count) items.")
                }
            } catch {
                model.activeAlert = .info("Failed to import collection: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Exclusions Content

    private var exclusionsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: loc("settings.exclusions.title"), icon: "hand.raised") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc("settings.exclusions.help"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ScrollView {
                        VStack(spacing: 6) {
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
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .windowBackgroundColor)))
                            }
                        }
                    }
                    .frame(height: 140)

                    HStack(spacing: 8) {
                        Button(loc("settings.exclusions.chooseApp")) {
                            chooseApplication()
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                }
            }
        }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
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
            settingsCard(title: loc("settings.backup.title"), icon: "externaldrive.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc("settings.backup.help"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button("Quick Backup Now") {
                            if let url = storage.createBackup() {
                                model.activeAlert = .info("Backup saved to:\n\(url.lastPathComponent)")
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button(loc("settings.backup.exportBtn")) {
                            exportHistory()
                        }
                        .buttonStyle(.bordered)

                        Button(loc("settings.backup.importBtn")) {
                            importHistory()
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider()

                    Text("Automatic Recovery: In the unlikely event of system corruption or crash, AleClip automatically preserves previous history files with timestamped `.bak` archives and restores active history safely.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
        VStack(spacing: 16) {
            Spacer().frame(height: 4)

            if let image = NSApp.applicationIconImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            } else {
                Image(systemName: "paperclip")
                    .font(.system(size: 54))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 3) {
                Text("AleClip")
                    .font(.system(size: 20, weight: .bold))
                Text(locF("about.version", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.1.0", Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "2026"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(loc("about.tagline"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            OpenSourceCard()
                .frame(maxWidth: 520)

            FollowSupportCard()
                .frame(maxWidth: 520)

            Divider().frame(width: 360)

            VStack(spacing: 4) {
                Text(locF("settings.about.clipsStats", storage.clips.count, storage.clips.filter { $0.isPinned }.count))
                    .font(.caption.bold())
                Text(loc("settings.about.localOnly"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer().frame(height: 10)
        }
        .frame(maxWidth: .infinity)
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
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color(nsColor: .windowBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.15), lineWidth: 1))
                }
            }
        }
        .padding(.vertical, 2.5)
    }

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
