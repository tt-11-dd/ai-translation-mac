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

            Button("截图翻译") {
                TranslationPanelController.shared.translateScreenshot()
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

        // 仅首次（无 API Key）弹出引导；之后只留菜单栏
        if AppSettings.shared.needsAPIKey {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                TranslationPanelController.shared.show()
            }
        }

        #if DEBUG
        DeepSeekTranslator.selfCheck()
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
        if let hotKeyObserver {
            NotificationCenter.default.removeObserver(hotKeyObserver)
        }
    }

    func registerHotKey() {
        let settings = AppSettings.shared
        HotKeyManager.shared.register([
            (HotKeyManager.toggleID, settings.hotKey, {
                TranslationPanelController.shared.toggle()
            }),
            (HotKeyManager.selectionID, settings.selectionHotKey, {
                TranslationPanelController.shared.translateSelection()
            }),
            (HotKeyManager.screenshotID, settings.screenshotHotKey, {
                TranslationPanelController.shared.translateScreenshot()
            }),
        ])
    }
}
