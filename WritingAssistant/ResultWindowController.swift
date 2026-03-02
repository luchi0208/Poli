@preconcurrency import AppKit
import Foundation
import Lottie
import SwiftUI

// MARK: - Panel Subclasses

/// A floating panel that accepts key status for keyboard shortcuts but does not
/// activate the app — the source app keeps focus and text selection.
final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// A panel that starts non-activating but can become key when the user clicks to edit.
final class ResultPanel: NSPanel {
    var allowsKeyStatus = false

    override var canBecomeKey: Bool { allowsKeyStatus }
    override var canBecomeMain: Bool { false }
}

// MARK: - Result View Model

@MainActor
@Observable
final class ResultViewModel {
    var action: WritingAction
    let originalText: String
    var resultText: String = ""
    var isProcessing: Bool = false
    var isComplete: Bool = false
    var statusPillStatus: StatusPill.Status = .processing
    var showingDiff: Bool = false
    var diffSegment: Int = 0
    var statsText: String = ""
    var customPromptText: String = ""
    var isCustomPromptMode: Bool = false
    var detectedTone: DetectedTone?
    var isDetectingTone: Bool = false

    // Callbacks to bridge panel behavior
    var onAllowKeyStatus: ((Bool) -> Void)?
    var onMakeKey: (() -> Void)?

    init(action: WritingAction, originalText: String) {
        self.action = action
        self.originalText = originalText

        if case .custom(let p) = action, p.isEmpty {
            isCustomPromptMode = true
        }
    }

    var showSavePromptButton: Bool = false
    var promptSaved: Bool = false

    var isAcceptEnabled: Bool {
        isComplete && !resultText.isEmpty
    }

    var isRetryVisible: Bool {
        isComplete || statusPillStatus != .processing
    }

    var canSavePrompt: Bool {
        if case .custom(let prompt) = action, !prompt.isEmpty, isComplete, !resultText.isEmpty {
            return !SavedCustomPrompts.prompts.contains(where: { $0.prompt == prompt })
        }
        return false
    }

    var previewText: String {
        let preview = originalText.prefix(200)
        return String(preview) + (originalText.count > 200 ? "\u{2026}" : "")
    }

    func submitCustomPrompt() {
        let prompt = customPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        action = .custom(prompt: prompt)
        isCustomPromptMode = false
        onAllowKeyStatus?(false)
    }

    func updateStats() {
        let resultWords = wordCount(resultText)
        let resultChars = resultText.count
        let originalWords = wordCount(originalText)
        let readTimeMinutes = max(1, resultWords / 200)

        let diff = resultWords - originalWords
        let diffStr: String
        if diff > 0 {
            diffStr = "+\(diff)"
        } else if diff < 0 {
            diffStr = "\(diff)"
        } else {
            diffStr = "\u{b1}0"
        }

        statsText = "\(resultWords) words  \u{00b7}  \(resultChars) chars  \u{00b7}  ~\(readTimeMinutes) min read  \u{00b7}  \(diffStr) words"
    }

    func computeWordDiff() -> NSAttributedString {
        let orig = Self.tokenize(originalText)
        let result = Self.tokenize(resultText)

        let rawOps = Self.lcsDiff(old: orig, new: result)
        let ops = Self.charSubDiff(rawOps)

        let output = NSMutableAttributedString()
        let baseFont = NSFont.systemFont(ofSize: 14)
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
        ]
        let removedAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: Brand.error.withAlphaComponent(0.8),
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .strikethroughColor: Brand.error.withAlphaComponent(0.5),
            .backgroundColor: Brand.error.withAlphaComponent(0.08),
        ]
        let addedAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: Brand.success,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: Brand.success.withAlphaComponent(0.5),
            .backgroundColor: Brand.success.withAlphaComponent(0.08),
        ]

        for op in ops {
            switch op {
            case .equal(let token):
                output.append(NSAttributedString(string: token, attributes: defaultAttrs))
            case .delete(let token):
                output.append(NSAttributedString(string: token, attributes: removedAttrs))
            case .insert(let token):
                output.append(NSAttributedString(string: token, attributes: addedAttrs))
            }
        }

        return output
    }

    // MARK: - Tokenizer

    /// Splits text into word, punctuation, and whitespace tokens.
    /// e.g. "Hello, world." → ["Hello", ",", " ", "world", "."]
    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var currentKind: TokenKind?

        enum TokenKind { case word, punctuation, whitespace }

        func kindOf(_ c: Character) -> TokenKind {
            if c.isWhitespace { return .whitespace }
            if c.isLetter || c.isNumber || c == "'" || c == "\u{2019}" { return .word } // keep contractions together
            return .punctuation
        }

        for ch in text {
            let k = kindOf(ch)
            if k == currentKind {
                current.append(ch)
            } else {
                if !current.isEmpty { tokens.append(current) }
                current = String(ch)
                currentKind = k
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    // MARK: - LCS Diff

    /// LCS-based token diff producing a linear sequence of equal/delete/insert operations.
    private static func lcsDiff(old: [String], new: [String]) -> [DiffOp] {
        let m = old.count
        let n = new.count
        guard m > 0 || n > 0 else { return [] }

        // Build LCS length table
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                if old[i - 1] == new[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        // Backtrack to produce diff ops
        var ops: [DiffOp] = []
        var i = m, j = n
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && old[i - 1] == new[j - 1] {
                ops.append(.equal(old[i - 1]))
                i -= 1
                j -= 1
            } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
                ops.append(.insert(new[j - 1]))
                j -= 1
            } else {
                ops.append(.delete(old[i - 1]))
                i -= 1
            }
        }

        return ops.reversed()
    }

    // MARK: - Character-Level Sub-Diff

    /// Post-processes word-level diff: for adjacent delete/insert pairs of similar words,
    /// expands into character-level diffs so only changed characters are highlighted.
    private static func charSubDiff(_ ops: [DiffOp]) -> [DiffOp] {
        var result: [DiffOp] = []
        var idx = 0

        while idx < ops.count {
            // Look for a run of deletes followed by a run of inserts
            if case .delete = ops[idx] {
                var deletes: [String] = []
                var deleteStart = idx
                while idx < ops.count, case .delete(let w) = ops[idx] {
                    deletes.append(w)
                    idx += 1
                }
                var inserts: [String] = []
                while idx < ops.count, case .insert(let w) = ops[idx] {
                    inserts.append(w)
                    idx += 1
                }

                if inserts.isEmpty {
                    // Pure deletions, no inserts to pair with
                    for d in deletes { result.append(.delete(d)) }
                    continue
                }

                // Pair up deletes and inserts, expanding similar pairs to char-level diffs
                let pairCount = min(deletes.count, inserts.count)
                for p in 0..<pairCount {
                    let oldWord = deletes[p]
                    let newWord = inserts[p]

                    if oldWord == newWord {
                        result.append(.equal(oldWord))
                    } else if areSimilar(oldWord, newWord) {
                        // Character-level diff within the word pair
                        let charOps = lcsDiff(
                            old: oldWord.map(String.init),
                            new: newWord.map(String.init)
                        )
                        // Merge consecutive same-type char ops into strings
                        result.append(contentsOf: mergeCharOps(charOps))
                    } else {
                        result.append(.delete(oldWord))
                        result.append(.insert(newWord))
                    }
                }
                // Leftover unpaired deletes or inserts
                for p in pairCount..<deletes.count {
                    result.append(.delete(deletes[p]))
                }
                for p in pairCount..<inserts.count {
                    result.append(.insert(inserts[p]))
                }
            } else {
                result.append(ops[idx])
                idx += 1
            }
        }

        return result
    }

    /// Two words are "similar" if edit distance is less than half the longer word's length.
    /// This avoids noisy char-level diffs for completely different words.
    private static func areSimilar(_ a: String, _ b: String) -> Bool {
        let maxLen = max(a.count, b.count)
        guard maxLen > 0 else { return true }
        // Quick check: if one is empty and other isn't, not similar
        if a.isEmpty || b.isEmpty { return false }
        let dist = levenshtein(Array(a.lowercased()), Array(b.lowercased()))
        return dist <= maxLen / 2
    }

    /// Standard Levenshtein distance.
    private static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        let m = a.count, n = b.count
        if m == 0 { return n }
        if n == 0 { return m }
        var prev = Array(0...n)
        var curr = Array(repeating: 0, count: n + 1)
        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    curr[j] = prev[j - 1]
                } else {
                    curr[j] = 1 + min(prev[j], curr[j - 1], prev[j - 1])
                }
            }
            prev = curr
        }
        return prev[n]
    }

    /// Merge consecutive character-level DiffOps of the same type into single strings.
    private static func mergeCharOps(_ ops: [DiffOp]) -> [DiffOp] {
        var merged: [DiffOp] = []
        for op in ops {
            switch op {
            case .equal(let c):
                if case .equal(let prev) = merged.last {
                    merged[merged.count - 1] = .equal(prev + c)
                } else {
                    merged.append(.equal(c))
                }
            case .delete(let c):
                if case .delete(let prev) = merged.last {
                    merged[merged.count - 1] = .delete(prev + c)
                } else {
                    merged.append(.delete(c))
                }
            case .insert(let c):
                if case .insert(let prev) = merged.last {
                    merged[merged.count - 1] = .insert(prev + c)
                } else {
                    merged.append(.insert(c))
                }
            }
        }
        return merged
    }

    private func wordCount(_ text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            count += 1
        }
        return count
    }
}

// MARK: - Streaming Text View (NSViewRepresentable)

struct StreamingTextView: NSViewRepresentable {
    @Bindable var viewModel: ResultViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        let coordinator = context.coordinator

        if viewModel.showingDiff {
            textView.isEditable = false
            let diffAttr = viewModel.computeWordDiff()
            if textView.textStorage?.string != diffAttr.string || coordinator.lastWasDiff != true {
                textView.textStorage?.setAttributedString(diffAttr)
                coordinator.lastWasDiff = true
                coordinator.lastStreamedLength = 0
                coordinator.stopFadeTimer()
            }
        } else {
            if coordinator.lastWasDiff == true {
                // Switching back from diff — restore plain text and reset typing attributes
                let plainAttr = NSAttributedString(
                    string: viewModel.resultText,
                    attributes: Coordinator.defaultAttrs
                )
                textView.textStorage?.setAttributedString(plainAttr)
                textView.typingAttributes = Coordinator.defaultAttrs
                coordinator.lastWasDiff = false
                coordinator.lastStreamedLength = viewModel.resultText.count
            } else if viewModel.isProcessing {
                // Incremental append — only insert newly arrived characters
                let newText = viewModel.resultText
                let oldLength = coordinator.lastStreamedLength

                if newText.count > oldLength {
                    let startIndex = newText.index(newText.startIndex, offsetBy: oldLength)
                    let delta = String(newText[startIndex...])

                    // Append in brand accent color — fades to label color via the timer
                    let fadeAttrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 14),
                        .foregroundColor: Brand.accent.withAlphaComponent(0.5),
                    ]
                    let attrDelta = NSAttributedString(string: delta, attributes: fadeAttrs)
                    let insertLocation = textView.textStorage?.length ?? 0
                    textView.textStorage?.append(attrDelta)

                    // Record this chunk for fade-in animation
                    coordinator.fadingChunks.append(
                        FadingChunk(
                            range: NSRange(location: insertLocation, length: delta.utf16.count),
                            addedAt: CACurrentMediaTime()
                        )
                    )
                    coordinator.lastStreamedLength = newText.count
                    coordinator.startFadeTimerIfNeeded()

                    // Smooth scroll to bottom
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = 0.1
                        ctx.allowsImplicitAnimation = true
                        textView.scrollToEndOfDocument(nil)
                    }
                } else if newText.count < oldLength {
                    // Text was reset (e.g. retry) — full replace
                    coordinator.fadingChunks.removeAll()
                    coordinator.stopFadeTimer()
                    textView.textStorage?.setAttributedString(
                        NSAttributedString(string: newText, attributes: Coordinator.defaultAttrs)
                    )
                    coordinator.lastStreamedLength = newText.count
                }
            }

            // When streaming finishes, finalize all text to full color
            if viewModel.isComplete && !coordinator.fadingChunks.isEmpty {
                coordinator.fadingChunks.removeAll()
                coordinator.stopFadeTimer()
                if let storage = textView.textStorage {
                    let fullRange = NSRange(location: 0, length: storage.length)
                    storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
                }
            }

            textView.isEditable = viewModel.isComplete && !viewModel.showingDiff
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var viewModel: ResultViewModel
        weak var textView: NSTextView?
        var lastWasDiff: Bool?
        var lastStreamedLength: Int = 0
        var fadingChunks: [FadingChunk] = []
        var fadeTimer: Timer?
        private var appearanceObserver: NSObjectProtocol?

        nonisolated(unsafe) static let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.labelColor,
        ]

        /// Duration for each chunk to transition from accent to label color
        private static let fadeDuration: CFTimeInterval = 0.5

        init(viewModel: ResultViewModel) {
            self.viewModel = viewModel
            super.init()

            // Re-apply text colors when system appearance changes (light ↔ dark)
            appearanceObserver = DistributedNotificationCenter.default().addObserver(
                forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refreshTextColors()
                }
            }
        }

        deinit {
            fadeTimer?.invalidate()
            if let observer = appearanceObserver {
                DistributedNotificationCenter.default().removeObserver(observer)
            }
        }

        @MainActor
        private func refreshTextColors() {
            guard let storage = textView?.textStorage else { return }
            let fullRange = NSRange(location: 0, length: storage.length)
            guard fullRange.length > 0 else { return }

            if viewModel.showingDiff {
                // Recompute the entire diff with fresh appearance-resolved colors
                let freshDiff = viewModel.computeWordDiff()
                storage.setAttributedString(freshDiff)
            } else {
                // Only refresh settled text (not chunks still fading)
                let fadingRanges = Set(fadingChunks.map { $0.range.location })

                storage.enumerateAttribute(.foregroundColor, in: fullRange) { _, range, _ in
                    if !fadingRanges.contains(range.location) {
                        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
                    }
                }
            }

            textView?.typingAttributes = Self.defaultAttrs
        }

        func startFadeTimerIfNeeded() {
            guard fadeTimer == nil else { return }
            fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.tickFade()
                }
            }
        }

        func stopFadeTimer() {
            fadeTimer?.invalidate()
            fadeTimer = nil
        }

        private func tickFade() {
            guard let storage = textView?.textStorage else { return }
            let now = CACurrentMediaTime()
            var finishedIndices: [Int] = []

            let accentColor = Brand.accent

            for (i, chunk) in fadingChunks.enumerated() {
                // Ensure range is still valid
                guard chunk.range.location + chunk.range.length <= storage.length else {
                    finishedIndices.append(i)
                    continue
                }

                let elapsed = now - chunk.addedAt
                let progress = min(elapsed / Self.fadeDuration, 1.0)

                // Ease-out cubic for a natural "ink settling" feel
                let t = CGFloat(1.0 - pow(1.0 - progress, 3.0))

                // Blend: sage green (0.5 alpha) → label color (full)
                let color = accentColor.blendedWithLabelColor(fraction: t)
                storage.addAttribute(.foregroundColor, value: color, range: chunk.range)

                if progress >= 1.0 {
                    finishedIndices.append(i)
                }
            }

            // Remove completed chunks (iterate in reverse to keep indices valid)
            for i in finishedIndices.reversed() {
                fadingChunks.remove(at: i)
            }

            if fadingChunks.isEmpty {
                stopFadeTimer()
            }
        }

        @MainActor
        func textDidBeginEditing(_ notification: Notification) {
            viewModel.onAllowKeyStatus?(true)
            viewModel.onMakeKey?()
        }

        @MainActor
        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            viewModel.resultText = textView.string
            viewModel.updateStats()
        }
    }
}

/// A chunk of text that is fading in from transparent to fully visible.
struct FadingChunk {
    let range: NSRange
    let addedAt: CFTimeInterval
}

/// A single operation in a word-level diff.
enum DiffOp {
    case equal(String)
    case delete(String)
    case insert(String)
}

// MARK: - Result Content View

struct ResultContentView: View {
    @Bindable var viewModel: ResultViewModel
    let onAccept: (String) -> Void
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onCopyAndClose: () -> Void
    var onChangeStyle: ((WritingAction) -> Void)?
    var onSavePrompt: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: style menu + status
            HStack(alignment: .center) {
                styleMenu
                Spacer()
                if viewModel.isProcessing {
                    LottieView(animation: .named("processing-dots"))
                        .looping()
                        .frame(width: 40, height: 16)
                }
                StatusPill(status: viewModel.statusPillStatus)
            }
            .padding(.top, 16)
            .padding(.horizontal, Brand.Layout.margin)

            // Quote block — compact, fits content, capped height
            QuoteBlock(text: viewModel.previewText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: 56)
                .clipped()
                .padding(.top, 10)
                .padding(.horizontal, Brand.Layout.margin)

            // Tone detection badge
            if viewModel.isDetectingTone {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Detecting tone\u{2026}")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 6)
                .padding(.horizontal, Brand.Layout.margin)
            } else if let tone = viewModel.detectedTone {
                HStack(spacing: 4) {
                    Image(systemName: tone.iconName)
                        .font(.system(size: 11))
                    Text("Original tone: \(tone.displayName)")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .padding(.horizontal, Brand.Layout.margin)
            }

            // Custom prompt input
            if viewModel.isCustomPromptMode {
                HStack(spacing: 8) {
                    TextField("Type your instruction\u{2026}", text: $viewModel.customPromptText)
                        .textFieldStyle(.roundedBorder)
                        .font(Brand.Typography.body)
                        .onSubmit {
                            viewModel.submitCustomPrompt()
                        }

                    Button("Go") {
                        viewModel.submitCustomPrompt()
                    }
                    .buttonStyle(BrandButtonStyle())
                }
                .padding(.top, 10)
                .padding(.horizontal, Brand.Layout.margin)
            }

            // Diff toggle
            if viewModel.action.supportsDiff {
                HStack {
                    Spacer()
                    Picker("", selection: $viewModel.diffSegment) {
                        Text("Result").tag(0)
                        Text("Changes").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .tint(Brand.accentColor)
                    .onChange(of: viewModel.diffSegment) { _, newValue in
                        viewModel.showingDiff = newValue == 1
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, Brand.Layout.margin)
            }

            // Streaming text area — fills remaining vertical space
            StreamingTextView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Brand.Layout.smallCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.Layout.smallCornerRadius)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 0.5)
                )
                .background(
                    RoundedRectangle(cornerRadius: Brand.Layout.smallCornerRadius)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .padding(.top, 8)
                .padding(.horizontal, Brand.Layout.margin)

            // Stats row — always present to avoid layout jumps, content hidden when empty
            Text(viewModel.statsText.isEmpty ? " " : viewModel.statsText)
                .font(Brand.Typography.stats)
                .tracking(0.3)
                .foregroundStyle(.tertiary)
                .opacity(viewModel.statsText.isEmpty ? 0 : 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                .padding(.horizontal, Brand.Layout.margin + 2)

            // Hairline above buttons
            BrandDivider()
                .padding(.top, 8)
                .padding(.horizontal, Brand.Layout.margin)

            // Button bar
            HStack(spacing: 6) {
                if viewModel.isRetryVisible && !viewModel.isProcessing {
                    Button {
                        onRetry()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Rewrite")
                            Text("⌘R")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(BrandButtonStyle(prominent: false))
                }

                if !viewModel.isProcessing {
                    Button {
                        onCopyAndClose()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy")
                            Text("⌘C")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(BrandButtonStyle(prominent: false))
                }

                if viewModel.canSavePrompt && !viewModel.promptSaved {
                    Button {
                        onSavePrompt?()
                    } label: {
                        Label("Save Prompt", systemImage: "star")
                    }
                    .buttonStyle(BrandButtonStyle(prominent: false))
                } else if viewModel.promptSaved {
                    Button {} label: {
                        Label("Saved", systemImage: "star.fill")
                    }
                    .buttonStyle(BrandButtonStyle(prominent: false))
                    .disabled(true)
                }

                Spacer()

                Button {
                    onCancel()
                } label: {
                    HStack(spacing: 4) {
                        Text("Close")
                        Text("esc")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(BrandButtonStyle(prominent: false, tint: Brand.errorColor))

                Button {
                    let text = viewModel.resultText
                    guard !text.isEmpty else { return }
                    onAccept(text)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Replace")
                        Text("↩")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .buttonStyle(BrandButtonStyle(isEnabled: viewModel.isAcceptEnabled))
                .disabled(!viewModel.isAcceptEnabled)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.top, 8)
            .padding(.horizontal, Brand.Layout.margin)
            .padding(.bottom, 14)
        }
        .background(Brand.surfaceColor)
    }

    // MARK: - Style Dropdown Menu

    @State private var isStyleMenuHovered = false

    private var styleMenu: some View {
        VStack(alignment: .leading, spacing: 3) {
            Menu {
                ForEach(WritingStyle.groupedByCategory, id: \.category) { group in
                    Section(group.category.displayName) {
                        ForEach(group.styles, id: \.self) { style in
                            Button {
                                onChangeStyle?(.style(style))
                            } label: {
                                Label(style.displayName, systemImage: style.iconName)
                            }
                        }
                    }
                }

                Divider()

                Button {
                    onChangeStyle?(.custom(prompt: ""))
                } label: {
                    Label("Custom Prompt\u{2026}", systemImage: "text.bubble")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.action.iconName)
                        .font(.system(size: 14, weight: .semibold))
                    Text(viewModel.action.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .tracking(0.3)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(Brand.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Brand.accentColor.opacity(isStyleMenuHovered ? 0.18 : 0.10))
                        .overlay(
                            Capsule()
                                .strokeBorder(Brand.accentColor.opacity(isStyleMenuHovered ? 0.35 : 0.15), lineWidth: 0.5)
                        )
                )
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isStyleMenuHovered = hovering
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Text("Click to change style")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.leading, 4)
        }
    }

}

// MARK: - Result Window Controller

@MainActor
final class ResultWindowController {
    static let shared = ResultWindowController()

    private var window: ResultPanel?
    private var processingTask: Task<Void, Never>?
    private var toneDetectionTask: Task<Void, Never>?
    private var sourceApp: NSRunningApplication?
    private var originalText: String = ""
    private var currentAction: WritingAction = .style(.proofread)
    private var viewModel: ResultViewModel?
    private var localKeyMonitor: Any?

    private init() {}

    func show(
        originalText: String,
        action: WritingAction,
        sourceApp: NSRunningApplication? = nil,
        pasteboard: NSPasteboard? = nil
    ) {
        processingTask?.cancel()

        self.originalText = originalText
        self.currentAction = action
        self.sourceApp = sourceApp ?? NSWorkspace.shared.frontmostApplication

        let panel = ResultPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Writing Assistant"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 380, height: 320)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden

        let vm = ResultViewModel(action: action, originalText: originalText)
        self.viewModel = vm

        // Bridge panel behavior
        vm.onAllowKeyStatus = { [weak panel] allow in
            panel?.allowsKeyStatus = allow
        }
        vm.onMakeKey = { [weak panel] in
            panel?.makeKey()
        }

        let resultView = ResultContentView(
            viewModel: vm,
            onAccept: { [weak self] resultText in
                self?.accept(resultText: resultText)
            },
            onCancel: { [weak self] in
                self?.dismiss()
            },
            onRetry: { [weak self] in
                self?.retry()
            },
            onCopyAndClose: { [weak self] in
                self?.copyAndClose()
            },
            onChangeStyle: { [weak self] newAction in
                self?.changeStyle(to: newAction)
            },
            onSavePrompt: { [weak self] in
                self?.saveCurrentPrompt()
            }
        )

        let hostingView = NSHostingView(rootView: resultView)
        panel.contentView = hostingView

        // Dismiss previous window
        self.window?.close()
        self.window = panel

        // Show without stealing focus, then accept key status for shortcuts
        panel.allowsKeyStatus = true
        panel.orderFront(nil)
        panel.makeKey()

        // Set up keyboard shortcuts
        setupKeyboardShortcuts()

        // Launch tone detection in parallel (stays valid across style changes)
        toneDetectionTask?.cancel()
        vm.isDetectingTone = true
        toneDetectionTask = Task {
            let tone = await ToneDetectionService.shared.detectTone(for: originalText)
            guard !Task.isCancelled else { return }
            vm.detectedTone = tone
            vm.isDetectingTone = false
        }

        // Start AI processing (unless waiting for custom prompt input)
        if vm.isCustomPromptMode {
            panel.allowsKeyStatus = true
        } else {
            processingTask = Task {
                await self.startProcessing()
            }
        }
    }

    private func setupKeyboardShortcuts() {
        if let existing = localKeyMonitor {
            NSEvent.removeMonitor(existing)
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            if event.keyCode == 53 { // Escape
                self.dismiss()
                return nil
            }

            let cmd = event.modifierFlags.contains(.command)

            if cmd && event.keyCode == 0x08 { // Cmd+C
                self.copyAndClose()
                return nil
            }

            if cmd && event.keyCode == 0x0F { // Cmd+R
                self.retry()
                return nil
            }

            return event
        }
    }

    private func copyResult() {
        guard let vm = viewModel else { return }
        let text = vm.resultText
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func copyAndClose() {
        copyResult()
        dismiss()
    }

    private func startProcessing() async {
        guard let vm = viewModel else { return }

        vm.isProcessing = true
        vm.isComplete = false
        vm.resultText = ""
        vm.statusPillStatus = .processing
        vm.statsText = ""
        vm.showingDiff = false
        vm.diffSegment = 0
        window?.allowsKeyStatus = false

        guard WritingService.shared.isAvailable else {
            vm.isProcessing = false
            vm.statusPillStatus = .error(WritingService.shared.unavailableReason)
            return
        }

        do {
            let stream = WritingService.shared.streamProcess(text: originalText, action: vm.action)
            let responseStream = try await stream.start()

            for try await snapshot in responseStream {
                vm.resultText = snapshot.content
            }

            // Streaming complete
            vm.isProcessing = false
            vm.isComplete = true
            vm.statusPillStatus = .done
            vm.updateStats()
        } catch {
            vm.isProcessing = false
            if !Task.isCancelled {
                vm.statusPillStatus = .error(error.localizedDescription)
            }
        }
    }

    private func retry() {
        processingTask?.cancel()
        window?.allowsKeyStatus = false
        processingTask = Task {
            await startProcessing()
        }
    }

    private func saveCurrentPrompt() {
        guard let vm = viewModel,
              case .custom(let prompt) = vm.action, !prompt.isEmpty else { return }

        // Use a truncated version of the prompt as the name
        let name = String(prompt.prefix(40)) + (prompt.count > 40 ? "\u{2026}" : "")
        SavedCustomPrompts.save(name: name, prompt: prompt)
        vm.promptSaved = true
    }

    private func changeStyle(to newAction: WritingAction) {
        guard let vm = viewModel else { return }

        if case .style(let style) = newAction {
            RecentStyles.record(style)
        }

        vm.action = newAction
        // Reset diff and prompt state immediately so the view doesn't flash stale formatting
        vm.showingDiff = false
        vm.diffSegment = 0
        vm.promptSaved = false

        if case .custom(let prompt) = newAction, prompt.isEmpty {
            // Enter custom prompt mode
            vm.isCustomPromptMode = true
            vm.customPromptText = ""
            processingTask?.cancel()
            vm.isProcessing = false
            vm.resultText = ""
            vm.statusPillStatus = .processing
            vm.statsText = ""
            window?.allowsKeyStatus = true
            window?.makeKey()
        } else {
            vm.isCustomPromptMode = false
            retry()
        }
    }

    private func accept(resultText: String) {
        // Always put result on clipboard
        let general = NSPasteboard.general
        general.clearContents()
        general.setString(resultText, forType: .string)

        UsageTracker.shared.recordUsage()
        HistoryStore.shared.record(
            action: viewModel?.action ?? currentAction,
            originalText: originalText,
            resultText: resultText
        )

        let app = sourceApp
        let original = originalText

        guard AXIsProcessTrusted(), let app else {
            dismiss()
            showCopiedNotification()
            return
        }

        let pid = app.processIdentifier

        dismiss()
        app.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if self.replaceViaAccessibility(pid: pid, original: original, replacement: resultText) {
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                self.replaceViaPaste()
            }
        }
    }

    private func dismiss() {
        processingTask?.cancel()
        toneDetectionTask?.cancel()
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        localKeyMonitor = nil
        window?.close()
        window = nil
        viewModel = nil
    }

    /// Show a brief HUD telling the user the result is on the clipboard.
    private func showCopiedNotification() {
        let panel = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 48),
            styleMask: [.titled, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isOpaque = false
        panel.backgroundColor = .clear

        let hudView = Text("Result copied \u{2014} \u{2318}V to paste")
            .font(.system(size: 13))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(width: 260, height: 48)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Brand.Layout.cornerRadius))

        panel.contentView = NSHostingView(rootView: hudView)
        panel.center()
        panel.orderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            panel.close()
        }
    }

    // MARK: - Text Replacement

    private nonisolated func replaceViaAccessibility(pid: pid_t, original: String, replacement: String) -> Bool {
        guard let focused = focusedAXElement(pid: pid) else { return false }

        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXValueAttribute as CFString,
            &valueRef
        ) == .success, let fullText = valueRef as? String else { return false }

        guard let range = fullText.range(of: original) else { return false }
        let nsRange = NSRange(range, in: fullText)

        var cfRange = CFRange(location: nsRange.location, length: nsRange.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else { return false }

        guard AXUIElementSetAttributeValue(
            focused,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        ) == .success else { return false }

        guard AXUIElementSetAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            replacement as CFTypeRef
        ) == .success else { return false }

        var verifyRef: AnyObject?
        if AXUIElementCopyAttributeValue(
            focused,
            kAXValueAttribute as CFString,
            &verifyRef
        ) == .success, let newText = verifyRef as? String {
            if newText == fullText {
                return false
            }
        }

        return true
    }

    private nonisolated func focusedAXElement(pid: pid_t) -> AXUIElement? {
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

    private nonisolated func replaceViaPaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        postKeyCombo(source: source, keyCode: 0x09, flags: .maskCommand)
    }

    private nonisolated func postKeyCombo(source: CGEventSource?, keyCode: CGKeyCode, flags: CGEventFlags) {
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
