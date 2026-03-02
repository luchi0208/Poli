import Foundation

// MARK: - History Entry

struct HistoryEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let actionDisplayName: String
    let actionIconName: String
    let originalPreview: String
    let resultPreview: String
    let originalWordCount: Int
    let resultWordCount: Int

    init(
        actionDisplayName: String,
        actionIconName: String,
        originalText: String,
        resultText: String
    ) {
        self.id = UUID()
        self.date = Date()
        self.actionDisplayName = actionDisplayName
        self.actionIconName = actionIconName
        self.originalPreview = String(originalText.prefix(500))
        self.resultPreview = String(resultText.prefix(500))
        self.originalWordCount = Self.wordCount(originalText)
        self.resultWordCount = Self.wordCount(resultText)
    }

    var wordCountDelta: Int { resultWordCount - originalWordCount }

    var wordCountDeltaString: String {
        if wordCountDelta > 0 { return "+\(wordCountDelta)" }
        if wordCountDelta < 0 { return "\(wordCountDelta)" }
        return "\u{b1}0"
    }

    private static func wordCount(_ text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            count += 1
        }
        return count
    }
}

// MARK: - History Store

@MainActor
final class HistoryStore {
    static let shared = HistoryStore()

    private static let maxEntries = 50
    private let fileURL: URL

    private(set) var entries: [HistoryEntry] = []

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("WritingAssistant", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent("history.json")
        load()
    }

    func record(action: WritingAction, originalText: String, resultText: String) {
        let entry = HistoryEntry(
            actionDisplayName: action.displayName,
            actionIconName: action.iconName,
            originalText: originalText,
            resultText: resultText
        )
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        save()
    }

    func delete(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
