import Foundation

final class ClaudeBackend: TranslationBackend {
    let identifier = "claude"

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"

    func translate(
        text: String,
        sourceLanguage: String?,
        targetLanguage: String,
        model: String
    ) async throws -> TranslatedTextResponse {
        let apiKey = try KeychainManager.shared.getCachedAPIKey(for: .claude)

        let src = sourceLanguage ?? "auto-detect"
        let systemPrompt = """
        You are a professional translator. Translate the user's text from \(src) to \(targetLanguage).

        Rules:
        - Preserve formatting: line breaks, markdown, code blocks, and special characters.
        - Do NOT translate code identifiers, URLs, or proper nouns that should remain in original form.
        - For code blocks, keep code unchanged and translate only comments and surrounding text.
        - Return ONLY the translated text — no preamble, no explanation, no quotes around the result.
        - If the text is already in \(targetLanguage), return it unchanged.
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": text,
                ]
            ],
        ]

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await cancellableData(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.networkError("Invalid response type")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No body"
            switch httpResponse.statusCode {
            case 401:
                throw TranslationError.invalidAPIKey
            case 429:
                throw TranslationError.rateLimited
            default:
                throw TranslationError.apiError(
                    statusCode: httpResponse.statusCode,
                    body: errorBody
                )
            }
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let translatedText = firstContent["text"] as? String
        else {
            throw TranslationError.apiError(
                statusCode: 200,
                body: "Failed to parse response"
            )
        }

        return TranslatedTextResponse(
            translatedText: translatedText.trimmingCharacters(in: .whitespacesAndNewlines),
            detectedSourceLanguage: sourceLanguage ?? "auto"
        )
    }

    func lookupWord(
        word: String,
        targetLanguage: String,
        model: String
    ) async throws -> TranslatedTextResponse {
        let apiKey = try KeychainManager.shared.getCachedAPIKey(for: .claude)

        let systemPrompt = """
        You are a bilingual dictionary. The user will give you a word or short phrase. \
        Provide a comprehensive dictionary entry in \(targetLanguage).

        Follow this format exactly:

        **发音**：<pronunciation or reading in targetLanguage>
        **词性**：<part of speech>
        **释义**：
        1. <definition in targetLanguage>
           📝 <example sentence in source language>
           💬 <translation of example in targetLanguage>
        2. <definition in targetLanguage>
           📝 <example sentence in source language>
           💬 <translation of example in targetLanguage>

        Rules:
        - Provide 2–4 definitions. For rare words, 1–2 is fine.
        - Detect the source language automatically.
        - For each definition, provide one natural example sentence.
        - Keep pronunciation concise (IPA or native script reading).
        - If the word has multiple parts of speech, list the most common one first.
        - Do NOT add a preamble or closing — start directly with **发音**.
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": word,
                ]
            ],
        ]

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        let (data, response) = try await cancellableData(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.networkError("Invalid response type")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No body"
            switch httpResponse.statusCode {
            case 401:
                throw TranslationError.invalidAPIKey
            case 429:
                throw TranslationError.rateLimited
            default:
                throw TranslationError.apiError(
                    statusCode: httpResponse.statusCode,
                    body: errorBody
                )
            }
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let dictText = firstContent["text"] as? String
        else {
            throw TranslationError.apiError(
                statusCode: 200,
                body: "Failed to parse response"
            )
        }

        return TranslatedTextResponse(
            translatedText: dictText.trimmingCharacters(in: .whitespacesAndNewlines),
            detectedSourceLanguage: "auto"
        )
    }

    // MARK: - Cancellable URLSession

    /// Thread-safe holder for a URLSessionDataTask so it can be cancelled
    /// from the `withTaskCancellationHandler` onCancel closure.
    private final class DataTaskBox: @unchecked Sendable {
        var task: URLSessionDataTask?
    }

    /// Performs a data request that properly cancels the underlying URLSessionDataTask
    /// when the Swift Task is cancelled.
    private func cancellableData(for request: URLRequest) async throws -> (Data, URLResponse) {
        let box = DataTaskBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let data = data, let response = response else {
                        continuation.resume(throwing: TranslationError.networkError("No data received"))
                        return
                    }
                    continuation.resume(returning: (data, response))
                }
                box.task = task
                task.resume()
            }
        } onCancel: {
            box.task?.cancel()
        }
    }
}
