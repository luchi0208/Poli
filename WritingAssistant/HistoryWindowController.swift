@preconcurrency import AppKit
import Foundation
import SwiftUI

// MARK: - History Content View

struct HistoryContentView: View {
    @State private var entries: [HistoryEntry] = HistoryStore.shared.entries
    @State private var selectedEntry: HistoryEntry?
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let entry = selectedEntry {
                historyDetailView(entry: entry)
            } else {
                historyListView
            }
        }
        .frame(width: 480, height: 420)
        .background(Brand.surfaceColor)
    }

    // MARK: - List View

    private var historyListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .tracking(0.3)
                Spacer()
                if !entries.isEmpty {
                    Button("Clear All") {
                        HistoryStore.shared.clearAll()
                        entries = []
                    }
                    .buttonStyle(BrandButtonStyle(prominent: false, tint: Brand.errorColor))
                }
                Button("Done") { onDone() }
                    .buttonStyle(BrandButtonStyle())
                    .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.top, 20)
            .padding(.horizontal, Brand.Layout.margin)
            .padding(.bottom, 12)

            BrandDivider()

            if entries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No history yet")
                        .font(Brand.Typography.body)
                        .foregroundStyle(.secondary)
                    Text("Accepted transformations will appear here")
                        .font(Brand.Typography.captionSecondary)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(entries) { entry in
                            HistoryRowView(entry: entry) {
                                selectedEntry = entry
                            }
                            BrandDivider()
                                .padding(.horizontal, Brand.Layout.margin)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Detail View

    private func historyDetailView(entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with back button
            HStack {
                Button {
                    selectedEntry = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Back")
                            .font(Brand.Typography.body)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Brand.accentColor)

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: entry.actionIconName)
                        .font(.system(size: 12))
                    Text(entry.actionDisplayName)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .padding(.horizontal, Brand.Layout.margin)
            .padding(.bottom, 12)

            BrandDivider()

            // Side by side original vs result
            HStack(alignment: .top, spacing: 12) {
                // Original
                VStack(alignment: .leading, spacing: 6) {
                    Text("ORIGINAL")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(.tertiary)
                    ScrollView {
                        Text(entry.originalPreview)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: .infinity)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: Brand.Layout.smallCornerRadius)
                            .fill(Brand.subtleColor.opacity(0.5))
                    )
                    Text("\(entry.originalWordCount) words")
                        .font(Brand.Typography.stats)
                        .foregroundStyle(.tertiary)
                }

                // Result
                VStack(alignment: .leading, spacing: 6) {
                    Text("RESULT")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(.tertiary)
                    ScrollView {
                        Text(entry.resultPreview)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: .infinity)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: Brand.Layout.smallCornerRadius)
                            .fill(Brand.subtleColor.opacity(0.5))
                    )
                    Text("\(entry.resultWordCount) words (\(entry.wordCountDeltaString))")
                        .font(Brand.Typography.stats)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, Brand.Layout.margin)
            .padding(.bottom, Brand.Layout.margin)
        }
    }
}

// MARK: - History Row View

struct HistoryRowView: View {
    let entry: HistoryEntry
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: entry.actionIconName)
                    .font(.system(size: 13))
                    .foregroundStyle(isHovered ? Brand.accentColor : Brand.midGrayColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.actionDisplayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(entry.date, style: .relative)
                            .font(Brand.Typography.captionSecondary)
                            .foregroundStyle(.tertiary)
                    }
                    Text(entry.originalPreview.prefix(80) + (entry.originalPreview.count > 80 ? "\u{2026}" : ""))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Brand.Layout.margin)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Brand.accentColor.opacity(0.06) : Color.clear)
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

// MARK: - History Window Controller

@MainActor
final class HistoryWindowController {
    static let shared = HistoryWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "History"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        self.window = window

        let historyView = HistoryContentView(
            onDone: { [weak self] in
                self?.window?.close()
                self?.window = nil
            }
        )

        let hostingView = NSHostingView(rootView: historyView)
        window.contentView = hostingView

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
