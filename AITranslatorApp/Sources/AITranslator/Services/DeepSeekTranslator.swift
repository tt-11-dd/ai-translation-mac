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
            return "请先在设置中填写 API Key"
        case .emptyText:
            return "请输入要翻译的文本"
        case .invalidURL:
            return "API 地址无效"
        case .httpStatus(let code, let body):
            let message = Self.extractErrorMessage(from: body) ?? body
            let preview = String(message.prefix(200))
            return "请求失败 (\(code)): \(preview)"
        case .emptyResponse:
            return "模型返回了空结果"
        case .decodingFailed:
            return "解析响应失败"
        case .cancelled:
            return nil
        }
    }

    /// 从 OpenAI 兼容错误体 {"error":{"message":"..."}} 里提取人话信息
    static func extractErrorMessage(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String,
              !message.isEmpty else {
            return nil
        }
        return message
    }
}

struct DeepSeekTranslator {
    private let settings: AppSettings

    /// 超过该长度触发分块翻译
    private static let chunkThreshold = 4000
    /// 每个分块的目标字符数
    private static let chunkSize = 2500

    init(settings: AppSettings) {
        self.settings = settings
    }

    @MainActor
    static func makeDefault() -> DeepSeekTranslator {
        DeepSeekTranslator(settings: .shared)
    }

    /// 流式翻译：每收到一段内容就回调累计全文；超长文本自动分块逐段翻译
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

        let systemPrompt = buildSystemPrompt()
        let sourceHint = source == .auto
            ? "Detect the source language automatically."
            : "Source language: \(source.promptName)."

        let chunks = Self.splitIntoChunks(trimmed)
        var prefix = ""
        var allResults: [String] = []

        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()

            let userPrompt = """
            \(sourceHint)
            Target language: \(target.promptName).

            Text to translate:
            \(chunk)
            """
            let chunkResult = try await streamOnce(
                url: url,
                apiKey: apiKey,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            ) { [prefix] partial in
                // 已有分块的结果 + 当前分块的累计输出
                let combined = prefix.isEmpty ? partial : prefix + "\n" + partial
                onUpdate(combined)
            }

            allResults.append(chunkResult)
            prefix = allResults.joined(separator: "\n")

            // 多于一个分块时，在分块间隙也同步一次完整结果
            if chunks.count > 1 && index < chunks.count - 1 {
                onUpdate(prefix)
            }
        }

        let result = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw TranslationError.emptyResponse }
        return result
    }

    // MARK: - 单次流式请求

    @MainActor
    private func streamOnce(
        url: URL,
        apiKey: String,
        systemPrompt: String,
        userPrompt: String,
        onUpdate: @escaping @MainActor (String) -> Void
    ) async throws -> String {
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

            // 兼容 delta / message（deepseek-reasoner 的 reasoning_content 会被忽略，只取 content）
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

    // MARK: - System prompt 与分块

    @MainActor
    private func buildSystemPrompt() -> String {
        var prompt = """
        You are a professional translation engine.
        Translate the user's text accurately and naturally.
        Preserve meaning, tone, and formatting (line breaks, markdown, code blocks).
        Output ONLY the translation. Do not add explanations, quotes, or notes.
        \(settings.translationStyle.promptInstruction)
        """

        if !settings.glossary.isEmpty {
            let entries = settings.glossary
                .filter { !$0.source.isEmpty && !$0.target.isEmpty }
                .map { "\($0.source) → \($0.target)" }
            if !entries.isEmpty {
                prompt += """

                Use the following glossary. For these terms, ALWAYS use the specified translation even if context suggests otherwise:
                \(entries.joined(separator: "\n"))
                """
            }
        }

        return prompt
    }

    /// 把长文本按段落切块，每块不超过 chunkSize 字符；不足阈值时直接整段返回
    static func splitIntoChunks(_ text: String, threshold: Int = chunkThreshold, size: Int = chunkSize) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if trimmed.count <= threshold { return [trimmed] }

        let paragraphs = trimmed.components(separatedBy: .newlines)
        var chunks: [String] = []
        var current = ""

        func flush() {
            if !current.isEmpty {
                chunks.append(current)
                current = ""
            }
        }

        for para in paragraphs {
            if para.count > size {
                flush()
                // 超长段落按句子拆
                let sentences = para.split(whereSeparator: { $0 == "." || $0 == "。" || $0 == "!" || $0 == "？" || $0 == "\n" })
                var sub = ""
                for sentence in sentences {
                    let piece = String(sentence) + "."
                    if sub.count + piece.count > size, !sub.isEmpty {
                        chunks.append(sub)
                        sub = ""
                    }
                    sub += piece
                }
                if !sub.isEmpty { chunks.append(sub) }
                continue
            }

            if current.count + para.count + 1 > size, !current.isEmpty {
                flush()
            }
            if current.isEmpty {
                current = para
            } else {
                current += "\n" + para
            }
        }
        flush()
        return chunks
    }
}
