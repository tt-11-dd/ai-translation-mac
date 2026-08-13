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
    @Published var isSpeaking = false
    /// 智能互翻下用户手动改了语言，本次不再自动覆盖
    @Published var smartOverride = false

    private let translator = DeepSeekTranslator.makeDefault()
    private let settings = AppSettings.shared
    private var translateTask: Task<Void, Never>?
    private var requestID = UUID()
    /// 上次填入或译出的文本，用于避免剪贴板把译文再翻回去
    private var lastClipboardFingerprint = ""

    init() {
        sourceLanguage = AppSettings.shared.sourceLanguage
        targetLanguage = AppSettings.shared.targetLanguage
    }

    func prepareForOpen() {
        sourceLanguage = settings.sourceLanguage
        targetLanguage = settings.targetLanguage
        errorMessage = nil
        statusMessage = nil
        smartOverride = false

        if settings.clearOnOpen {
            translateTask?.cancel()
            inputText = ""
            outputText = ""
            isTranslating = false
        }

        if settings.useClipboardOnOpen,
           let clip = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !clip.isEmpty {
            if clip == lastClipboardFingerprint {
                applySmartLanguagesIfNeeded()
                return
            }
            inputText = clip
            lastClipboardFingerprint = clip
            statusMessage = "已填入剪贴板"
            applySmartLanguagesIfNeeded()
            return
        }

        // 剪贴板没有文本但有图片 → 截图翻译：OCR 识别后填入
        if settings.useClipboardOnOpen,
           OCRService.clipboardImage() != nil {
            statusMessage = "正在识别图片…"
            Task { [weak self] in
                guard let self else { return }
                await self.recognizeClipboardImage()
            }
            return
        }

        applySmartLanguagesIfNeeded()
    }

    /// 识别剪贴板图片中的文字并填入，可自动翻译
    func recognizeClipboardImage(forceTranslate: Bool = false) async {
        guard let image = OCRService.clipboardImage(),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let text = await OCRService.recognizeText(in: cgImage) else {
            statusMessage = "图片中未识别到文字"
            return
        }

        // 期间用户可能已手动输入或切换了内容，避免覆盖
        if !inputText.isEmpty {
            statusMessage = "已识别图片文字"
            return
        }

        inputText = text
        statusMessage = "已识别图片文字"
        applySmartLanguagesIfNeeded()

        if settings.autoTranslateOnOpen || forceTranslate {
            await translate()
        }
    }

    /// 截图翻译：忽略「打开时不清空」之类的保护，直接 OCR 并翻译
    func ocrClipboardAndTranslate() async {
        translateTask?.cancel()
        inputText = ""
        outputText = ""
        errorMessage = nil
        isTranslating = false
        await recognizeClipboardImage(forceTranslate: true)
    }

    func applySmartLanguagesIfNeeded() {
        guard settings.smartChineseEnglish, !smartOverride else { return }
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let pair = LanguageDetector.resolveChineseEnglish(for: trimmed)
        sourceLanguage = pair.source
        targetLanguage = pair.target
    }

    func swapLanguages() {
        smartOverride = true
        if sourceLanguage == .auto {
            // 自动检测时没有明确的源语言，反向推导：把当前目标语作为新的源语言
            let newSource = targetLanguage
            // 目标语言则根据新源语给一个合理的默认值（中↔英，其余语言回中文）
            let newTarget: TranslateLanguage
            switch newSource {
            case .chinese:
                newTarget = .english
            case .english:
                newTarget = .chinese
            default:
                newTarget = .chinese
            }
            sourceLanguage = newSource
            targetLanguage = newTarget
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
            // 翻译完成，聚焦译文框方便直接微调
            EditorFocusCoordinator.shared.focus(id: "output")
            settings.sourceLanguage = sourceLanguage
            settings.targetLanguage = targetLanguage

            // 记录历史
            HistoryStore.shared.add(
                source: inputText,
                target: result,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )

            // 记录用量（按输入字符数）
            UsageStore.shared.record(characters: inputText.count)

            if settings.autoCopyOnComplete {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result, forType: .string)
                lastClipboardFingerprint = result
                statusMessage = "翻译完成，已复制"
            } else {
                statusMessage = "翻译完成"
            }
        } catch is CancellationError {
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
        lastClipboardFingerprint = outputText
        statusMessage = "已复制到剪贴板"
    }

    func toggleSpeakResult() {
        guard !outputText.isEmpty else { return }
        if isSpeaking {
            TTSSpeaker.shared.stop()
            isSpeaking = false
        } else {
            TTSSpeaker.shared.onFinish = { [weak self] in
                Task { @MainActor in
                    self?.isSpeaking = false
                }
            }
            TTSSpeaker.shared.speak(outputText, language: targetLanguage)
            isSpeaking = true
        }
    }

    func clear() {
        translateTask?.cancel()
        inputText = ""
        outputText = ""
        errorMessage = nil
        statusMessage = nil
        isTranslating = false
    }

    /// 取消进行中的翻译（窗口隐藏时调用）
    func cancelTranslating() {
        translateTask?.cancel()
        isTranslating = false
    }

    /// 从历史记录回填原文与译文
    func restoreFromHistory(_ item: HistoryItem) {
        translateTask?.cancel()
        inputText = item.source
        outputText = item.target
        lastClipboardFingerprint = item.target
        if let src = TranslateLanguage.fromStored(item.sourceLanguage) {
            sourceLanguage = src
        }
        if let tgt = TranslateLanguage.fromStored(item.targetLanguage) {
            targetLanguage = tgt
        }
        smartOverride = true
        errorMessage = nil
        statusMessage = "已从历史回填"
        isTranslating = false
    }

    /// 从历史记录回填原文并立即重新翻译（忽略历史译文）
    func restoreFromHistoryAndTranslate(_ item: HistoryItem) {
        translateTask?.cancel()
        inputText = item.source
        outputText = ""
        errorMessage = nil
        isTranslating = false
        if let src = TranslateLanguage.fromStored(item.sourceLanguage) {
            sourceLanguage = src
        }
        if let tgt = TranslateLanguage.fromStored(item.targetLanguage) {
            targetLanguage = tgt
        }
        smartOverride = true
        Task { await translate() }
    }

    /// 设置外部传入的文本（如选中文本），并应用智能语言判断
    func setExternalText(_ text: String) {
        translateTask?.cancel()
        inputText = text
        outputText = ""
        errorMessage = nil
        isTranslating = false
        applySmartLanguagesIfNeeded()
    }
}
