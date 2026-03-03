import Foundation

// MARK: - Style Category

enum StyleCategory: String, CaseIterable, Sendable {
    case fix
    case rewrite
    case transform
    case translate

    var displayName: String {
        switch self {
        case .fix: return "Fix"
        case .rewrite: return "Rewrite"
        case .transform: return "Transform"
        case .translate: return "Translate"
        }
    }
}

// MARK: - Writing Style

enum WritingStyle: String, CaseIterable, Sendable {
    case proofread
    case fixGrammar
    case professional
    case casual
    case friendly
    case formal
    case creative
    case concise
    case summarize
    case expand
    case keyPoints
    case translateSpanish
    case translateFrench
    case translateGerman
    case translateChineseSimplified
    case translateJapanese
    case translateKorean

    var category: StyleCategory {
        switch self {
        case .proofread, .fixGrammar:
            return .fix
        case .professional, .casual, .friendly, .formal, .creative, .concise:
            return .rewrite
        case .summarize, .expand, .keyPoints:
            return .transform
        case .translateSpanish, .translateFrench, .translateGerman,
             .translateChineseSimplified, .translateJapanese, .translateKorean:
            return .translate
        }
    }

    var displayName: String {
        switch self {
        case .proofread: return "Fix Spelling & Grammar"
        case .fixGrammar: return "Fix Grammar Only"
        case .professional: return "Professional"
        case .casual: return "Casual"
        case .friendly: return "Friendly"
        case .formal: return "Formal"
        case .creative: return "Creative"
        case .concise: return "Concise"
        case .summarize: return "Summarize"
        case .expand: return "Expand"
        case .keyPoints: return "Key Points"
        case .translateSpanish: return "Spanish"
        case .translateFrench: return "French"
        case .translateGerman: return "German"
        case .translateChineseSimplified: return "Chinese (Simplified)"
        case .translateJapanese: return "Japanese"
        case .translateKorean: return "Korean"
        }
    }

    var iconName: String {
        switch self {
        case .proofread: return "checkmark.circle"
        case .fixGrammar: return "textformat.abc"
        case .professional: return "briefcase"
        case .casual: return "face.smiling"
        case .friendly: return "hand.wave"
        case .formal: return "building.columns"
        case .creative: return "paintbrush"
        case .concise: return "arrow.down.right.and.arrow.up.left"
        case .summarize: return "doc.plaintext"
        case .expand: return "arrow.up.left.and.arrow.down.right"
        case .keyPoints: return "list.bullet"
        case .translateSpanish, .translateFrench, .translateGerman,
             .translateChineseSimplified, .translateJapanese, .translateKorean:
            return "globe"
        }
    }

    var systemPrompt: String {
        switch PromptVersionManager.active {
        case .v1: return systemPromptV1
        case .v2: return systemPromptV2
        }
    }

    private var systemPromptV1: String {
        switch self {
        case .proofread:
            return """
            You are a proofreading assistant. Fix spelling, grammar, and punctuation errors in the text. \
            Keep the original tone, style, and meaning. Only correct mistakes — do not rewrite or rephrase. \
            Return only the corrected text with no explanation.
            """
        case .fixGrammar:
            return """
            You are a grammar assistant. Fix only grammatical errors in the text. \
            Do not change spelling, punctuation style, tone, or word choice — only fix grammar. \
            Return only the corrected text with no explanation.
            """
        case .professional:
            return """
            You are a professional writing assistant. Rewrite the text in a formal, professional tone \
            suitable for business communication. Maintain the original meaning. \
            Return only the rewritten text with no explanation.
            """
        case .casual:
            return """
            You are a writing assistant. Rewrite the text in a friendly, casual, conversational tone. \
            Keep the original meaning but make it sound natural and approachable. \
            Return only the rewritten text with no explanation.
            """
        case .friendly:
            return """
            You are a writing assistant. Rewrite the text in a warm, friendly, and encouraging tone. \
            Make it feel personable and positive while preserving the original meaning. \
            Return only the rewritten text with no explanation.
            """
        case .formal:
            return """
            You are a writing assistant. Rewrite the text in a highly formal, polished tone \
            suitable for official documents, academic writing, or executive communication. \
            Use sophisticated vocabulary and proper structure. Maintain the original meaning. \
            Return only the rewritten text with no explanation.
            """
        case .creative:
            return """
            You are a creative writing assistant. Rewrite the text with vivid, engaging, and expressive language. \
            Add flair and personality while preserving the core meaning. \
            Return only the rewritten text with no explanation.
            """
        case .concise:
            return """
            You are a writing assistant. Rewrite the text to be more concise and to the point. \
            Remove unnecessary words, redundancy, and filler. Preserve the core meaning. \
            Return only the rewritten text with no explanation.
            """
        case .summarize:
            return """
            You are a summarization assistant. Provide a brief, clear summary of the text. \
            Capture the key points and main ideas in fewer words. \
            Return only the summary with no explanation.
            """
        case .expand:
            return """
            You are a writing assistant. Expand the text with more detail, examples, and explanation. \
            Elaborate on the ideas while maintaining the original tone and intent. \
            Return only the expanded text with no explanation.
            """
        case .keyPoints:
            return """
            You are a writing assistant. Extract the key points from the text and present them \
            as a clear, concise bulleted list. Each point should be one sentence or less. \
            Return only the bullet points with no explanation.
            """
        case .translateSpanish:
            return """
            You are a translation assistant. Translate the text into Spanish. \
            Preserve the tone, meaning, and formatting of the original. \
            Return only the translated text with no explanation.
            """
        case .translateFrench:
            return """
            You are a translation assistant. Translate the text into French. \
            Preserve the tone, meaning, and formatting of the original. \
            Return only the translated text with no explanation.
            """
        case .translateGerman:
            return """
            You are a translation assistant. Translate the text into German. \
            Preserve the tone, meaning, and formatting of the original. \
            Return only the translated text with no explanation.
            """
        case .translateChineseSimplified:
            return """
            You are a translation assistant. Translate the text into Simplified Chinese (简体中文). \
            Preserve the tone, meaning, and formatting of the original. \
            Return only the translated text with no explanation.
            """
        case .translateJapanese:
            return """
            You are a translation assistant. Translate the text into Japanese. \
            Preserve the tone, meaning, and formatting of the original. \
            Return only the translated text with no explanation.
            """
        case .translateKorean:
            return """
            You are a translation assistant. Translate the text into Korean. \
            Preserve the tone, meaning, and formatting of the original. \
            Return only the translated text with no explanation.
            """
        }
    }

    private var systemPromptV2: String {
        switch self {
        case .proofread:
            return """
            Fix spelling, grammar, and punctuation errors. \
            DO NOT rewrite, rephrase, or change tone. Only correct mistakes. \
            Output the corrected text only. Same length as input.
            """
        case .fixGrammar:
            return """
            Fix grammar errors only. \
            DO NOT change spelling, punctuation style, tone, or word choice. \
            Output the corrected text only. Same length as input.
            """
        case .professional:
            return """
            Rewrite in a formal, professional tone for business communication. \
            Keep the same meaning. Match the input length. \
            Output the rewritten text only.
            """
        case .casual:
            return """
            Rewrite in a casual, conversational tone. \
            Keep the same meaning. Sound natural and approachable. \
            Output the rewritten text only. Match the input length.
            """
        case .friendly:
            return """
            Rewrite in a warm, friendly, encouraging tone. \
            Keep the same meaning. Be personable and positive. \
            Output the rewritten text only. Match the input length.
            """
        case .formal:
            return """
            Rewrite in a highly formal, polished tone for official or academic use. \
            Use sophisticated vocabulary. Keep the same meaning. \
            Output the rewritten text only. Match the input length.
            """
        case .creative:
            return """
            Rewrite with vivid, engaging, expressive language. \
            Add flair while keeping the core meaning. \
            Output the rewritten text only. Match the input length.
            """
        case .concise:
            return """
            Rewrite to be shorter and more direct. \
            Cut filler, redundancy, and unnecessary words. Keep the core meaning. \
            Output the rewritten text only.
            """
        case .summarize:
            return """
            Summarize the text in 1-3 sentences. \
            Capture only the key points and main ideas. \
            Output the summary only.
            """
        case .expand:
            return """
            Expand the text with more detail and examples. \
            Keep the original tone. Roughly double the length. \
            Output the expanded text only.
            """
        case .keyPoints:
            return """
            Extract key points as a bulleted list. \
            Each bullet: one sentence max. DO NOT add commentary. \
            Output the bullets only.
            """
        case .translateSpanish:
            return """
            Translate into Spanish. Preserve tone, meaning, and formatting. \
            DO NOT add notes or explanations. Output the translation only.
            """
        case .translateFrench:
            return """
            Translate into French. Preserve tone, meaning, and formatting. \
            DO NOT add notes or explanations. Output the translation only.
            """
        case .translateGerman:
            return """
            Translate into German. Preserve tone, meaning, and formatting. \
            DO NOT add notes or explanations. Output the translation only.
            """
        case .translateChineseSimplified:
            return """
            Translate into Simplified Chinese (简体中文). Preserve tone, meaning, and formatting. \
            DO NOT add notes or explanations. Output the translation only.
            """
        case .translateJapanese:
            return """
            Translate into Japanese. Preserve tone, meaning, and formatting. \
            DO NOT add notes or explanations. Output the translation only.
            """
        case .translateKorean:
            return """
            Translate into Korean. Preserve tone, meaning, and formatting. \
            DO NOT add notes or explanations. Output the translation only.
            """
        }
    }

    /// Whether a diff view makes sense for this style.
    /// Only fix styles (spelling, grammar) preserve text structure enough for a useful word diff.
    var supportsDiff: Bool {
        switch category {
        case .fix: return true
        case .rewrite, .transform, .translate: return false
        }
    }

    /// Styles grouped by category, in display order
    static var groupedByCategory: [(category: StyleCategory, styles: [WritingStyle])] {
        StyleCategory.allCases.map { category in
            (category: category, styles: allCases.filter { $0.category == category })
        }
    }
}

// MARK: - Writing Action

/// Wraps both built-in styles and custom prompts so downstream code has a single type.
enum WritingAction: Sendable, Equatable {
    case style(WritingStyle)
    case custom(prompt: String)
    case quickTranslate(languageName: String)

    var displayName: String {
        switch self {
        case .style(let style): return style.displayName
        case .custom: return "Custom Prompt"
        case .quickTranslate(let name): return "Translate to \(name)"
        }
    }

    var iconName: String {
        switch self {
        case .style(let style): return style.iconName
        case .custom: return "text.bubble"
        case .quickTranslate: return "globe"
        }
    }

    var systemPrompt: String {
        switch self {
        case .style(let style):
            return style.systemPrompt
        case .custom(let prompt):
            switch PromptVersionManager.active {
            case .v1:
                return """
                You are a helpful writing assistant. Follow the user's instruction to modify or transform the text. \
                The user's instruction is: \(prompt) \
                Return only the result with no explanation.
                """
            case .v2:
                return """
                Follow this instruction on the text: \(prompt) \
                DO NOT add commentary. Output the result only.
                """
            }
        case .quickTranslate(let name):
            switch PromptVersionManager.active {
            case .v1:
                return """
                You are a translation assistant. Translate the text into \(name). \
                Preserve the tone, meaning, and formatting of the original. \
                Return only the translated text with no explanation.
                """
            case .v2:
                return """
                Translate into \(name). Preserve tone, meaning, and formatting. \
                DO NOT add notes or explanations. Output the translation only.
                """
            }
        }
    }

    var supportsDiff: Bool {
        switch self {
        case .style(let style): return style.supportsDiff
        case .custom, .quickTranslate: return false
        }
    }
}

// MARK: - Prompt Version

enum PromptVersion: String, CaseIterable, Sendable {
    case v1
    case v2

    var displayName: String {
        switch self {
        case .v1: return "Standard"
        case .v2: return "Apple-Optimized"
        }
    }

    var description: String {
        switch self {
        case .v1: return "Current prompts — detailed, conversational style"
        case .v2: return "Shorter, imperative prompts tuned for Foundation Models"
        }
    }
}

enum PromptVersionManager: Sendable {
    nonisolated(unsafe) private static let key = "activePromptVersion"

    static var active: PromptVersion {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let version = PromptVersion(rawValue: raw) else {
                return .v1
            }
            return version
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}

// MARK: - Preferred Language Manager

@MainActor
enum PreferredLanguageManager {
    private static let key = "preferredTranslateLanguageCode"

    /// All 23 languages supported by Foundation Models
    static let supportedLanguages: [(code: String, name: String)] = [
        ("ar", "Arabic"),
        ("de", "German"),
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("hi", "Hindi"),
        ("id", "Indonesian"),
        ("it", "Italian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("nl", "Dutch"),
        ("pl", "Polish"),
        ("pt", "Portuguese"),
        ("ro", "Romanian"),
        ("ru", "Russian"),
        ("sv", "Swedish"),
        ("th", "Thai"),
        ("tl", "Tagalog"),
        ("tr", "Turkish"),
        ("uk", "Ukrainian"),
        ("vi", "Vietnamese"),
        ("zh-Hans", "Chinese (Simplified)"),
        ("zh-Hant", "Chinese (Traditional)"),
    ]

    static var languageCode: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static var displayName: String? {
        guard let code = languageCode else { return nil }
        return supportedLanguages.first(where: { $0.code == code })?.name
            ?? Locale.current.localizedString(forLanguageCode: code)
    }
}

// MARK: - Saved Custom Prompts

struct SavedCustomPrompt: Codable, Equatable, Sendable {
    let name: String
    let prompt: String
}

@MainActor
enum SavedCustomPrompts {
    private static let key = "savedCustomPrompts"
    private static let maxCount = 10

    static var prompts: [SavedCustomPrompt] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SavedCustomPrompt].self, from: data) else {
            return []
        }
        return decoded
    }

    static func save(name: String, prompt: String) {
        var current = prompts
        current.removeAll { $0.prompt == prompt }
        current.insert(SavedCustomPrompt(name: name, prompt: prompt), at: 0)
        if current.count > maxCount { current = Array(current.prefix(maxCount)) }
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func delete(_ prompt: SavedCustomPrompt) {
        var current = prompts
        current.removeAll { $0 == prompt }
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
