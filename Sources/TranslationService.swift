import Foundation

// MARK: - Data Types

struct TranslatedTextResponse {
    let translatedText: String
    let detectedSourceLanguage: String
}

struct TranslationResult {
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let provider: String
    let isError: Bool
}

// MARK: - Backend Protocol

protocol TranslationBackend: Sendable {
    var identifier: String { get }
    func translate(text: String, sourceLanguage: String?, targetLanguage: String, model: String) async throws -> TranslatedTextResponse
}

// MARK: - Service

@MainActor
final class TranslationService {
    static let shared = TranslationService()

    private var backends: [TranslationProvider: TranslationBackend] = [:]

    private init() {
        backends[.claude] = ClaudeBackend()
        backends[.deepseek] = DeepSeekBackend()
    }

    func translate(
        text: String,
        targetLanguage: String,
        provider: TranslationProvider
    ) async -> TranslationResult {
        guard let backend = backends[provider] else {
            return TranslationResult(
                originalText: text,
                translatedText: "Error: Unknown provider",
                sourceLanguage: "unknown",
                targetLanguage: targetLanguage,
                provider: provider.rawValue,
                isError: true
            )
        }

        let sourceLanguage = SettingsStore.shared.autoDetectSource
            ? detectSourceLanguage(text)
            : nil

        do {
            let model = SettingsStore.shared.selectedModel
            let response = try await backend.translate(
                text: text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                model: model
            )
            return TranslationResult(
                originalText: text,
                translatedText: response.translatedText,
                sourceLanguage: response.detectedSourceLanguage,
                targetLanguage: targetLanguage,
                provider: provider.rawValue,
                isError: false
            )
        } catch {
            return TranslationResult(
                originalText: text,
                translatedText: "Translation failed: \(error.localizedDescription)",
                sourceLanguage: sourceLanguage ?? "unknown",
                targetLanguage: targetLanguage,
                provider: provider.rawValue,
                isError: true
            )
        }
    }

    // MARK: - Language Detection

    /// Simple character-set heuristic for source language detection.
    /// Falls back to "auto" so the LLM handles accurate detection.
    func detectSourceLanguage(_ text: String) -> String? {
        let cjkMainRange = 0x4E00...0x9FFF
        let cjkExtA = 0x3400...0x4DBF
        let hiragana = 0x3040...0x309F
        let katakana = 0x30A0...0x30FF
        let hangul = 0xAC00...0xD7AF

        let scalars = text.unicodeScalars
        let total = scalars.count
        guard total > 0 else { return nil }

        var cjkCount = 0
        var japaneseCount = 0
        var koreanCount = 0

        for scalar in scalars {
            let val = Int(scalar.value)
            if cjkMainRange.contains(val) || cjkExtA.contains(val) {
                cjkCount += 1
            }
            if hiragana.contains(val) || katakana.contains(val) {
                japaneseCount += 1
            }
            if hangul.contains(val) {
                koreanCount += 1
            }
        }

        let cjkRatio = Double(cjkCount) / Double(total)
        let jpRatio = Double(japaneseCount) / Double(total)
        let krRatio = Double(koreanCount) / Double(total)

        if jpRatio > 0.15 { return "Japanese" }
        if krRatio > 0.3 { return "Korean" }
        if cjkRatio > 0.3 { return "Chinese" }

        // Otherwise let the model auto-detect
        return nil
    }
}
