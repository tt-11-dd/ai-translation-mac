import AppKit
import AVFoundation

/// 译文朗读：按目标语言选择系统语音
@MainActor
final class TTSSpeaker: NSObject {
    static let shared = TTSSpeaker()

    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking = false
    /// 朗读结束（无论正常或被打断）时回调，用于同步 UI
    var onFinish: (() -> Void)?

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: TranslateLanguage) {
        guard !text.isEmpty else { return }

        if isSpeaking {
            stop()
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        if let voice = Self.voice(for: language) {
            utterance.voice = voice
        }
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            onFinish?()
        }
    }

    private static func voice(for language: TranslateLanguage) -> AVSpeechSynthesisVoice? {
        let preferred = AVSpeechSynthesisVoice.speechVoices()
        let candidates: [String]

        switch language {
        case .chinese:
            candidates = ["zh-CN", "zh-TW", "zh-HK"]
        case .english:
            candidates = ["en-US", "en-GB", "en-AU"]
        case .japanese:
            candidates = ["ja-JP"]
        case .korean:
            candidates = ["ko-KR"]
        case .french:
            candidates = ["fr-FR"]
        case .german:
            candidates = ["de-DE"]
        case .spanish:
            candidates = ["es-ES", "es-MX"]
        case .italian:
            candidates = ["it-IT"]
        case .portuguese:
            candidates = ["pt-BR", "pt-PT"]
        case .russian:
            candidates = ["ru-RU"]
        default:
            return nil
        }

        // 优先匹配精确语言代码，其次同一语言族内任意语音
        for candidate in candidates {
            if let voice = AVSpeechSynthesisVoice(language: candidate) {
                return voice
            }
        }

        guard let languagePrefix = candidates.first.map({ String($0.prefix(2)) }) else {
            return nil
        }
        return preferred.first(where: { voice in
            String(voice.language.prefix(2)) == languagePrefix
        })
    }
}

extension TTSSpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            onFinish?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            onFinish?()
        }
    }
}
