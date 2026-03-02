@preconcurrency import AppKit
import Foundation
import SwiftUI

// MARK: - Onboarding View Model

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep = 0
    var isAccessibilityGranted = AXIsProcessTrusted()

    func nextStep() {
        currentStep += 1
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }
}

// MARK: - Onboarding Content View

struct OnboardingContentView: View {
    @Bindable var viewModel: OnboardingViewModel
    let hotkeyString: String
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Brand.surfaceColor.ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch viewModel.currentStep {
                    case 0:
                        WelcomeStep(onNext: { viewModel.nextStep() })
                            .transition(.move(edge: .trailing))
                    case 1:
                        AccessibilityStep(
                            isGranted: viewModel.isAccessibilityGranted,
                            onOpenSettings: { viewModel.openAccessibilitySettings() },
                            onNext: { viewModel.nextStep() }
                        )
                        .transition(.move(edge: .trailing))
                    case 2:
                        HowToUseStep(
                            hotkeyString: hotkeyString,
                            onDone: onComplete
                        )
                        .transition(.move(edge: .trailing))
                    default:
                        EmptyView()
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)

                // Step dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { step in
                        Circle()
                            .fill(step == viewModel.currentStep
                                ? Brand.accentColor
                                : Brand.midGrayColor.opacity(0.4))
                            .frame(width: step == viewModel.currentStep ? 7 : 6,
                                   height: step == viewModel.currentStep ? 7 : 6)
                            .animation(.easeOut(duration: 0.2), value: viewModel.currentStep)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Step 0: Welcome

private struct WelcomeStep: View {
    let onNext: () -> Void

    private let features: [(icon: String, title: String, detail: String)] = [
        ("checkmark.circle", "Fix", "proofread and fix grammar"),
        ("briefcase", "Rewrite", "professional, casual, friendly, formal, creative, concise"),
        ("doc.plaintext", "Transform", "summarize, expand, key points"),
        ("text.bubble", "Custom", "your own prompt"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 36)

            Image(systemName: "pencil.and.outline")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Brand.accentColor)

            Text("Writing Assistant")
                .font(Brand.Typography.serifTitle)
                .padding(.top, 14)

            Text("AI-powered writing tools that work in every app.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(features, id: \.title) { feature in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(Brand.accentColor)
                            .frame(width: 18)
                        HStack(spacing: 0) {
                            Text(feature.title)
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                            Text(" \u{2014} \(feature.detail)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 40)

            Spacer()

            Button("Get Started") { onNext() }
                .buttonStyle(BrandButtonStyle())
                .keyboardShortcut(.return, modifiers: [])
                .padding(.bottom, 28)
        }
    }
}

// MARK: - Step 1: Accessibility

private struct AccessibilityStep: View {
    let isGranted: Bool
    let onOpenSettings: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 36)

            Image(systemName: "lock.shield")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Brand.accentColor)

            Text("Accessibility Permission")
                .font(Brand.Typography.serifHeading)
                .padding(.top, 14)

            Text("Writing Assistant needs Accessibility access to read selected text and replace it with the improved version.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .padding(.top, 8)

            Text("All processing happens on-device \u{2014} nothing is sent to the internet.")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .padding(.top, 6)

            // Status pill
            StatusPill(status: isGranted ? .info("Granted") : .error("Not Granted"))
                .padding(.top, 24)

            if !isGranted {
                Button("Open System Settings") { onOpenSettings() }
                    .buttonStyle(BrandButtonStyle(prominent: false))
                    .padding(.top, 16)
            }

            Spacer()

            Button("Continue") { onNext() }
                .buttonStyle(BrandButtonStyle())
                .keyboardShortcut(.return, modifiers: [])
                .padding(.bottom, 28)
        }
    }
}

// MARK: - Step 2: How to Use

private struct HowToUseStep: View {
    let hotkeyString: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 36)

            Image(systemName: "keyboard")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Brand.accentColor)

            Text("How to Use")
                .font(Brand.Typography.serifHeading)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 22) {
                // Keyboard shortcut method
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Brand.accentColor)
                        Text("Keyboard Shortcut")
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        stepRow("1", "Select text in any app")
                        HStack(spacing: 6) {
                            Text("2.")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(width: 18, alignment: .trailing)
                            Text("Press")
                                .font(Brand.Typography.caption)
                                .foregroundStyle(.secondary)
                            KeyboardKey(label: hotkeyString)
                        }
                        stepRow("3", "Pick a writing style")
                        stepRow("4", "Review and accept")
                    }
                }

            }
            .padding(.horizontal, 50)
            .padding(.top, 24)

            Spacer()

            Button("Done") { onDone() }
                .buttonStyle(BrandButtonStyle())
                .keyboardShortcut(.return, modifiers: [])
                .padding(.bottom, 28)
        }
    }

    private func stepRow(_ number: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Text("\(number).")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 18, alignment: .trailing)
            Text(text)
                .font(Brand.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Onboarding Window Controller

@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()

    private static let hasCompletedKey = "hasCompletedOnboarding"

    private var window: NSWindow?
    private var viewModel: OnboardingViewModel?
    private var axCheckTimer: Timer?

    var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: Self.hasCompletedKey)
    }

    private init() {}

    func showIfNeeded() {
        guard !hasCompletedOnboarding else { return }
        show()
    }

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let vm = OnboardingViewModel()
        self.viewModel = vm

        let contentView = OnboardingContentView(
            viewModel: vm,
            hotkeyString: GlobalHotkeyManager.shared.hotkeyDisplayString,
            onComplete: { [weak self] in
                self?.complete()
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Writing Assistant"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.contentView = NSHostingView(rootView: contentView)

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Poll AX status
        axCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.viewModel?.isAccessibilityGranted = AXIsProcessTrusted()
            }
        }
    }

    private func complete() {
        axCheckTimer?.invalidate()
        axCheckTimer = nil
        UserDefaults.standard.set(true, forKey: Self.hasCompletedKey)
        window?.close()
        window = nil
        viewModel = nil
    }
}
