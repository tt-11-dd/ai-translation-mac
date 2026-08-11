import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show() {
        if window == nil {
            createWindow()
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        guard let window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // 显示后按内容自适应高度，避免上下留白
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window,
                  let hosting = window.contentView as? NSHostingView<SettingsView> else { return }
            let fitting = hosting.fittingSize
            guard fitting.height > 0 else { return }
            let newSize = NSSize(width: 860, height: fitting.height)
            if abs(window.frame.height - newSize.height) > 2 {
                var frame = window.frame
                frame.origin.y += frame.height - newSize.height
                frame.size = newSize
                window.setFrame(frame, display: true)
            }
        }
    }

    func hide() {
        window?.orderOut(nil)
        let hasVisible = NSApp.windows.contains { $0.isVisible && $0 !== window }
        if !hasVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func createWindow() {
        let content = SettingsView {
            SettingsWindowController.shared.hide()
        }
        let hosting = NSHostingView(rootView: content)
        // 宽度固定，高度跟随内容自适应（不写死，避免上下留白）
        let contentSize = hosting.fittingSize
        hosting.frame = NSRect(x: 0, y: 0, width: 860, height: max(contentSize.height, 480))

        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.delegate = self
        window.center()
        self.window = window
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }
}
