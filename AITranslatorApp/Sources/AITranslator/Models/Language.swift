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
