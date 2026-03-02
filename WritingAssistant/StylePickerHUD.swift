@preconcurrency import AppKit
import Foundation
import SwiftUI

// MARK: - Recent Styles Storage

@MainActor
enum RecentStyles {
    private static let key = "recentStyleRawValues"
    private static let maxCount = 3

    static var styles: [WritingStyle] {
        let raw = UserDefaults.standard.stringArray(forKey: key) ?? []
        return raw.compactMap { WritingStyle(rawValue: $0) }
    }

    static func record(_ style: WritingStyle) {
        var raw = UserDefaults.standard.stringArray(forKey: key) ?? []
        raw.removeAll { $0 == style.rawValue }
        raw.insert(style.rawValue, at: 0)
        if raw.count > maxCount { raw = Array(raw.prefix(maxCount)) }
        UserDefaults.standard.set(raw, forKey: key)
    }
}

// MARK: - Row Item

enum RowItem: Identifiable {
    case suggestedHeader(DetectedContext)
    case suggestedStyle(WritingStyle)
    case recentHeader
    case recentStyle(WritingStyle)
    case quickTranslate(languageCode: String, displayName: String)
    case categoryHeader(StyleCategory)
    case style(WritingStyle)
    case savedPromptsHeader
    case savedPrompt(SavedCustomPrompt)
    case customPrompt

    var id: String {
        switch self {
        case .suggestedHeader(let c): "header-suggested-\(c.rawValue)"
        case .suggestedStyle(let s): "suggested-\(s.rawValue)"
        case .recentHeader: "header-recent"
        case .recentStyle(let s): "recent-\(s.rawValue)"
        case .quickTranslate(let code, _): "quick-translate-\(code)"
        case .categoryHeader(let c): "header-\(c.rawValue)"
        case .style(let s): "style-\(s.rawValue)"
        case .savedPromptsHeader: "header-saved"
        case .savedPrompt(let p): "saved-\(p.prompt.hashValue)"
        case .customPrompt: "custom-prompt"
        }
    }

    var isSelectable: Bool {
        switch self {
        case .suggestedHeader, .recentHeader, .categoryHeader, .savedPromptsHeader: false
        default: true
        }
    }
}

// MARK: - Style Picker View Model

@MainActor
@Observable
final class StylePickerViewModel {
    var rows: [RowItem] = []
    var highlightedIndex: Int = -1
    var detectedContext: DetectedContext?

    init(detectedContext: DetectedContext? = nil) {
        self.detectedContext = detectedContext
        buildRows()
    }

    private func buildRows() {
        rows = []

        // Suggested styles based on detected context (shown first)
        if let context = detectedContext, context != .general, !context.suggestedStyles.isEmpty {
            rows.append(.suggestedHeader(context))
            for style in context.suggestedStyles {
                rows.append(.suggestedStyle(style))
            }
        }

        // Show only the most recent style
        if let mostRecent = RecentStyles.styles.first {
            rows.append(.recentHeader)
            rows.append(.recentStyle(mostRecent))
        }
        // Quick translate row (if a preferred language is set)
        if let code = PreferredLanguageManager.languageCode,
           let name = PreferredLanguageManager.displayName {
            rows.append(.quickTranslate(languageCode: code, displayName: name))
        }
        for (category, styles) in WritingStyle.groupedByCategory {
            rows.append(.categoryHeader(category))
            for style in styles {
                rows.append(.style(style))
            }
        }
        let savedPrompts = SavedCustomPrompts.prompts
        if !savedPrompts.isEmpty {
            rows.append(.savedPromptsHeader)
            for prompt in savedPrompts {
                rows.append(.savedPrompt(prompt))
            }
        }
        rows.append(.customPrompt)
    }

    func moveHighlight(by delta: Int) {
        let selectableIndices = rows.indices.filter { rows[$0].isSelectable }
        guard !selectableIndices.isEmpty else { return }

        if highlightedIndex < 0 {
            highlightedIndex = delta > 0 ? selectableIndices.first! : selectableIndices.last!
        } else if let currentPos = selectableIndices.firstIndex(of: highlightedIndex) {
            let newPos = currentPos + delta
            if newPos >= 0, newPos < selectableIndices.count {
                highlightedIndex = selectableIndices[newPos]
            }
        } else {
            highlightedIndex = selectableIndices.first!
        }
    }

    func selectNthSelectable(_ n: Int) -> RowItem? {
        let selectableIndices = rows.indices.filter { rows[$0].isSelectable }
        guard n < selectableIndices.count else { return nil }
        return rows[selectableIndices[n]]
    }

    func selectedRow() -> RowItem? {
        guard highlightedIndex >= 0, highlightedIndex < rows.count else { return nil }
        return rows[highlightedIndex]
    }

    func computeHeight() -> CGFloat {
        var height: CGFloat = 8
        for row in rows {
            switch row {
            case .suggestedHeader, .recentHeader, .categoryHeader, .savedPromptsHeader:
                height += Brand.Layout.sectionHeaderHeight
            case .suggestedStyle, .recentStyle, .quickTranslate, .style, .customPrompt, .savedPrompt:
                height += Brand.Layout.rowHeight
            }
        }
        height += 12
        return min(height, 500)
    }
}

// MARK: - Style Picker Content View

struct StylePickerContentView: View {
    @Bindable var viewModel: StylePickerViewModel
    let onActionSelected: (WritingAction) -> Void
    let onCancel: () -> Void

    /// Maps row index to its 1-based shortcut number (only for selectable rows, max 9).
    private var shortcutMap: [Int: Int] {
        var map: [Int: Int] = [:]
        var counter = 1
        for (index, row) in viewModel.rows.enumerated() {
            guard row.isSelectable, counter <= 9 else { continue }
            map[index] = counter
            counter += 1
        }
        return map
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.rows.enumerated()), id: \.element.id) { index, row in
                        rowView(for: row, at: index)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: viewModel.highlightedIndex) { _, newIndex in
                if newIndex >= 0, newIndex < viewModel.rows.count {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(viewModel.rows[newIndex].id, anchor: .center)
                    }
                }
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Brand.Layout.cornerRadius))
    }

    @ViewBuilder
    private func rowView(for row: RowItem, at index: Int) -> some View {
        let shortcut = shortcutMap[index]
        switch row {
        case .suggestedHeader(let context):
            BrandSectionHeader(title: "Suggested for \(context.displayName)")
        case .suggestedStyle(let style):
            StyleRow(
                iconName: "wand.and.stars",
                title: style.displayName,
                isHighlighted: index == viewModel.highlightedIndex,
                shortcutNumber: shortcut
            ) {
                onActionSelected(.style(style))
            }
        case .recentHeader:
            BrandSectionHeader(title: "Recent")
        case .categoryHeader(let category):
            BrandSectionHeader(title: category.displayName)
        case .savedPromptsHeader:
            BrandSectionHeader(title: "Saved Prompts")
        case .quickTranslate(_, let displayName):
            StyleRow(
                iconName: "globe",
                title: "Translate to \(displayName)",
                isHighlighted: index == viewModel.highlightedIndex,
                shortcutNumber: shortcut
            ) {
                onActionSelected(.quickTranslate(languageName: displayName))
            }
        case .recentStyle(let style), .style(let style):
            StyleRow(
                iconName: style.iconName,
                title: style.displayName,
                isHighlighted: index == viewModel.highlightedIndex,
                shortcutNumber: shortcut
            ) {
                onActionSelected(.style(style))
            }
        case .savedPrompt(let saved):
            StyleRow(
                iconName: "star",
                title: saved.name,
                isHighlighted: index == viewModel.highlightedIndex,
                shortcutNumber: shortcut
            ) {
                onActionSelected(.custom(prompt: saved.prompt))
            }
        case .customPrompt:
            StyleRow(
                iconName: "text.bubble",
                title: "Custom Prompt\u{2026}",
                isHighlighted: index == viewModel.highlightedIndex,
                shortcutNumber: shortcut
            ) {
                onActionSelected(.custom(prompt: ""))
            }
        }
    }
}

// MARK: - Style Picker HUD

@MainActor
final class StylePickerHUD {
    static let shared = StylePickerHUD()

    private var panel: NSPanel?
    private var monitor: Any?
    private var localMonitor: Any?
    private var viewModel: StylePickerViewModel?

    private init() {}

    func show(selectedText: String, sourceApp: NSRunningApplication, selectionRect: NSRect? = nil, detectedContext: DetectedContext? = nil) {
        dismiss()

        let vm = StylePickerViewModel(detectedContext: detectedContext)
        self.viewModel = vm

        let panel = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 270, height: 0),
            styleMask: [.titled, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Pick a Style"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear

        let pickerView = StylePickerContentView(
            viewModel: vm,
            onActionSelected: { [weak self] action in
                self?.dismiss()
                if case .style(let style) = action {
                    RecentStyles.record(style)
                }
                ResultWindowController.shared.show(
                    originalText: selectedText,
                    action: action,
                    sourceApp: sourceApp
                )
            },
            onCancel: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: pickerView)
        panel.contentView = hostingView

        // Size to fit
        let height = vm.computeHeight()
        let width: CGFloat = 270
        panel.setContentSize(NSSize(width: width, height: height))

        // Position near selection or mouse
        let anchorPoint: NSPoint
        if let selectionRect, selectionRect.width > 0 {
            anchorPoint = NSPoint(
                x: selectionRect.midX - width / 2,
                y: selectionRect.minY - height - 4
            )
        } else {
            let mouse = NSEvent.mouseLocation
            anchorPoint = NSPoint(
                x: mouse.x - width / 2,
                y: mouse.y - height - 10
            )
        }

        // Keep on screen
        let panelOrigin: NSPoint
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(anchorPoint) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            let x = min(max(anchorPoint.x, visible.minX + 4), visible.maxX - width - 4)
            let y = min(max(anchorPoint.y, visible.minY + 4), visible.maxY - height - 4)
            panelOrigin = NSPoint(x: x, y: y)
        } else {
            panelOrigin = anchorPoint
        }
        panel.setFrameOrigin(panelOrigin)

        self.panel = panel
        panel.orderFront(nil)
        panel.makeKey()

        // Dismiss on click outside
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }

        // Keyboard navigation
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let vm = self.viewModel else { return event }

            switch event.keyCode {
            case 53: // Escape
                self.dismiss()
                return nil
            case 125: // Down
                vm.moveHighlight(by: 1)
                return nil
            case 126: // Up
                vm.moveHighlight(by: -1)
                return nil
            case 36: // Return
                if let row = vm.selectedRow() {
                    self.selectRow(row, selectedText: selectedText, sourceApp: sourceApp)
                }
                return nil
            default:
                if let char = event.characters?.first, let num = Int(String(char)), num >= 1 {
                    if let row = vm.selectNthSelectable(num - 1) {
                        self.selectRow(row, selectedText: selectedText, sourceApp: sourceApp)
                        return nil
                    }
                }
                return event
            }
        }
    }

    private func selectRow(_ row: RowItem, selectedText: String, sourceApp: NSRunningApplication) {
        switch row {
        case .quickTranslate(_, let displayName):
            dismiss()
            ResultWindowController.shared.show(
                originalText: selectedText,
                action: .quickTranslate(languageName: displayName),
                sourceApp: sourceApp
            )
        case .suggestedStyle(let style), .recentStyle(let style), .style(let style):
            dismiss()
            RecentStyles.record(style)
            ResultWindowController.shared.show(
                originalText: selectedText,
                action: .style(style),
                sourceApp: sourceApp
            )
        case .savedPrompt(let saved):
            dismiss()
            ResultWindowController.shared.show(
                originalText: selectedText,
                action: .custom(prompt: saved.prompt),
                sourceApp: sourceApp
            )
        case .customPrompt:
            dismiss()
            ResultWindowController.shared.show(
                originalText: selectedText,
                action: .custom(prompt: ""),
                sourceApp: sourceApp
            )
        default:
            break
        }
    }

    func dismiss() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        monitor = nil
        localMonitor = nil
        panel?.close()
        panel = nil
        viewModel = nil
    }
}
