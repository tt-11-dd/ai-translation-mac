import AppKit
import SwiftUI

@MainActor
final class TranslationPanelController: NSObject {
    static let shared = TranslationPanelController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<TranslationPopupView>?
    private let viewModel = TranslationViewModel()

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

    func show(openSettings: Bool = false) {
        if panel == nil {
            createPanel()
        }

        viewModel.prepareForOpen()

        guard let panel else { return }
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
        panel?.orderOut(nil)
    }

    private func createPanel() {
        let content = TranslationPopupView(
            viewModel: viewModel,
            onClose: { [weak self] in
                self?.hide()
            }
        )

        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(x: 0, y: 0, width: 560, height: 480)

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
        panel.minSize = NSSize(width: 480, height: 400)
        panel.contentView = hosting
        panel.delegate = self

        self.hostingView = hosting
        self.panel = panel
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
}
