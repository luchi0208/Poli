@preconcurrency import AppKit
import ApplicationServices
import Foundation
import SwiftUI

@MainActor
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    // nonisolated(unsafe) so the C callback can access without actor hop
    nonisolated(unsafe) var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?

    // Default hotkey: Control+Option+C
    nonisolated static let defaultModifiers: CGEventFlags = [.maskControl, .maskAlternate]
    nonisolated static let defaultKeyCode: CGKeyCode = 0x08 // 'C' key

    private static let modifiersKey = "hotkeyModifiers"
    private static let keyCodeKey = "hotkeyKeyCode"

    nonisolated(unsafe) var modifiers: CGEventFlags = GlobalHotkeyManager.defaultModifiers
    nonisolated(unsafe) var keyCode: CGKeyCode = GlobalHotkeyManager.defaultKeyCode

    private init() {}

    func loadSavedHotkey() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.modifiersKey) != nil {
            let rawMods = defaults.integer(forKey: Self.modifiersKey)
            modifiers = CGEventFlags(rawValue: UInt64(rawMods))
            keyCode = CGKeyCode(defaults.integer(forKey: Self.keyCodeKey))
        }
    }

    private func saveHotkey() {
        let defaults = UserDefaults.standard
        defaults.set(Int(modifiers.rawValue), forKey: Self.modifiersKey)
        defaults.set(Int(keyCode), forKey: Self.keyCodeKey)
    }

    func updateHotkey(modifiers newMods: CGEventFlags, keyCode newKey: CGKeyCode) {
        modifiers = newMods
        keyCode = newKey
        saveHotkey()
        restart()
    }

    func resetToDefault() {
        modifiers = Self.defaultModifiers
        keyCode = Self.defaultKeyCode
        saveHotkey()
        restart()
    }

    var isDefault: Bool {
        modifiers == Self.defaultModifiers && keyCode == Self.defaultKeyCode
    }

    func start() {
        guard eventTap == nil else {
            print("[Hotkey] Already started")
            return
        }

        guard AXIsProcessTrusted() else {
            print("[Hotkey] Accessibility not granted — cannot create event tap")
            // Retry after a delay (user may grant permission later)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.start()
            }
            return
        }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: globalHotkeyCallback,
            userInfo: refcon
        ) else {
            print("[Hotkey] Failed to create event tap even though AX is trusted")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[Hotkey] Event tap created and enabled. Shortcut: \(hotkeyDisplayString)")
        startHealthCheck()
    }

    func stop() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }

    /// Periodically verify the event tap is still alive and re-create if needed.
    private func startHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkTapHealth()
            }
        }
    }

    private func checkTapHealth() {
        guard let tap = eventTap else {
            print("[Hotkey] Health check: tap is nil, restarting...")
            restart()
            return
        }
        if !CGEvent.tapIsEnabled(tap: tap) {
            print("[Hotkey] Health check: tap was disabled, re-enabling...")
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func restart() {
        stop()
        start()
    }

    /// Read selected text using the Accessibility API.
    private nonisolated func readSelectedTextViaAX(pid: pid_t) -> String? {
        guard let focused = focusedElement(pid: pid) else { return nil }

        var selectedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectedRef
        ) == .success,
            let selectedText = selectedRef as? String
        else { return nil }

        return selectedText
    }

    /// Get the screen rect of the selected text via Accessibility.
    /// Returns the bottom-left corner and size in screen coordinates (origin at bottom-left).
    nonisolated func selectedTextBounds(pid: pid_t) -> NSRect? {
        guard let focused = focusedElement(pid: pid) else { return nil }

        // Get the selected text range
        var rangeRef: AnyObject?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeRef
        ) == .success else { return nil }

        // Get the bounds for that range (parameterized attribute)
        var boundsRef: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            focused,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeRef!,
            &boundsRef
        ) == .success else { return nil }

        // Extract CGRect from AXValue
        var cgRect = CGRect.zero
        guard AXValueGetValue(boundsRef as! AXValue, .cgRect, &cgRect) else { return nil }

        // AX returns screen coords with origin at top-left; convert to AppKit (bottom-left)
        guard let screen = NSScreen.main else { return nil }
        let flippedY = screen.frame.height - cgRect.origin.y - cgRect.height
        return NSRect(x: cgRect.origin.x, y: flippedY, width: cgRect.width, height: cgRect.height)
    }

    /// Get the focused AX element for a process.
    private nonisolated func focusedElement(pid: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)
        var focusedRef: AnyObject?

        if AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success {
            return (focusedRef as! AXUIElement)
        }

        let systemWide = AXUIElementCreateSystemWide()
        if AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success {
            return (focusedRef as! AXUIElement)
        }

        return nil
    }

    /// Simulate ⌘C, read the clipboard, then restore previous clipboard contents.
    private nonisolated func readSelectedTextViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general

        // Save current clipboard: each item may have multiple type representations
        let savedItems: [[(NSPasteboard.PasteboardType, Data)]] = pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        } ?? []
        let previousChangeCount = pasteboard.changeCount

        // Simulate ⌘C
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)

        // Wait for the target app to process the copy command
        Thread.sleep(forTimeInterval: 0.15)

        // Read the clipboard
        let copiedText: String?
        if pasteboard.changeCount != previousChangeCount {
            copiedText = pasteboard.string(forType: .string)
        } else {
            copiedText = nil
        }

        // Restore previous clipboard contents
        if !savedItems.isEmpty {
            pasteboard.clearContents()
            for itemTypes in savedItems {
                let newItem = NSPasteboardItem()
                for (type, data) in itemTypes {
                    newItem.setData(data, forType: type)
                }
                pasteboard.writeObjects([newItem])
            }
        }

        return copiedText
    }

    /// Trigger a specific style directly (used by menu bar recent items).
    /// The sourceApp must be reactivated before calling this.
    func triggerForStyle(_ style: WritingStyle, sourceApp: NSRunningApplication) {
        let pid = sourceApp.processIdentifier

        // Try AX first
        if let text = readSelectedTextViaAX(pid: pid), !text.isEmpty {
            RecentStyles.record(style)
            ResultWindowController.shared.show(
                originalText: text,
                action: .style(style),
                sourceApp: sourceApp
            )
            return
        }

        // Clipboard fallback on a background thread
        Task.detached { [weak self] in
            guard let self else { return }
            let text = self.readSelectedTextViaClipboard()
            await MainActor.run {
                if let text, !text.isEmpty {
                    RecentStyles.record(style)
                    ResultWindowController.shared.show(
                        originalText: text,
                        action: .style(style),
                        sourceApp: sourceApp
                    )
                } else {
                    self.showBriefNotification("Select text first, then press the shortcut.")
                }
            }
        }
    }

    /// Handle the hotkey press
    fileprivate func handleHotkey() {
        print("[Hotkey] Hotkey triggered!")
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            showBriefNotification("Select text first, then press the shortcut.")
            return
        }
        let pid = frontApp.processIdentifier

        // Get selection bounds for positioning (may be nil for non-AX apps)
        let selectionRect = selectedTextBounds(pid: pid)

        // Try AX first (synchronous, fast)
        if let text = readSelectedTextViaAX(pid: pid), !text.isEmpty {
            print("[Hotkey] Got text via AX (\(text.count) chars)")
            let context = detectContextIfEnabled(text)
            StylePickerHUD.shared.show(selectedText: text, sourceApp: frontApp, selectionRect: selectionRect, detectedContext: context)
            return
        }

        // Fall back to clipboard on a background thread to avoid blocking main
        print("[Hotkey] AX failed, trying clipboard fallback...")
        Task.detached { [weak self] in
            guard let self else { return }
            let text = self.readSelectedTextViaClipboard()
            await MainActor.run {
                if let text, !text.isEmpty {
                    print("[Hotkey] Got text via clipboard fallback (\(text.count) chars)")
                    let context = self.detectContextIfEnabled(text)
                    StylePickerHUD.shared.show(selectedText: text, sourceApp: frontApp, selectionRect: selectionRect, detectedContext: context)
                } else {
                    print("[Hotkey] Both AX and clipboard fallback failed")
                    self.showBriefNotification("Select text first, then press the shortcut.")
                }
            }
        }
    }

    private func detectContextIfEnabled(_ text: String) -> DetectedContext? {
        guard ContextSuggestionsPreference.isEnabled else { return nil }
        let context = ContextDetectionService.detectContext(for: text)
        if context != .general {
            print("[Hotkey] Detected context: \(context.displayName)")
        }
        return context
    }

    private func showBriefNotification(_ message: String) {
        let panel = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 60),
            styleMask: [.titled, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Poli"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isOpaque = false
        panel.backgroundColor = .clear

        let hudView = Text(message)
            .font(.system(size: 13))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(width: 300, height: 60)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Brand.Layout.cornerRadius))

        panel.contentView = NSHostingView(rootView: hudView)
        panel.center()
        panel.orderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            panel.close()
        }
    }

    var hotkeyDisplayString: String {
        hotkeyDisplayStringFor(modifiers: modifiers, keyCode: keyCode)
    }

    func hotkeyDisplayStringFor(modifiers mods: CGEventFlags, keyCode code: CGKeyCode) -> String {
        var parts: [String] = []
        if mods.contains(.maskControl) { parts.append("\u{2303}") }
        if mods.contains(.maskAlternate) { parts.append("\u{2325}") }
        if mods.contains(.maskShift) { parts.append("\u{21E7}") }
        if mods.contains(.maskCommand) { parts.append("\u{2318}") }
        parts.append(keyCodeToString(code))
        return parts.joined()
    }

    private func keyCodeToString(_ code: CGKeyCode) -> String {
        let map: [CGKeyCode: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x17: "5", 0x16: "6", 0x1A: "7", 0x1C: "8",
            0x19: "9", 0x1D: "0", 0x1F: "O", 0x20: "U", 0x22: "I",
            0x23: "P", 0x25: "L", 0x26: "J", 0x28: "K", 0x2D: "N",
            0x2E: "M",
        ]
        return map[code] ?? "?"
    }
}

// C callback for CGEvent tap — must be a free function
private func globalHotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Re-enable tap if it gets disabled by the system
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        print("[Hotkey] Event tap was disabled by system (\(type == .tapDisabledByTimeout ? "timeout" : "user input")), re-enabling...")
        if let refcon {
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            if let tap = manager.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                print("[Hotkey] Event tap re-enabled")
            }
        }
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown, let refcon else {
        return Unmanaged.passRetained(event)
    }

    let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags

    // Check if our hotkey combo is pressed
    let requiredMods = manager.modifiers
    let relevantFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
    let pressedMods = flags.intersection(relevantFlags)

    if keyCode == manager.keyCode && pressedMods.contains(requiredMods) && pressedMods.subtracting(requiredMods).isEmpty {
        DispatchQueue.main.async {
            manager.handleHotkey()
        }
        // Consume the event so it doesn't reach the app
        return nil
    }

    return Unmanaged.passRetained(event)
}
