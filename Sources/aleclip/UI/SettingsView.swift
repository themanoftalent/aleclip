import SwiftUI
import AppKit

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case shortcuts = "Shortcuts"
    case exclusions = "Exclusions"
    case backup = "Backup"
    case about = "About"

    public var id: String { rawValue }

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

final class SettingsViewModel: ObservableObject {
    @Published var selectedTab: SettingsTab = .general
    @Published var newBundleId: String = ""
    @Published var alertMessage: String?
    @Published var showAlert: Bool = false
}

public struct SettingsView: View {
    @ObservedObject private var storage = StorageService.shared
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
        .alert(isPresented: $model.showAlert) {
            Alert(
                title: Text("AleClip"),
                message: Text(model.alertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
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
                        Text(tab.rawValue)
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
            // History Limits Card
            settingsCard(title: "History Limits", icon: "clock.arrow.circlepath") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Maximum items stored in history:")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $storage.settings.historyLimit) {
                            Text("50 clips").tag(50)
                            Text("100 clips").tag(100)
                            Text("200 clips").tag(200)
                            Text("500 clips").tag(500)
                            Text("1000 clips").tag(1000)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                        .onChange(of: storage.settings.historyLimit) { _, _ in
                            storage.saveSettings()
                        }
                    }

                    Text("Older unpinned clips are automatically purged when history exceeds this limit. Pinned clips are always preserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Paste Behavior Card
            settingsCard(title: "Paste Behavior", icon: "doc.on.clipboard") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Paste directly into active application upon selection", isOn: $storage.settings.pasteIntoActiveApp)
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
                                Text(PasteService.shared.isAccessibilityTrusted ? "Accessibility Permission Granted" : "Accessibility Permission Required")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(PasteService.shared.isAccessibilityTrusted ? "AleClip can synthesize ⌘V directly into your active apps." : "macOS requires Accessibility access to simulate paste keystrokes.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if !PasteService.shared.isAccessibilityTrusted {
                                Button("Open System Settings") {
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

                    Toggle("Always paste as unformatted plain text (strip rich text & HTML styling)", isOn: $storage.settings.plainTextAlways)
                        .font(.system(size: 13))
                        .onChange(of: storage.settings.plainTextAlways) { _, _ in
                            storage.saveSettings()
                        }
                }
            }

            // Sound Effects Card
            settingsCard(title: "Audio Feedback", icon: "speaker.wave.2") {
                Toggle("Play sound feedback when copying or pasting clips", isOn: $storage.settings.soundEffects)
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
            settingsCard(title: "Global Activation Shortcut", icon: "command") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Shortcut to open/close AleClip:")
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

                    Text("Pressing this global shortcut from any app brings up the non-activating bottom panel without stealing window focus.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Keyboard Shortcuts Guide Card
            settingsCard(title: "In-Panel Keyboard Shortcuts", icon: "keyboard") {
                VStack(spacing: 8) {
                    shortcutRow(keys: ["⌥", "V"], action: "Open / Dismiss AleClip bottom panel")
                    shortcutRow(keys: ["←", "→"], action: "Navigate between clipboard cards")
                    shortcutRow(keys: ["↵"], action: "Paste selected clip into frontmost app")
                    shortcutRow(keys: ["⇧", "↵"], action: "Paste clip as unformatted plain text")
                    shortcutRow(keys: ["Space"], action: "Quick Look preview (text, images, links, files, colors)")
                    shortcutRow(keys: ["⌘", "E"], action: "Edit text clip content or assign custom title")
                    shortcutRow(keys: ["⌫"], action: "Delete selected clip from history")
                    shortcutRow(keys: ["Esc"], action: "Dismiss the panel without pasting")
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
            settingsCard(title: "Excluded Applications", icon: "hand.raised") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Copies made while any of these applications are frontmost will never be captured or stored.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // App List
                    ScrollView {
                        VStack(spacing: 6) {
                            if storage.settings.excludedBundleIds.isEmpty {
                                Text("No applications excluded yet.")
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
                        Button("Choose Application from Mac...") {
                            chooseApplication()
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }

                    HStack(spacing: 8) {
                        TextField("Or enter bundle ID (e.g. com.example.app)", text: $model.newBundleId)
                            .textFieldStyle(.roundedBorder)

                        Button("Add") {
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
            settingsCard(title: "History Backup & Restore", icon: "arrow.triangle.2.circlepath") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export your clipboard history as a standard JSON file, or restore from a previous backup. Duplicate clips are automatically skipped.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button("Export History to JSON...") {
                            exportHistory()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Import History from JSON...") {
                            importHistory()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            settingsCard(title: "Manage Stored Data", icon: "trash") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Remove all unpinned items from the history database. Pinned clips and preferences will remain intact.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Clear All Unpinned Clips", role: .destructive) {
                        storage.clearUnpinned()
                        model.alertMessage = "All unpinned clips have been cleared."
                        model.showAlert = true
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
                model.alertMessage = "History successfully exported!"
                model.showAlert = true
            } catch {
                model.alertMessage = "Export failed: \(error.localizedDescription)"
                model.showAlert = true
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
                model.alertMessage = "Successfully imported \(count) new clips!"
                model.showAlert = true
            } catch {
                model.alertMessage = "Import failed: \(error.localizedDescription)"
                model.showAlert = true
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
                Text("Version 1.0.0 (Build 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Developer Credit
            HStack(spacing: 5) {
                Text("Developed by")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text("Mehmet Akif Çifçi")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Text("A modern, lightweight native clipboard manager for macOS with card history, Quick Look, and non-activating bottom panel.")
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
                    Text("Zero Data Collection")
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
                    Text("100% Free for Everyone")
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
                    Text("Free to Fork & Customize")
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
                Text("\(storage.clips.count) clips in history • \(storage.clips.filter { $0.isPinned }.count) pinned")
                    .font(.caption.bold())
                Text("All clipboard content is stored strictly locally on your Mac. No network telemetry.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Built natively with Swift 6, AppKit, and SwiftUI.")
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
