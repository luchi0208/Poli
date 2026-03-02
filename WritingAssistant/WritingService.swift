import Foundation
import FoundationModels

@MainActor
final class WritingService {
    static let shared = WritingService()

    private let model = SystemLanguageModel.default

    private init() {}

    var isAvailable: Bool {
        if case .available = model.availability {
            return true
        }
        return false
    }

    var unavailableReason: String {
        switch model.availability {
        case .available:
            return ""
        case .unavailable(.deviceNotEligible):
            return "This device does not support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Please enable Apple Intelligence in System Settings."
        case .unavailable(.modelNotReady):
            return "The language model is still downloading. Please try again later."
        case .unavailable(_):
            return "The language model is currently unavailable."
        @unknown default:
            return "The language model is currently unavailable."
        }
    }

    /// Non-streaming processing (kept for Services which don't need streaming)
    func process(text: String, action: WritingAction) async throws -> String {
        let session = LanguageModelSession(model: model) {
            Instructions(action.systemPrompt)
        }
        let response = try await session.respond(to: text)
        return response.content
    }

    /// Streaming processing — yields accumulated text snapshots
    func streamProcess(text: String, action: WritingAction) -> StreamingSession {
        StreamingSession(model: model, text: text, action: action)
    }
}

// MARK: - Streaming Session

/// Wraps Foundation Models streaming so callers can iterate with `for try await`
@MainActor
final class StreamingSession {
    private let model: SystemLanguageModel
    private let text: String
    private let action: WritingAction

    init(model: SystemLanguageModel, text: String, action: WritingAction) {
        self.model = model
        self.text = text
        self.action = action
    }

    /// Returns an AsyncThrowingStream of accumulated text snapshots
    func start() async throws -> LanguageModelSession.ResponseStream<String> {
        let session = LanguageModelSession(model: model) {
            Instructions(action.systemPrompt)
        }
        return session.streamResponse(to: text)
    }
}
