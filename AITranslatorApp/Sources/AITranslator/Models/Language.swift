import Foundation

enum TranslateLanguage: String, CaseIterable, Identifiable, Codable {
    case auto
    case chinese
    case english
    case japanese
    case korean
    case french
    case german
    case spanish
    case portuguese
    case russian
    case italian
    case thai
    case vietnamese
    case arabic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "自动检测"
        case .chinese: return "中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .spanish: return "Español"
        case .portuguese: return "Português"
        case .russian: return "Русский"
        case .italian: return "Italiano"
        case .thai: return "ไทย"
        case .vietnamese: return "Tiếng Việt"
        case .arabic: return "العربية"
        }
    }

    var promptName: String {
        switch self {
        case .auto: return "the same language as detected source"
        case .chinese: return "Simplified Chinese"
        case .english: return "English"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .french: return "French"
        case .german: return "German"
        case .spanish: return "Spanish"
        case .portuguese: return "Portuguese"
        case .russian: return "Russian"
        case .italian: return "Italian"
        case .thai: return "Thai"
        case .vietnamese: return "Vietnamese"
        case .arabic: return "Arabic"
        }
    }

    static var sourceOptions: [TranslateLanguage] {
        allCases
    }

    static var targetOptions: [TranslateLanguage] {
        allCases.filter { $0 != .auto }
    }
}

/// 翻译风格：影响译文的语气与用词
enum TranslationStyle: String, CaseIterable, Identifiable {
    case general
    case formal
    case casual
    case academic
    case code
    case subtitle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: return "通用"
        case .formal: return "正式"
        case .casual: return "口语化"
        case .academic: return "学术论文"
        case .code: return "代码注释"
        case .subtitle: return "字幕"
        }
    }

    /// 追加到 system prompt 的指令
    var promptInstruction: String {
        switch self {
        case .general:
            return "Use a natural, neutral tone."
        case .formal:
            return "Use a formal, polished register appropriate for business or official documents."
        case .casual:
            return "Use a casual, conversational tone as if chatting with a friend."
        case .academic:
            return "Use an academic register: precise, objective, with formal academic vocabulary and hedged claims."
        case .code:
            return "Translate as code comments: concise, imperative, and technical. Keep code identifiers and syntax unchanged."
        case .subtitle:
            return "Translate as subtitles: short, punchy, readable at a glance, preserving tone and keeping line length brief."
        }
    }
}

/// 提供商预设：一键切换 baseURL 与默认模型
enum ProviderPreset: String, CaseIterable, Identifiable {
    case deepseek
    case moonshot
    case ollama
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .moonshot: return "Moonshot Kimi"
        case .ollama: return "Ollama（本地）"
        case .custom: return "自定义"
        }
    }

    var baseURL: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com"
        case .moonshot: return "https://api.moonshot.cn"
        case .ollama: return "http://127.0.0.1:11434"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .deepseek: return "deepseek-chat"
        case .moonshot: return "moonshot-v1-8k"
        case .ollama: return "qwen2.5:7b"
        case .custom: return ""
        }
    }
}
