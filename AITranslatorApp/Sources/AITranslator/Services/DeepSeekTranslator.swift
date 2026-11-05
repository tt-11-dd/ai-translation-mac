import Foundation

/// 处理任务模式：常规翻译 / 深度润色 / 语法纠错 / 词典深度解析 / 学术改写
enum TaskMode: String, CaseIterable, Identifiable, Codable {
    case translate = "翻译"
    case polish = "润色"
    case grammar = "纠错"
    case dictionary = "词典"
    case academic = "学术"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .translate: return "arrow.triangle.2.circlepath"
        case .polish: return "sparkles"
        case .grammar: return "checkmark.bubble"
        case .dictionary: return "character.book.closed"
        case .academic: return "graduationcap"
        }
    }

    var tip: String {
        switch self {
        case .translate: return "多语言智能准确直译"
        case .polish: return "母语级地道表达润色"
        case .grammar: return "排查并修正语法与拼写"
        case .dictionary: return "音标、释义、搭配与例句解析"
        case .academic: return "顶会学术论文规范改写"
        }
    }
}

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

    /// 统一流式处理：支持常规翻译、母语润色、语法纠错、深度词典、学术改写
    @MainActor
    func processStream(
        text: String,
        mode: TaskMode = .translate,
        source: TranslateLanguage,
        target: TranslateLanguage,
        onUpdate: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationError.emptyText }

        let apiKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if apiKey.isEmpty, settings.providerPreset != .ollama {
            throw TranslationError.missingAPIKey
        }

        let base = settings.apiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/chat/completions") else {
            throw TranslationError.invalidURL
        }

        let systemPrompt = buildSystemPrompt(for: mode, target: target)
        let sourceHint = source == .auto
            ? "Detect the source language automatically."
            : "Source language: \(source.promptName)."

        let chunks = Self.splitIntoChunks(trimmed)
        var prefix = ""
        var allResults: [String] = []

        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()

            let userPrompt: String
            switch mode {
            case .translate:
                userPrompt = """
                \(sourceHint)
                Target language: \(target.promptName).

                Text to translate:
                \(chunk)
                """
            case .polish:
                userPrompt = """
                Target language: \(target.promptName).
                Polish and improve this text into natural, native, idiomatic writing:
                \(chunk)
                """
            case .grammar:
                userPrompt = """
                Check grammar and correct this text:
                \(chunk)
                """
            case .dictionary:
                userPrompt = """
                Provide a complete dictionary breakdown for:
                \(chunk)
                """
            case .academic:
                userPrompt = """
                Elevate and rewrite this text into formal publication-ready academic English:
                \(chunk)
                """
            }

            let chunkResult = try await streamOnce(
                url: url,
                apiKey: apiKey,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            ) { [prefix] partial in
                let combined = prefix.isEmpty ? partial : prefix + "\n" + partial
                onUpdate(combined)
            }

            allResults.append(chunkResult)
            prefix = allResults.joined(separator: "\n")

            if chunks.count > 1 && index < chunks.count - 1 {
                onUpdate(prefix)
            }
        }

        let result = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw TranslationError.emptyResponse }
        return result
    }

    /// 兼容旧的 translateStream 调用
    @MainActor
    func translateStream(
        text: String,
        source: TranslateLanguage,
        target: TranslateLanguage,
        onUpdate: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        try await processStream(text: text, mode: .translate, source: source, target: target, onUpdate: onUpdate)
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
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
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
    private func buildSystemPrompt(for mode: TaskMode, target: TranslateLanguage) -> String {
        switch mode {
        case .translate:
            var prompt = """
            You are a professional translation engine.
            Translate the user's text accurately and naturally into \(target.promptName).
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

        case .polish:
            return """
            You are a master bilingual editor and native-speaker writer.
            Refine and polish the user's text to make it natural, idiomatic, clear, and elegant.
            Output ONLY the polished text. Do not add explanations, conversational filler, or quotation marks.
            """

        case .grammar:
            return """
            You are a professional language proofreader.
            1. First line: Provide the fully corrected version of the text.
            2. Followed by a concise bulleted summary of key grammar/spelling issues resolved (if any).
            Keep it clean and helpful.
            """

        case .dictionary:
            return """
            You are an authoritative bilingual learner's dictionary (Oxford & Collins style).
            For the queried word or short phrase, output in this exact clean format:
            **Word** `/UK Phonetic/`  `/US Phonetic/`
            - **[Part of Speech]** Chinese definition
            - **Common Collocations / Phrases**: phrase 1 (Chinese meaning), phrase 2
            - **Example Sentences**:
              1. *English sentence* (Chinese translation)
              2. *English sentence* (Chinese translation)
            Do not wrap in extra markdown codeblocks. Output directly.
            """

        case .academic:
            return """
            You are a senior academic reviewer for Nature and IEEE publications.
            Rewrite the user's text into rigorous, objective, formal, and authoritative academic English.
            Use scholarly vocabulary and appropriate passive/objective structures.
            Output ONLY the revised academic text without introductory notes.
            """
        }
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
                let sentences = Self.splitKeepingDelimiters(para)
                var sub = ""
                for piece in sentences {
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

    /// 按句号等切分，保留原分隔符（避免中文。被补成英文.）
    static func splitKeepingDelimiters(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""
        let marks = Set("。！？.!?\n")
        for ch in text {
            current.append(ch)
            if marks.contains(ch) {
                parts.append(current)
                current = ""
            }
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    #if DEBUG
    static func selfCheck() {
        let parts = splitIntoChunks("你好。世界。测试", threshold: 2, size: 6)
        precondition(parts.allSatisfy { !$0.hasSuffix("..") }, "chunk must not append extra period")
        precondition(parts.contains(where: { $0.contains("。") }), "must keep Chinese period")
        let packed = splitKeepingDelimiters("甲。乙！丙")
        precondition(packed == ["甲。", "乙！", "丙"], "keep original delimiters")
    }
    #endif
}
