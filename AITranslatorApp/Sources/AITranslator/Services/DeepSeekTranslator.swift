import Foundation

enum TranslationError: LocalizedError, Equatable {
    case missingAPIKey
    case emptyText
    case invalidURL
    case httpStatus(Int, String)
    case emptyResponse
    case decodingFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先在设置中填写 DeepSeek API Key"
        case .emptyText:
            return "请输入要翻译的文本"
        case .invalidURL:
            return "API 地址无效"
        case .httpStatus(let code, let body):
            return "请求失败 (\(code)): \(body)"
        case .emptyResponse:
            return "模型返回了空结果"
        case .decodingFailed:
            return "解析响应失败"
        case .cancelled:
            return nil
        }
    }
}

struct DeepSeekTranslator {
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    @MainActor
    static func makeDefault() -> DeepSeekTranslator {
        DeepSeekTranslator(settings: .shared)
    }

    /// 流式翻译：每收到一段内容就回调累计全文
    @MainActor
    func translateStream(
        text: String,
        source: TranslateLanguage,
        target: TranslateLanguage,
        onUpdate: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationError.emptyText }

        let apiKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw TranslationError.missingAPIKey }

        let base = settings.apiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/chat/completions") else {
            throw TranslationError.invalidURL
        }

        let systemPrompt = """
        You are a professional translation engine.
        Translate the user's text accurately and naturally.
        Preserve meaning, tone, and formatting (line breaks, markdown, code blocks).
        Output ONLY the translation. Do not add explanations, quotes, or notes.
        """

        let sourceHint = source == .auto
            ? "Detect the source language automatically."
            : "Source language: \(source.promptName)."
        let userPrompt = """
        \(sourceHint)
        Target language: \(target.promptName).

        Text to translate:
        \(trimmed)
        """

        let body: [String: Any] = [
            "model": settings.model,
            "temperature": 0.2,
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TranslationError.decodingFailed
        }

        guard (200...299).contains(http.statusCode) else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
                if errorData.count > 4096 { break }
            }
            let message = String(data: errorData, encoding: .utf8) ?? ""
            throw TranslationError.httpStatus(http.statusCode, message)
        }

        var assembled = ""
        for try await line in bytes.lines {
            try Task.checkCancellation()

            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.hasPrefix("data:") else { continue }

            let payload = trimmedLine.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload.isEmpty || payload == "[DONE]" {
                if payload == "[DONE]" { break }
                continue
            }

            guard let data = payload.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first else {
                continue
            }

            // 兼容 delta / message
            let piece: String?
            if let delta = first["delta"] as? [String: Any] {
                piece = delta["content"] as? String
            } else if let message = first["message"] as? [String: Any] {
                piece = message["content"] as? String
            } else {
                piece = nil
            }

            guard let piece, !piece.isEmpty else { continue }
            assembled += piece
            onUpdate(assembled)
        }

        let result = assembled.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw TranslationError.emptyResponse }
        return result
    }
}
