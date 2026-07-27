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
        hosting.frame = NSRect(x: 0, y: 0, width: 520, height: 620)

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
