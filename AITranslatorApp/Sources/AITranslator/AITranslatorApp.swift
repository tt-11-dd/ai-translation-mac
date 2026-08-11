import SwiftUI
import AppKit

@main
struct AITranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("打开翻译窗口") {
                TranslationPanelController.shared.show()
            }

            Button("翻译选中文本") {
                TranslationPanelController.shared.translateSelection()
            }

            Divider()

            Button("设置…") {
                SettingsWindowController.shared.show()
            }

            Divider()

            Button("退出") {
                NSApp.terminate(nil)
            }
        } label: {
            Label("AI 翻译", systemImage: "character.book.closed.fill")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerHotKey()

        hotKeyObserver = NotificationCenter.default.addObserver(
            forName: .hotKeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.registerHotKey()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            TranslationPanelController.shared.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
        if let hotKeyObserver {
            NotificationCenter.default.removeObserver(hotKeyObserver)
        }
    }

    func registerHotKey() {
        let config = AppSettings.shared.hotKey
        HotKeyManager.shared.register(config: config) {
            TranslationPanelController.shared.toggle()
        }
    }
}
