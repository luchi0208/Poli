import Foundation
import FoundationModels

// MARK: - Detected Tone

@Generable
enum DetectedTone: String, CaseIterable, Sendable {
    case formal
    case casual
    case friendly
    case professional
    case academic
    case creative
    case neutral
    case urgent
    case persuasive

    var displayName: String {
        switch self {
        case .formal: "Formal"
        case .casual: "Casual"
        case .friendly: "Friendly"
        case .professional: "Professional"
        case .academic: "Academic"
        case .creative: "Creative"
        case .neutral: "Neutral"
        case .urgent: "Urgent"
        case .persuasive: "Persuasive"
        }
    }

    var iconName: String {
        switch self {
        case .formal: "building.columns"
        case .casual: "face.smiling"
        case .friendly: "hand.wave"
        case .professional: "briefcase"
        case .academic: "graduationcap"
        case .creative: "paintbrush"
        case .neutral: "minus.circle"
        case .urgent: "exclamationmark.triangle"
        case .persuasive: "megaphone"
        }
    }
}

// MARK: - Tone Detection Service

@MainActor
final class ToneDetectionService {
    static let shared = ToneDetectionService()

    private let model = SystemLanguageModel.default
    private var cache: [String: DetectedTone] = [:]
    private static let maxCacheSize = 100
    private static let inputLimit = 500

    private init() {}

    func detectTone(for text: String) async -> DetectedTone? {
        let prefix = String(text.prefix(Self.inputLimit))
        let cacheKey = String(prefix.prefix(300))

        if let cached = cache[cacheKey] {
            return cached
        }

        guard case .available = model.availability else { return nil }

        do {
            let session = LanguageModelSession(model: model) {
                Instructions("""
                    Classify the tone of the given text into exactly one of these categories: \
                    formal, casual, friendly, professional, academic, creative, neutral, urgent, persuasive. \
                    Return only the tone classification as a single word, nothing else.
                    """)
            }

            let response = try await session.respond(to: prefix, generating: DetectedTone.self)
            let tone = response.content

            // Evict oldest entries if cache is full
            if cache.count >= Self.maxCacheSize {
                let keysToRemove = Array(cache.keys.prefix(cache.count - Self.maxCacheSize + 1))
                for key in keysToRemove {
                    cache.removeValue(forKey: key)
                }
            }

            cache[cacheKey] = tone
            return tone
        } catch {
            print("[ToneDetection] Failed: \(error.localizedDescription)")
            return nil
        }
    }
}
