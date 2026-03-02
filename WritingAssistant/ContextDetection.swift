import Foundation

// MARK: - Detected Context

enum DetectedContext: String, CaseIterable, Sendable {
    case email
    case chat
    case codeComment
    case academic
    case socialMedia
    case general

    var displayName: String {
        switch self {
        case .email: return "Email"
        case .chat: return "Chat"
        case .codeComment: return "Code"
        case .academic: return "Academic"
        case .socialMedia: return "Social Media"
        case .general: return "General"
        }
    }

    var iconName: String {
        switch self {
        case .email: return "envelope"
        case .chat: return "bubble.left.and.bubble.right"
        case .codeComment: return "chevron.left.forwardslash.chevron.right"
        case .academic: return "graduationcap"
        case .socialMedia: return "at"
        case .general: return "doc.text"
        }
    }

    var suggestedStyles: [WritingStyle] {
        switch self {
        case .email: return [.professional, .formal, .concise]
        case .chat: return [.casual, .friendly, .concise]
        case .codeComment: return [.concise, .professional]
        case .academic: return [.formal, .professional, .concise]
        case .socialMedia: return [.casual, .creative, .concise]
        case .general: return []
        }
    }
}

// MARK: - Preference

@MainActor
enum ContextSuggestionsPreference {
    private static let key = "contextSuggestionsEnabled"

    static var isEnabled: Bool {
        get {
            // Default to true if never set
            if UserDefaults.standard.object(forKey: key) == nil { return true }
            return UserDefaults.standard.bool(forKey: key)
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// MARK: - Context Detection Service

enum ContextDetectionService {

    private static let minimumThreshold = 3

    // MARK: - Detection

    static func detectContext(for text: String) -> DetectedContext {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .general }

        var scores: [DetectedContext: Int] = [:]

        scores[.email] = scoreEmail(trimmed)
        scores[.chat] = scoreChat(trimmed)
        scores[.codeComment] = scoreCode(trimmed)
        scores[.academic] = scoreAcademic(trimmed)
        scores[.socialMedia] = scoreSocial(trimmed)

        // Filter to only those above threshold
        let qualifying = scores.filter { $0.value >= minimumThreshold }

        guard let best = qualifying.max(by: { $0.value < $1.value }) else {
            return .general
        }

        return best.key
    }

    // MARK: - Regex Helper

    private static func matches(_ text: String, pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Email Scoring

    private static func scoreEmail(_ text: String) -> Int {
        var score = 0

        let keywords: [(String, Int)] = [
            ("(?i)\\bdear\\b", 3),
            ("(?i)\\bhi\\s+[A-Z]", 2),
            ("(?i)\\bhello\\s+[A-Z]", 2),
            ("(?i)\\bbest regards\\b", 3),
            ("(?i)\\bsincerely\\b", 3),
            ("(?i)\\bkind regards\\b", 3),
            ("(?i)\\bwarm regards\\b", 3),
            ("(?i)\\bthank you\\b", 1),
            ("(?i)\\bthanks,\\b", 2),
            ("(?i)\\bsubject:", 3),
            ("(?i)\\bplease find attached\\b", 3),
            ("(?i)\\bI hope this (email|message) finds you\\b", 3),
            ("(?i)\\blooking forward to hearing\\b", 2),
            ("(?i)\\bplease let me know\\b", 1),
            ("(?i)\\bcc:", 2),
            ("(?i)\\bbcc:", 2),
            ("(?i)\\bregards,?\\s*$", 2),
            ("(?i)\\bcheers,?\\s*$", 2),
        ]

        for (pattern, weight) in keywords {
            if matches(text, pattern: pattern) { score += weight }
        }

        // Greeting + closing pattern
        let hasGreeting = matches(text, pattern: "(?i)^(dear|hi|hello|hey)\\b")
        let hasClosing = matches(text, pattern: "(?i)(regards|sincerely|cheers|thanks|best),?\\s*$")
        if hasGreeting && hasClosing { score += 4 }

        return score
    }

    // MARK: - Chat Scoring

    private static func scoreChat(_ text: String) -> Int {
        var score = 0

        let keywords: [(String, Int)] = [
            ("(?i)\\blol\\b", 2),
            ("(?i)\\bhaha\\b", 2),
            ("(?i)\\bhehe\\b", 2),
            ("(?i)\\bbrb\\b", 2),
            ("(?i)\\btbh\\b", 2),
            ("(?i)\\bidk\\b", 2),
            ("(?i)\\bomg\\b", 2),
            ("(?i)\\bbtw\\b", 2),
            ("(?i)\\bimo\\b", 2),
            ("(?i)\\bimho\\b", 2),
            ("(?i)\\bnvm\\b", 2),
            ("(?i)\\bwyd\\b", 2),
            ("(?i)\\bwbu\\b", 2),
            ("(?i)\\bty\\b", 1),
            ("(?i)\\bthx\\b", 1),
            ("(?i)\\bu\\b", 1),
            ("(?i)\\bur\\b", 1),
        ]

        for (pattern, weight) in keywords {
            if matches(text, pattern: pattern) { score += weight }
        }

        // Short text signals
        if text.count < 100 { score += 1 }
        if text.count < 40 { score += 1 }

        // Contains emoji
        if text.unicodeScalars.contains(where: { $0.properties.isEmoji && $0.value > 0x238C }) {
            score += 2
        }

        // No ending punctuation
        if let last = text.last, !".!?".contains(last) {
            score += 1
        }

        return score
    }

    // MARK: - Code Scoring

    private static func scoreCode(_ text: String) -> Int {
        var score = 0

        let keywords: [(String, Int)] = [
            ("^\\s*//", 3),
            ("^\\s*/\\*", 3),
            ("\\*/\\s*$", 2),
            ("(?i)\\bTODO\\b", 2),
            ("(?i)\\bFIXME\\b", 2),
            ("(?i)\\bHACK\\b", 2),
            ("(?i)\\bNOTE\\b", 1),
            ("(?i)\\bWARNING\\b", 1),
            ("(?i)\\bDEPRECATED\\b", 2),
            ("(?i)\\bparam\\b", 2),
            ("(?i)\\breturns?\\b.*\\b(true|false|nil|null|void|int|string)\\b", 2),
        ]

        for (pattern, weight) in keywords {
            if matches(text, pattern: pattern) { score += weight }
        }

        // camelCase identifiers
        if matches(text, pattern: "[a-z][a-zA-Z]*[A-Z][a-zA-Z]*") { score += 2 }
        // Function-like patterns: word(
        if matches(text, pattern: "\\w+\\(") { score += 1 }
        // Common code symbols
        if matches(text, pattern: "->|=>|::|\\{\\}|\\[\\]|!=|==|\\|\\||&&") { score += 2 }

        return score
    }

    // MARK: - Academic Scoring

    private static func scoreAcademic(_ text: String) -> Int {
        var score = 0

        let keywords: [(String, Int)] = [
            ("(?i)\\bhypothesis\\b", 3),
            ("(?i)\\bmethodology\\b", 3),
            ("(?i)\\bfurthermore\\b", 2),
            ("(?i)\\bmoreover\\b", 2),
            ("(?i)\\bnevertheless\\b", 2),
            ("(?i)\\bhowever,\\b", 1),
            ("(?i)\\bin conclusion\\b", 2),
            ("(?i)\\babstract\\b", 2),
            ("(?i)\\bliterature review\\b", 3),
            ("(?i)\\bfindings\\b", 2),
            ("(?i)\\bsignificant(ly)?\\b", 1),
            ("(?i)\\bempirical\\b", 3),
            ("(?i)\\btheoretical\\b", 2),
            ("(?i)\\banalysis\\b", 1),
            ("(?i)\\bresearch\\b", 1),
            ("(?i)\\bcorrelation\\b", 2),
            ("(?i)\\bconsequently\\b", 2),
            ("(?i)\\bthesis\\b", 2),
            ("(?i)\\bet al\\.", 3),
        ]

        for (pattern, weight) in keywords {
            if matches(text, pattern: pattern) { score += weight }
        }

        // Citation patterns: (Author, 2023) or [1]
        if matches(text, pattern: "\\([A-Z][a-z]+,?\\s*\\d{4}\\)") { score += 3 }
        if matches(text, pattern: "\\[\\d+\\]") { score += 2 }
        // Passive voice
        if matches(text, pattern: "(?i)\\b(was|were|been|being)\\s+(observed|analyzed|found|shown|demonstrated|conducted|performed)") { score += 2 }

        return score
    }

    // MARK: - Social Media Scoring

    private static func scoreSocial(_ text: String) -> Int {
        var score = 0

        let keywords: [(String, Int)] = [
            ("#\\w+", 2),
            ("@\\w+", 2),
            ("(?i)\\bRT\\b", 2),
            ("(?i)\\bDM\\b", 1),
            ("(?i)\\bthread\\b", 1),
            ("(?i)\\bfollow\\b", 1),
            ("(?i)\\blike and share\\b", 3),
            ("(?i)\\blink in bio\\b", 3),
            ("(?i)\\bswipe up\\b", 2),
        ]

        for (pattern, weight) in keywords {
            if matches(text, pattern: pattern) { score += weight }
        }

        // Short + hashtags
        if text.count < 280 && matches(text, pattern: "#\\w+") {
            score += 2
        }

        // Emoji-heavy (3+)
        let emojiCount = text.unicodeScalars.filter({ $0.properties.isEmoji && $0.value > 0x238C }).count
        if emojiCount >= 3 { score += 2 }

        return score
    }
}
