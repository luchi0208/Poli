@preconcurrency import AppKit
import Foundation
import Sparkle

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var accessibilityStatusItem: NSMenuItem!
    private var hotkeyMenuItem: NSMenuItem!
    private var usageMenuItem: NSMenuItem!
    private var recentMenuItem: NSMenuItem!
    private var capturedSourceApp: NSRunningApplication?

    nonisolated static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        requestAccessibilityIfNeeded()
        GlobalHotkeyManager.shared.loadSavedHotkey()
        GlobalHotkeyManager.shared.start()
        OnboardingWindowController.shared.showIfNeeded()
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let result = AXIsProcessTrustedWithOptions(options)
        updateAccessibilityStatus(result)
    }

    private func updateAccessibilityStatus(_ granted: Bool) {
        if granted {
            accessibilityStatusItem.title = "Accessibility: Granted"
            accessibilityStatusItem.action = nil
            accessibilityStatusItem.isEnabled = false
        } else {
            accessibilityStatusItem.title = "Accessibility: Not Granted (click to fix)"
            accessibilityStatusItem.action = #selector(openAccessibilitySettings)
            accessibilityStatusItem.target = self
            accessibilityStatusItem.isEnabled = true
        }
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "pencil.and.outline",
                accessibilityDescription: "Writing Assistant"
            )
        }

        let menu = NSMenu()
        menu.delegate = self

        let headerItem = NSMenuItem(title: "Writing Assistant", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // AI Model status
        let availabilityTitle: String
        if WritingService.shared.isAvailable {
            availabilityTitle = "AI Model: Ready"
        } else {
            availabilityTitle = "AI Model: \(WritingService.shared.unavailableReason)"
        }
        let availabilityItem = NSMenuItem(title: availabilityTitle, action: nil, keyEquivalent: "")
        availabilityItem.isEnabled = false
        menu.addItem(availabilityItem)

        // Accessibility status
        accessibilityStatusItem = NSMenuItem(title: "Accessibility: Checking...", action: nil, keyEquivalent: "")
        accessibilityStatusItem.isEnabled = false
        menu.addItem(accessibilityStatusItem)

        menu.addItem(NSMenuItem.separator())

        // Usage stats
        usageMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        usageMenuItem.isEnabled = false
        menu.addItem(usageMenuItem)

        // Recent submenu
        recentMenuItem = NSMenuItem(title: "Recent", action: nil, keyEquivalent: "")
        let recentSubmenu = NSMenu()
        recentMenuItem.submenu = recentSubmenu
        menu.addItem(recentMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Hotkey info
        let hotkeyStr = GlobalHotkeyManager.shared.hotkeyDisplayString
        hotkeyMenuItem = NSMenuItem(
            title: "Shortcut: \(hotkeyStr) (select text first)",
            action: nil,
            keyEquivalent: ""
        )
        hotkeyMenuItem.isEnabled = false
        menu.addItem(hotkeyMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        // History
        let historyItem = NSMenuItem(
            title: "History...",
            action: #selector(showHistory),
            keyEquivalent: "h"
        )
        historyItem.target = self
        menu.addItem(historyItem)

        // Show Onboarding
        let onboardingItem = NSMenuItem(
            title: "Show Welcome Guide...",
            action: #selector(showOnboarding),
            keyEquivalent: ""
        )
        onboardingItem.target = self
        menu.addItem(onboardingItem)

        // Check for Updates
        let checkUpdatesItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkUpdatesItem.target = updaterController
        menu.addItem(checkUpdatesItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Writing Assistant",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateUsageMenuItem() {
        let daily = UsageTracker.shared.dailyCount
        let total = UsageTracker.shared.totalCount
        usageMenuItem.title = "Texts today: \(daily) | Total: \(total)"
    }

    private func updateRecentSubmenu() {
        guard let submenu = recentMenuItem.submenu else { return }
        submenu.removeAllItems()

        let recents = RecentStyles.styles
        if recents.isEmpty {
            let emptyItem = NSMenuItem(title: "No recent styles", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            for style in recents {
                let item = NSMenuItem(
                    title: style.displayName,
                    action: #selector(recentStyleClicked(_:)),
                    keyEquivalent: ""
                )
                item.image = NSImage(systemSymbolName: style.iconName, accessibilityDescription: style.displayName)
                item.target = self
                item.representedObject = style.rawValue as NSString
                submenu.addItem(item)
            }
        }
    }

    @objc private func recentStyleClicked(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let style = WritingStyle(rawValue: rawValue),
              let sourceApp = capturedSourceApp else { return }

        // Reactivate the source app so we can read its selection
        sourceApp.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            GlobalHotkeyManager.shared.triggerForStyle(style, sourceApp: sourceApp)
        }
    }

    @objc private func showOnboarding() {
        OnboardingWindowController.shared.show()
    }

    @objc private func showSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func showHistory() {
        HistoryWindowController.shared.show()
    }
}

extension AppDelegate: NSMenuDelegate {
    nonisolated func menuWillOpen(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            // Capture the app that was in the foreground before our menu opened
            capturedSourceApp = NSWorkspace.shared.frontmostApplication
            let trusted = AXIsProcessTrusted()
            updateAccessibilityStatus(trusted)
            updateUsageMenuItem()
            updateRecentSubmenu()
            let hotkeyStr = GlobalHotkeyManager.shared.hotkeyDisplayString
            hotkeyMenuItem.title = "Shortcut: \(hotkeyStr) (select text first)"
        }
    }
}
