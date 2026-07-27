import Foundation
import AppKit

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var outputText: String = ""
    @Published var sourceLanguage: TranslateLanguage
    @Published var targetLanguage: TranslateLanguage
    @Published var isTranslating = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    private let translator = DeepSeekTranslator.makeDefault()
    private let settings = AppSettings.shared
    private var translateTask: Task<Void, Never>?
    private var requestID = UUID()

    init() {
        sourceLanguage = AppSettings.shared.sourceLanguage
        targetLanguage = AppSettings.shared.targetLanguage
    }

    /// - Parameter selectedText: 唤起前抓到的划词（优先于剪贴板）
    func prepareForOpen(selectedText: String? = nil) {
        sourceLanguage = settings.sourceLanguage
        targetLanguage = settings.targetLanguage
        errorMessage = nil
        statusMessage = nil

        if settings.clearOnOpen {
            translateTask?.cancel()
            inputText = ""
            outputText = ""
            isTranslating = false
        }

        if let selected = selectedText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !selected.isEmpty,
           settings.useSelectionOnOpen {
            inputText = selected
            statusMessage = "已填入划词"
        } else if settings.useClipboardOnOpen,
                  let clip = NSPasteboard.general.string(forType: .string)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !clip.isEmpty {
            inputText = clip
            statusMessage = "已填入剪贴板"
        }

        applySmartLanguagesIfNeeded()
    }

    func applySmartLanguagesIfNeeded() {
        guard settings.smartChineseEnglish else { return }
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let pair = LanguageDetector.resolveChineseEnglish(for: trimmed)
        sourceLanguage = pair.source
        targetLanguage = pair.target
    }

    func swapLanguages() {
        if sourceLanguage == .auto {
            sourceLanguage = targetLanguage
            targetLanguage = .english
        } else {
            let oldSource = sourceLanguage
            sourceLanguage = targetLanguage
            targetLanguage = oldSource
        }
        if !outputText.isEmpty {
            let tmp = inputText
            inputText = outputText
            outputText = tmp
        }
    }

    func translate() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            outputText = ""
            return
        }

        applySmartLanguagesIfNeeded()

        translateTask?.cancel()
        let id = UUID()
        requestID = id

        translateTask = Task { [weak self] in
            guard let self else { return }
            await self.runStreamingTranslate(requestID: id)
        }
        await translateTask?.value
    }

    private func runStreamingTranslate(requestID id: UUID) async {
        isTranslating = true
        errorMessage = nil
        statusMessage = "正在翻译…"
        outputText = ""

        do {
            let result = try await translator.translateStream(
                text: inputText,
                source: sourceLanguage,
                target: targetLanguage
            ) { [weak self] partial in
                guard let self, self.requestID == id else { return }
                self.outputText = partial
            }

            guard requestID == id, !Task.isCancelled else { return }
            outputText = result
            settings.sourceLanguage = sourceLanguage
            settings.targetLanguage = targetLanguage

            if settings.autoCopyOnComplete {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result, forType: .string)
                statusMessage = "翻译完成，已复制"
            } else {
                statusMessage = "翻译完成"
            }
        } catch is CancellationError {
            // 被取消时静默忽略
        } catch {
            guard requestID == id else { return }
            if error is CancellationError { return }
            errorMessage = error.localizedDescription
            statusMessage = nil
        }

        if requestID == id {
            isTranslating = false
        }
    }

    func copyResult() {
        guard !outputText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        statusMessage = "已复制到剪贴板"
    }

    func clear() {
        translateTask?.cancel()
        inputText = ""
        outputText = ""
        errorMessage = nil
        statusMessage = nil
        isTranslating = false
    }
}
