import AppKit
import ApplicationServices

/// 通过模拟 ⌘C 抓取当前选中文本（需在抢焦点之前调用）
enum SelectedTextCapture {
    static func capture(timeout: TimeInterval = 0.35) -> String? {
        if !AccessibilityHelper.isTrusted {
            AccessibilityHelper.requestTrust()
        }

        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount
        let previousString = pasteboard.string(forType: .string)

        guard postCommandC() else { return nil }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pasteboard.changeCount != previousChangeCount {
                break
            }
            Thread.sleep(forTimeInterval: 0.02)
        }

        guard pasteboard.changeCount != previousChangeCount,
              let selected = pasteboard.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !selected.isEmpty else {
            restoreClipboard(previousString)
            return nil
        }

        // 恢复原剪贴板，避免覆盖用户内容
        restoreClipboard(previousString)
        return selected
    }

    private static func postCommandC() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyC: CGKeyCode = 8 // kVK_ANSI_C

        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false) else {
            return false
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    private static func restoreClipboard(_ previous: String?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let previous {
            pasteboard.setString(previous, forType: .string)
        }
    }
}

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
