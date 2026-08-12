import AppKit
import Vision

/// 图片 OCR：识别截图 / 剪贴板图片里的文字
@MainActor
enum OCRService {
    /// 用 Vision 识别一张 CGImage 中的文字，返回按阅读顺序拼接的文本
    static func recognizeText(in cgImage: CGImage) async -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        // 简体中文 + 英文（可识别中日韩等，这里覆盖主要场景）
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            NSLog("OCRService: 识别失败: \(error)")
            return nil
        }

        let observations = request.results ?? []
        guard !observations.isEmpty else { return nil }

        // 按 Y 坐标从下到上（Vision 坐标原点在左下）、X 从左到右排序，近似阅读顺序
        let sorted = observations.sorted { a, b in
            let ay = a.boundingBox.midY
            let by = b.boundingBox.midY
            if abs(ay - by) > 0.02 {
                return ay > by
            }
            return a.boundingBox.minX < b.boundingBox.minX
        }

        let lines = sorted.compactMap { $0.topCandidates(1).first?.string }
        let text = lines.joined(separator: "\n")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 读取剪贴板中的图片（若存在）
    static func clipboardImage() -> NSImage? {
        let pasteboard = NSPasteboard.general
        guard let data = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) else {
            return nil
        }
        return NSImage(data: data)
    }
}
