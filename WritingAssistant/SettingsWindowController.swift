@preconcurrency import AppKit
import Foundation
import ServiceManagement
import SwiftUI

// MARK: - Settings Content View

struct SettingsContentView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var smartSuggestions = ContextSuggestionsPreference.isEnabled
    @State var hotkeyString: String
    @State var selectedLanguage: String
    let version: String
    let build: String
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // General section header
            Text("GENERAL")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.tertiary)
                .padding(.top, 28)
                .padding(.bottom, 10)

            // Shortcut row
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.system(size: 14))
                    .foregroundStyle(Brand.accentColor)
                    .frame(width: 20)
                Text("Keyboard Shortcut")
                    .font(Brand.Typography.body)
                Spacer()
                HotkeyRecorderView(hotkeyString: $hotkeyString) { mods, keyCode in
                    GlobalHotkeyManager.shared.updateHotkey(modifiers: mods, keyCode: keyCode)
                }
                if !GlobalHotkeyManager.shared.isDefault {
                    Button {
                        GlobalHotkeyManager.shared.resetToDefault()
                        hotkeyString = GlobalHotkeyManager.shared.hotkeyDisplayString
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reset to default (\u{2303}\u{2325}C)")
                }
            }
            .padding(.bottom, 14)

            BrandDivider()
                .padding(.bottom, 14)

            // Launch at Login
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(Brand.accentColor)
                    .frame(width: 20)
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .tint(Brand.accentColor)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !newValue
                        }
                    }
            }

            BrandDivider()
                .padding(.vertical, 14)

            // Smart Suggestions
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14))
                    .foregroundStyle(Brand.accentColor)
                    .frame(width: 20)
                Toggle("Smart Style Suggestions", isOn: $smartSuggestions)
                    .toggleStyle(.switch)
                    .tint(Brand.accentColor)
                    .onChange(of: smartSuggestions) { _, newValue in
                        ContextSuggestionsPreference.isEnabled = newValue
                    }
            }

            Text("Suggests styles based on detected text context (email, chat, code)")
                .font(Brand.Typography.captionSecondary)
                .foregroundStyle(.tertiary)
                .padding(.leading, 30)
                .padding(.top, 4)

            // Language section
            Text("LANGUAGE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.tertiary)
                .padding(.top, 28)
                .padding(.bottom, 10)

            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 14))
                    .foregroundStyle(Brand.accentColor)
                    .frame(width: 20)
                Text("Quick Translate")
                    .font(Brand.Typography.body)
                Spacer()
                Picker("", selection: $selectedLanguage) {
                    Text("None").tag("")
                    ForEach(PreferredLanguageManager.supportedLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .frame(width: 160)
                .onChange(of: selectedLanguage) { _, newValue in
                    PreferredLanguageManager.languageCode = newValue.isEmpty ? nil : newValue
                }
            }

            Text("Adds a quick translate option to the style picker")
                .font(Brand.Typography.captionSecondary)
                .foregroundStyle(.tertiary)
                .padding(.leading, 30)
                .padding(.top, 4)

            // About section
            Text("ABOUT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.tertiary)
                .padding(.top, 28)
                .padding(.bottom, 10)

            HStack(spacing: 10) {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 14))
                    .foregroundStyle(Brand.accentColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Writing Assistant v\(version)")
                        .font(Brand.Typography.bodyMedium)
                    Text("Build \(build) \u{00b7} Powered by Apple Intelligence")
                        .font(Brand.Typography.captionSecondary)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            BrandDivider()
                .padding(.bottom, 12)

            // Done button
            HStack {
                Spacer()
                Button("Done") { onDone() }
                    .buttonStyle(BrandButtonStyle())
                    .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal, Brand.Layout.margin)
        .padding(.bottom, Brand.Layout.margin)
        .frame(width: 420, height: 440)
        .background(Brand.surfaceColor)
    }
}

// MARK: - Settings Window Controller

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        self.window = window

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        let settingsView = SettingsContentView(
            hotkeyString: GlobalHotkeyManager.shared.hotkeyDisplayString,
            selectedLanguage: PreferredLanguageManager.languageCode ?? "",
            version: version,
            build: build,
            onDone: { [weak self] in
                self?.window?.close()
                self?.window = nil
            }
        )

        let hostingView = NSHostingView(rootView: settingsView)
        window.contentView = hostingView

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
