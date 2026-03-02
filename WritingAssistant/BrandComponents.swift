import SwiftUI

// MARK: - Brand Button Style

struct BrandButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    var prominent: Bool = true
    var tint: Color? = nil

    private var resolvedTint: Color { tint ?? Brand.accentColor }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .default))
            .tracking(0.3)
            .foregroundStyle(prominent ? .white : resolvedTint)
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background {
                if prominent {
                    Capsule()
                        .fill(isEnabled
                            ? (configuration.isPressed ? resolvedTint.opacity(0.85) : resolvedTint)
                            : resolvedTint.opacity(0.35))
                        .shadow(
                            color: resolvedTint.opacity(isEnabled && !configuration.isPressed ? 0.25 : 0),
                            radius: 4, y: 2
                        )
                } else {
                    Capsule()
                        .fill(resolvedTint.opacity(configuration.isPressed ? 0.15 : 0.08))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Brand Badge

struct BrandBadge: View {
    let iconName: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .tracking(0.4)
        }
        .foregroundStyle(Brand.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Brand.accentColor.opacity(0.10))
                .overlay(
                    Capsule()
                        .strokeBorder(Brand.accentColor.opacity(0.15), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    enum Status: Equatable {
        case processing
        case done
        case error(String)
        case info(String)

        static func == (lhs: Status, rhs: Status) -> Bool {
            switch (lhs, rhs) {
            case (.processing, .processing), (.done, .done): return true
            case (.error(let a), .error(let b)): return a == b
            case (.info(let a), .info(let b)): return a == b
            default: return false
            }
        }
    }

    let status: Status

    private var text: String {
        switch status {
        case .processing: "Processing\u{2026}"
        case .done: "Done"
        case .error(let msg): msg
        case .info(let msg): msg
        }
    }

    private var foreground: Color {
        switch status {
        case .processing: .secondary
        case .done: Brand.successColor
        case .error: Brand.errorColor
        case .info: Brand.accentColor
        }
    }

    private var dotColor: Color {
        switch status {
        case .processing: Brand.midGrayColor
        case .done: Brand.successColor
        case .error: Brand.errorColor
        case .info: Brand.accentColor
        }
    }

    private var background: Color {
        switch status {
        case .processing: Color(nsColor: .labelColor).opacity(0.05)
        case .done: Brand.successColor.opacity(0.08)
        case .error: Brand.errorColor.opacity(0.08)
        case .info: Brand.accentColor.opacity(0.08)
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .tracking(0.2)
        }
        .foregroundStyle(foreground)
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(background)
        )
    }
}

// MARK: - Quote Block

struct QuoteBlock: View {
    let text: String
    var maxLines: Int = 2

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Accent bar — sage green, editorial feel
            RoundedRectangle(cornerRadius: 1)
                .fill(Brand.accentColor.opacity(0.5))
                .frame(width: 2.5)
                .padding(.vertical, 6)
                .padding(.leading, 10)

            Text(text)
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(.secondary)
                .lineLimit(maxLines)
                .truncationMode(.tail)
                .lineSpacing(2)
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Brand.subtleColor.opacity(0.5))
        )
    }
}

// MARK: - Brand Section Header

struct BrandSectionHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.tertiary)
                .padding(.leading, 14)
                .padding(.bottom, 4)

            // Hairline separator
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.4))
                .frame(height: 0.5)
                .padding(.horizontal, 10)
        }
        .frame(height: Brand.Layout.sectionHeaderHeight, alignment: .bottom)
        .padding(.top, 2)
    }
}

// MARK: - Style Row

struct StyleRow: View {
    let iconName: String
    let title: String
    let isHighlighted: Bool
    var shortcutNumber: Int? = nil
    let action: () -> Void

    @State private var isHovered = false

    private var showActive: Bool { isHovered || isHighlighted }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 13))
                    .frame(width: 20)
                    .foregroundStyle(showActive ? Brand.accentColor : .secondary)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(showActive ? .primary : .primary)
                Spacer()
                if let num = shortcutNumber {
                    Text("\(num)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 16, height: 16)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(nsColor: .labelColor).opacity(0.06))
                        )
                }
            }
            .padding(.horizontal, 10)
            .frame(height: Brand.Layout.rowHeight)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(showActive ? Brand.accentColor.opacity(0.10) : Color.clear)
                    .padding(.horizontal, 4)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Thin Divider

struct BrandDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.3))
            .frame(height: 0.5)
    }
}

// MARK: - Keyboard Key

struct KeyboardKey: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(Brand.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Brand.accentColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Brand.accentColor.opacity(0.18), lineWidth: 0.5)
                    )
                    .shadow(color: Brand.accentColor.opacity(0.06), radius: 1, y: 1)
            )
    }
}

// MARK: - Hotkey Recorder View

struct HotkeyRecorderView: View {
    @Binding var hotkeyString: String
    var onHotkeyChanged: ((_ modifiers: CGEventFlags, _ keyCode: CGKeyCode) -> Void)?

    @State private var isRecording = false
    @State private var pulseOpacity: Double = 1.0
    @State private var monitor: Any?

    var body: some View {
        Button {
            startRecording()
        } label: {
            Text(isRecording ? "Press shortcut\u{2026}" : hotkeyString)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(isRecording ? .primary : Brand.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isRecording ? Brand.accentColor.opacity(0.15) : Brand.accentColor.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(
                                    isRecording ? Brand.accentColor : Brand.accentColor.opacity(0.18),
                                    lineWidth: isRecording ? 1.5 : 0.5
                                )
                        )
                )
                .opacity(isRecording ? pulseOpacity : 1.0)
        }
        .buttonStyle(.plain)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true

        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.5
        }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags
            let keyCode = event.keyCode

            // Escape cancels recording
            if keyCode == 53 {
                stopRecording()
                return nil
            }

            // Must have at least one modifier (Control, Option, or Command)
            let hasModifier = flags.contains(.control) || flags.contains(.option) || flags.contains(.command)
            guard hasModifier else { return nil }

            // Build CGEventFlags from NSEvent modifier flags
            var cgFlags: CGEventFlags = []
            if flags.contains(.control) { cgFlags.insert(.maskControl) }
            if flags.contains(.option) { cgFlags.insert(.maskAlternate) }
            if flags.contains(.shift) { cgFlags.insert(.maskShift) }
            if flags.contains(.command) { cgFlags.insert(.maskCommand) }

            let cgKeyCode = CGKeyCode(keyCode)

            // Update display
            hotkeyString = GlobalHotkeyManager.shared.hotkeyDisplayStringFor(
                modifiers: cgFlags, keyCode: cgKeyCode
            )

            onHotkeyChanged?(cgFlags, cgKeyCode)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        pulseOpacity = 1.0
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}

