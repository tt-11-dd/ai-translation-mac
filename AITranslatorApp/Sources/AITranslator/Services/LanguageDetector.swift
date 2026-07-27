import Foundation

enum LanguageDetector {
    /// 中英智能互翻：偏中文 → 英；偏英文 → 中
    static func resolveChineseEnglish(for text: String) -> (source: TranslateLanguage, target: TranslateLanguage) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (.auto, .chinese)
        }

        var cjk = 0
        var latin = 0
        for scalar in trimmed.unicodeScalars {
            let v = scalar.value
            if (0x4E00...0x9FFF).contains(v)
                || (0x3400...0x4DBF).contains(v)
                || (0xF900...0xFAFF).contains(v) {
                cjk += 1
            } else if (0x41...0x5A).contains(v) || (0x61...0x7A).contains(v) {
                latin += 1
            }
        }

        if cjk == 0 && latin == 0 {
            return (.auto, .chinese)
        }
        if cjk >= latin {
            return (.chinese, .english)
        }
        return (.english, .chinese)
    }
}
