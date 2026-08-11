import AppKit
import ApplicationServices

/// 通过辅助功能 API 读取当前前台 App 中选中的文本
@MainActor
enum SelectedTextReader {
    static func readSelectedText() -> String? {
        guard AccessibilityHelper.isTrusted else { return nil }

        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        let pid = app.processIdentifier

        let appElement = AXUIElementCreateApplication(pid)
        var focusedValue: CFTypeRef?
        let focusedErr = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)
        guard focusedErr == .success, let focused = focusedValue else { return nil }

        // 优先取 focused 元素的选中文本
        let focusedElement = focused as! AXUIElement
        var selectedValue: CFTypeRef?
        let selectedErr = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        )
        if selectedErr == .success,
           let selected = selectedValue as? String,
           !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return selected
        }

        // 兜底：遍历所有窗口找选中文本
        var windowsValue: CFTypeRef?
        let windowsErr = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        guard windowsErr == .success, let windows = windowsValue as? [AXUIElement] else { return nil }

        for window in windows {
            if let text = searchSelectedText(in: window) {
                return text
            }
        }
        return nil
    }

    private static func searchSelectedText(in element: AXUIElement) -> String? {
        var roleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) == .success,
              let role = roleValue as? String else { return nil }

        // 文本框 / 文本区域直接取选中文本
        if role == kAXTextAreaRole as String || role == kAXTextFieldRole as String || role == kAXStaticTextRole as String {
            var selectedValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedValue) == .success,
               let selected = selectedValue as? String,
               !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return selected
            }
        }

        // 递归子元素
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else { return nil }

        for child in children {
            if let text = searchSelectedText(in: child) {
                return text
            }
        }
        return nil
    }
}
