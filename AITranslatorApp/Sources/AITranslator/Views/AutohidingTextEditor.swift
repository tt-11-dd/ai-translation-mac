import AppKit
import SwiftUI

/// 双击全选的 NSTextView：双击任意位置选中整段文本（翻译场景比「选词」更实用）
final class SelectAllOnDoubleClickTextView: NSTextView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 3 {
            let fullRange = NSRange(location: 0, length: (string as NSString).length)
            setSelectedRange(fullRange)
            return
        }
        super.mouseDown(with: event)
    }
}

/// 编辑器焦点协调器：让 NSTextView 之间通过第一响应者切换焦点
/// （SwiftUI 的 @FocusState 对 NSViewRepresentable 不生效，需要手动转交第一响应者）
/// 仅在主线程被调用（makeNSView / doCommandBy 都在主线程），因此无需 actor 隔离
final class EditorFocusCoordinator {
    static let shared = EditorFocusCoordinator()

    private var editors: [String: NSView] = [:]

    private init() {}

    func register(id: String, view: NSView) {
        editors[id] = view
    }

    func unregister(id: String) {
        editors.removeValue(forKey: id)
    }

    func focus(id: String) {
        guard let view = editors[id] else { return }
        let window = view.window
        window?.makeFirstResponder(view)
        // 若被视图本身不是 NSTextView 容器，尝试找到其内的文本视图
        if let textView = view as? NSTextView {
            textView.window?.makeFirstResponder(textView)
        } else if let scrollView = view as? NSScrollView,
                  let doc = scrollView.documentView as? NSTextView {
            doc.window?.makeFirstResponder(doc)
        }
    }
}

/// 仅在内容超出时显示滚动条（overlay 风格）
struct AutohidingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var fontSize: CGFloat = 14
    /// 按 id 注册到焦点协调器，用于 Tab 切换
    var focusID: String? = nil
    /// 按下回车（无 Shift）时回调；nil 表示不拦截
    var onEnter: (() -> Void)? = nil
    /// 按下 Tab / Shift+Tab 时回调（用于切换编辑器焦点）；nil 表示不拦截
    var onTab: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.autoresizingMask = [.width, .height]

        let textView = SelectAllOnDoubleClickTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.labelColor
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // 初始文本非空时，光标放到末尾
        if !text.isEmpty {
            textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.focusID = focusID
        if let focusID {
            EditorFocusCoordinator.shared.register(id: focusID, view: scrollView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            // 外部/程序化更新文本（如剪贴板填入、历史回填）时，光标移到末尾
            textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        }
        textView.isEditable = isEditable
        textView.font = NSFont.systemFont(ofSize: fontSize)
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        context.coordinator.onEnter = onEnter
        context.coordinator.onTab = onTab
        context.coordinator.focusID = focusID
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        if let focusID = coordinator.focusID {
            EditorFocusCoordinator.shared.unregister(id: focusID)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onEnter: onEnter, onTab: onTab)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?
        var onEnter: (() -> Void)?
        var onTab: (() -> Void)?
        var focusID: String?

        init(text: Binding<String>, onEnter: (() -> Void)?, onTab: (() -> Void)?) {
            self.text = text
            self.onEnter = onEnter
            self.onTab = onTab
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Shift+回车 → 换行；普通回车 → 触发翻译回调
                let modifiers = NSApp.currentEvent?.modifierFlags ?? []
                if modifiers.contains(.shift) {
                    textView.insertNewline(nil)
                    return true
                }
                if let onEnter {
                    onEnter()
                    return true
                }
            }

            if commandSelector == #selector(NSResponder.insertTab(_:))
                || commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                if let onTab {
                    onTab()
                    return true
                }
            }

            return false
        }
    }
}
