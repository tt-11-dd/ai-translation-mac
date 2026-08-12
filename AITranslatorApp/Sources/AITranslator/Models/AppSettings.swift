import Foundation
import Carbon
import AppKit
import ServiceManagement
import ApplicationServices

struct HotKeyConfig: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    /// 录制时记下的按键显示名（便于自定义键）
    var label: String?

    static let `default` = HotKeyConfig(
        keyCode: UInt32(kVK_ANSI_T),
        modifiers: UInt32(cmdKey | shiftKey),
        label: "T"
    )

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if let label, !label.isEmpty {
            parts.append(label)
        } else {
            parts.append(Self.keyName(for: keyCode))
        }
        return parts.joined()
    }

    /// 单键或组合键均可；自定义键用 keyCode + 显示名记录
    static func fromKeyEvent(_ event: NSEvent) -> HotKeyConfig? {
        let keyCode = UInt32(event.keyCode)
        if keyCode == UInt32(kVK_Command) ||
            keyCode == UInt32(kVK_Shift) ||
            keyCode == UInt32(kVK_Option) ||
            keyCode == UInt32(kVK_Control) ||
            keyCode == UInt32(kVK_Function) {
            return nil
        }

        let mods = carbonModifiers(from: event.modifierFlags)
        let label = Self.displayLabel(from: event) ?? Self.keyName(for: keyCode)
        return HotKeyConfig(keyCode: keyCode, modifiers: mods, label: label)
    }

    private static func displayLabel(from event: NSEvent) -> String? {
        if let chars = event.charactersIgnoringModifiers?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !chars.isEmpty {
            // 可打印字符直接展示
            let filtered = chars.filter { scalar in
                let v = scalar.unicodeScalars.first?.value ?? 0
                return v >= 32 && v != 127
            }
            if !filtered.isEmpty {
                return String(filtered).uppercased()
            }
        }
        return nil
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        return mods
    }

    private enum CodingKeys: String, CodingKey {
        case keyCode, modifiers, kind, label
    }

    init(keyCode: UInt32, modifiers: UInt32, label: String? = nil) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let kind = try c.decodeIfPresent(String.self, forKey: .kind), kind == "mouseMiddle" {
            self = .default
            return
        }
        keyCode = try c.decode(UInt32.self, forKey: .keyCode)
        modifiers = try c.decode(UInt32.self, forKey: .modifiers)
        label = try c.decodeIfPresent(String.self, forKey: .label)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(keyCode, forKey: .keyCode)
        try c.encode(modifiers, forKey: .modifiers)
        try c.encode("keyboard", forKey: .kind)
        try c.encodeIfPresent(label, forKey: .label)
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Escape: return "Esc"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return "Key\(keyCode)"
        }
    }
}

/// 一条术语映射：翻译时强制将 source 替换为 target
struct GlossaryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var source: String
    var target: String

    init(id: UUID = UUID(), source: String, target: String) {
        self.id = id
        self.source = source
        self.target = target
    }
}

enum AccessibilityHelper {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    @discardableResult
    static func requestTrust() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

enum LaunchAtLoginHelper {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var apiKey: String {
        didSet {
            // 空字符串表示清空 Keychain；否则同步保存
            if apiKey.isEmpty {
                KeychainHelper.delete()
            } else {
                KeychainHelper.save(apiKey)
            }
        }
    }

    @Published var apiBaseURL: String {
        didSet { UserDefaults.standard.set(apiBaseURL, forKey: Keys.apiBaseURL) }
    }

    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: Keys.model) }
    }

    @Published var providerPreset: ProviderPreset {
        didSet { UserDefaults.standard.set(providerPreset.rawValue, forKey: Keys.providerPreset) }
    }

    @Published var sourceLanguage: TranslateLanguage {
        didSet { UserDefaults.standard.set(sourceLanguage.rawValue, forKey: Keys.sourceLanguage) }
    }

    @Published var targetLanguage: TranslateLanguage {
        didSet { UserDefaults.standard.set(targetLanguage.rawValue, forKey: Keys.targetLanguage) }
    }

    @Published var hotKey: HotKeyConfig {
        didSet {
            if let data = try? JSONEncoder().encode(hotKey) {
                UserDefaults.standard.set(data, forKey: Keys.hotKey)
            }
        }
    }

    @Published var useClipboardOnOpen: Bool {
        didSet { UserDefaults.standard.set(useClipboardOnOpen, forKey: Keys.useClipboardOnOpen) }
    }

    @Published var autoTranslateOnOpen: Bool {
        didSet { UserDefaults.standard.set(autoTranslateOnOpen, forKey: Keys.autoTranslateOnOpen) }
    }

    @Published var clearOnOpen: Bool {
        didSet { UserDefaults.standard.set(clearOnOpen, forKey: Keys.clearOnOpen) }
    }

    @Published var autoCopyOnComplete: Bool {
        didSet { UserDefaults.standard.set(autoCopyOnComplete, forKey: Keys.autoCopyOnComplete) }
    }

    @Published var smartChineseEnglish: Bool {
        didSet { UserDefaults.standard.set(smartChineseEnglish, forKey: Keys.smartChineseEnglish) }
    }

    @Published var glossary: [GlossaryEntry] {
        didSet {
            if let data = try? JSONEncoder().encode(glossary) {
                UserDefaults.standard.set(data, forKey: Keys.glossary)
            }
        }
    }

    @Published var translationStyle: TranslationStyle {
        didSet { UserDefaults.standard.set(translationStyle.rawValue, forKey: Keys.translationStyle) }
    }

    @Published var editorFontSize: Double {
        didSet { UserDefaults.standard.set(editorFontSize, forKey: Keys.editorFontSize) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != LaunchAtLoginHelper.isEnabled else { return }
            if let error = LaunchAtLoginHelper.setEnabled(launchAtLogin) {
                launchAtLoginError = error
                launchAtLogin = LaunchAtLoginHelper.isEnabled
            } else {
                launchAtLoginError = nil
            }
        }
    }

    @Published var launchAtLoginError: String?

    private enum Keys {
        static let apiBaseURL = "apiBaseURL"
        static let model = "model"
        static let providerPreset = "providerPreset"
        static let sourceLanguage = "sourceLanguage"
        static let targetLanguage = "targetLanguage"
        static let hotKey = "hotKey"
        static let useClipboardOnOpen = "useClipboardOnOpen"
        static let autoTranslateOnOpen = "autoTranslateOnOpen"
        static let clearOnOpen = "clearOnOpen"
        static let autoCopyOnComplete = "autoCopyOnComplete"
        static let smartChineseEnglish = "smartChineseEnglish"
        static let glossary = "glossary"
        static let translationStyle = "translationStyle"
        static let editorFontSize = "editorFontSize"
    }

    private init() {
        let defaults = UserDefaults.standard
        // API Key 只从 Keychain 读取，不再写 UserDefaults，避免明文泄露
        var storedAPIKey = KeychainHelper.load() ?? ""

        // 迁移旧版本：如果 UserDefaults 里残留旧 Key 而 Keychain 为空，迁入 Keychain 后删除明文
        if storedAPIKey.isEmpty {
            if let legacy = defaults.string(forKey: "apiKey"), !legacy.isEmpty {
                storedAPIKey = legacy
                KeychainHelper.save(legacy)
                defaults.removeObject(forKey: "apiKey")
            }
        }
        apiKey = storedAPIKey

        apiBaseURL = defaults.string(forKey: Keys.apiBaseURL) ?? ProviderPreset.deepseek.baseURL
        model = defaults.string(forKey: Keys.model) ?? ProviderPreset.deepseek.defaultModel

        if let raw = defaults.string(forKey: Keys.providerPreset),
           let preset = ProviderPreset(rawValue: raw) {
            providerPreset = preset
        } else {
            providerPreset = .deepseek
        }

        if let raw = defaults.string(forKey: Keys.sourceLanguage),
           let lang = TranslateLanguage(rawValue: raw) {
            sourceLanguage = lang
        } else {
            sourceLanguage = .auto
        }

        if let raw = defaults.string(forKey: Keys.targetLanguage),
           let lang = TranslateLanguage(rawValue: raw) {
            targetLanguage = lang
        } else {
            targetLanguage = .chinese
        }

        if let data = defaults.data(forKey: Keys.hotKey),
           let decoded = try? JSONDecoder().decode(HotKeyConfig.self, from: data) {
            hotKey = decoded
        } else {
            hotKey = .default
        }

        if defaults.object(forKey: Keys.useClipboardOnOpen) == nil {
            useClipboardOnOpen = true
        } else {
            useClipboardOnOpen = defaults.bool(forKey: Keys.useClipboardOnOpen)
        }

        if defaults.object(forKey: Keys.autoTranslateOnOpen) == nil {
            autoTranslateOnOpen = false
        } else {
            autoTranslateOnOpen = defaults.bool(forKey: Keys.autoTranslateOnOpen)
        }

        if defaults.object(forKey: Keys.clearOnOpen) == nil {
            clearOnOpen = true
        } else {
            clearOnOpen = defaults.bool(forKey: Keys.clearOnOpen)
        }

        if defaults.object(forKey: Keys.autoCopyOnComplete) == nil {
            autoCopyOnComplete = true
        } else {
            autoCopyOnComplete = defaults.bool(forKey: Keys.autoCopyOnComplete)
        }

        if defaults.object(forKey: Keys.smartChineseEnglish) == nil {
            smartChineseEnglish = true
        } else {
            smartChineseEnglish = defaults.bool(forKey: Keys.smartChineseEnglish)
        }

        if let data = defaults.data(forKey: Keys.glossary),
           let decoded = try? JSONDecoder().decode([GlossaryEntry].self, from: data) {
            glossary = decoded
        } else {
            glossary = []
        }

        if let raw = defaults.string(forKey: Keys.translationStyle),
           let style = TranslationStyle(rawValue: raw) {
            translationStyle = style
        } else {
            translationStyle = .general
        }

        if defaults.object(forKey: Keys.editorFontSize) == nil {
            editorFontSize = 14
        } else {
            editorFontSize = defaults.double(forKey: Keys.editorFontSize)
        }

        launchAtLogin = LaunchAtLoginHelper.isEnabled
        launchAtLoginError = nil
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLogin = LaunchAtLoginHelper.isEnabled
    }
}
