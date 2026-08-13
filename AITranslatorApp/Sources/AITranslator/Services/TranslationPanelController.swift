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
        if !restoreSavedFrame(panel) {
            panel.setContentSize(NSSize(width: 600, height: 520))
            centerOnScreen(panel)
        }
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
        viewModel.cancelTranslating()
        persistPanelFrame()
        panel?.orderOut(nil)
    }

    func restoreFromHistory(_ item: HistoryItem) {
        show(skipPrepare: true)
        viewModel.restoreFromHistory(item)
    }

    func restoreFromHistoryAndTranslate(_ item: HistoryItem) {
        show(skipPrepare: true)
        viewModel.restoreFromHistoryAndTranslate(item)
    }

    func translateSelection() {
        guard AccessibilityHelper.isTrusted else {
            AccessibilityHelper.requestTrust()
            DispatchQueue.main.async {
                AccessibilityHelper.openSettings()
            }
            return
        }

        let text = SelectedTextReader.readSelectedText()
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            show()
            return
        }

        show(skipPrepare: true)
        viewModel.setExternalText(text)
        Task { @MainActor in
            await viewModel.translate()
        }
    }

    /// 系统框选截图 → 剪贴板 → OCR → 翻译
    func translateScreenshot() {
        hide()
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-c"]
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    self.show(skipPrepare: true)
                    self.viewModel.errorMessage = "无法启动截图"
                }
                return
            }
            let status = process.terminationStatus
            DispatchQueue.main.async {
                guard status == 0 else { return }
                self.show(skipPrepare: true)
                Task { await self.viewModel.ocrClipboardAndTranslate() }
            }
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
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = false
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 520, height: 440)
        panel.contentView = hosting
        panel.delegate = self

        self.hostingView = hosting
        self.panel = panel
    }

    // MARK: - 窗口位置与尺寸

    private func restoreSavedFrame(_ panel: NSPanel) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.frameKey),
              let box = try? JSONDecoder().decode(FrameBox.self, from: data) else {
            return false
        }

        let size = NSSize(width: box.width, height: box.height)
        guard size.width >= panel.minSize.width, size.height >= panel.minSize.height else {
            return false
        }

        if let x = box.x, let y = box.y {
            let frame = NSRect(x: x, y: y, width: size.width, height: size.height)
            if Self.isFrameVisible(frame) {
                panel.setFrame(frame, display: false)
                return true
            }
        }

        panel.setContentSize(size)
        centerOnScreen(panel)
        return true
    }

    private func persistPanelFrame() {
        guard let panel else { return }
        let frame = panel.frame
        let box = FrameBox(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height)
        if let data = try? JSONEncoder().encode(box) {
            UserDefaults.standard.set(data, forKey: Self.frameKey)
        }
    }

    private struct FrameBox: Codable {
        var x: CGFloat?
        var y: CGFloat?
        var width: CGFloat
        var height: CGFloat
    }

    /// 至少有一部分落在某块屏幕上才算有效
    private static func isFrameVisible(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(frame)
        }
    }

    private func centerOnScreen(_ panel: NSPanel) {
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
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
        persistPanelFrame()
    }

    func windowDidResize(_ notification: Notification) {
        persistPanelFrame()
    }
}
