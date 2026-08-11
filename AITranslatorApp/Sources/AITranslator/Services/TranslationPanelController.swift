import AppKit
import SwiftUI

@MainActor
final class TranslationPanelController: NSObject {
    static let shared = TranslationPanelController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<TranslationPopupView>?
    private let viewModel = TranslationViewModel()

    private static let frameKey = "translationPanelFrame"

    private override init() {
        super.init()
    }

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show(openSettings: Bool = false, skipPrepare: Bool = false) {
        if panel == nil {
            createPanel()
        }

        if !skipPrepare {
            viewModel.prepareForOpen()
        }

        guard let panel else { return }
        // 恢复上次的尺寸（不恢复位置），然后居中显示
        if !restoreSavedSize(panel) {
            panel.setContentSize(NSSize(width: 600, height: 520))
        }
        centerOnScreen(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        if openSettings {
            DispatchQueue.main.async {
                SettingsWindowController.shared.show()
            }
        }
    }

    func hide() {
        // 窗口收起时取消进行中的翻译，避免后台空跑
        viewModel.cancelTranslating()
        persistPanelSize()
        panel?.orderOut(nil)
    }

    /// 从历史记录回填：填入原文与译文并显示窗口
    func restoreFromHistory(_ item: HistoryItem) {
        // 先显示窗口（跳过剪贴板/清空逻辑），再回填内容
        show(skipPrepare: true)
        viewModel.restoreFromHistory(item)
    }

    /// 从历史记录回填原文并立即重新翻译
    func restoreFromHistoryAndTranslate(_ item: HistoryItem) {
        show(skipPrepare: true)
        viewModel.restoreFromHistoryAndTranslate(item)
    }

    /// 翻译当前选中的文本：读取前台 App 选中内容并触发翻译
    func translateSelection() {
        guard AccessibilityHelper.isTrusted else {
            // 未授权：弹出系统授权提示并引导到设置
            AccessibilityHelper.requestTrust()
            DispatchQueue.main.async {
                AccessibilityHelper.openSettings()
            }
            return
        }

        let text = SelectedTextReader.readSelectedText()
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // 没有读到选中内容，退回普通打开
            show()
            return
        }

        // 跳过 prepareForOpen（避免清空/剪贴板覆盖），直接填入选中文本并翻译
        show(skipPrepare: true)
        viewModel.setExternalText(text)
        Task { @MainActor in
            await viewModel.translate()
        }
    }

    private func createPanel() {
        let content = TranslationPopupView(
            viewModel: viewModel,
            onClose: { [weak self] in
                self?.hide()
            }
        )

        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 600, height: 520)

        let panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "AI 翻译"
        panel.titleVisibility = .visible
        panel.titlebarAppearsTransparent = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = false
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 520, height: 440)
        panel.contentView = hosting

        self.hostingView = hosting
        self.panel = panel
    }

    // MARK: - 窗口尺寸记忆

    /// 恢复上次保存的尺寸；返回 false 表示无记录或尺寸非法
    private func restoreSavedSize(_ panel: NSPanel) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.frameKey),
              let box = try? JSONDecoder().decode(SizeBox.self, from: data) else {
            return false
        }

        let savedSize = NSSize(width: box.width, height: box.height)
        guard savedSize.width >= panel.minSize.width, savedSize.height >= panel.minSize.height else {
            return false
        }
        panel.setContentSize(savedSize)
        return true
    }

    private func persistPanelSize() {
        guard let panel else { return }
        let size = panel.frame.size
        let box = SizeBox(width: size.width, height: size.height)
        if let data = try? JSONEncoder().encode(box) {
            UserDefaults.standard.set(data, forKey: Self.frameKey)
        }
    }

    /// 保存窗口尺寸的 Codable 辅助结构
    private struct SizeBox: Codable {
        let width: CGFloat
        let height: CGFloat
    }

    private func centerOnScreen(_ panel: NSPanel) {
        let screen = NSScreen.main
            ?? NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.screens.first

        guard let screen else {
            panel.center()
            return
        }

        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - panel.frame.width / 2,
            y: visible.midY - panel.frame.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}

extension TranslationPanelController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    func windowDidMove(_ notification: Notification) {
        // 仅记录尺寸（每次打开居中，不记忆位置）
        persistPanelSize()
    }

    func windowDidResize(_ notification: Notification) {
        persistPanelSize()
    }
}
