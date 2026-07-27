import SwiftUI
import Carbon
import AppKit

private enum SettingsSection: String, CaseIterable, Identifiable {
    case service = "服务"
    case hotkey = "快捷键"
    case translate = "翻译"
    case general = "通用"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .service: return "cloud.fill"
        case .hotkey: return "keyboard"
        case .translate: return "character.book.closed.fill"
        case .general: return "gearshape.fill"
        }
    }
}

struct SettingsView: View {
    var onClose: (() -> Void)? = nil

    @ObservedObject private var settings = AppSettings.shared
    @State private var section: SettingsSection = .service
    @State private var isRecordingHotKey = false
    @State private var showAPIKey = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                sidebar
                Divider()
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            footer
        }
        .frame(width: 520, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { settings.refreshLaunchAtLoginStatus() }
        .onDisappear { stopRecording() }
        .onExitCommand {
            if isRecordingHotKey {
                stopRecording()
            } else {
                onClose?()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("设置")
                    .font(.headline)
                Text("API、快捷键与翻译偏好")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsSection.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        section = item
                    }
                    if item != .hotkey { stopRecording() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                            .frame(width: 16)
                        Text(item.rawValue)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(section == item ? Color.accentColor.opacity(0.15) : Color.clear)
                    )
                    .foregroundStyle(section == item ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 140)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch section {
                case .service:
                    serviceSection
                case .hotkey:
                    hotkeySection
                case .translate:
                    translateSection
                case .general:
                    generalSection
                }
            }
            .padding(20)
        }
    }

    private var footer: some View {
        HStack {
            Text(sectionHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button("完成") {
                stopRecording()
                onClose?()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var sectionHint: String {
        switch section {
        case .service: return "翻译请求使用这里的 Key / URL / 模型"
        case .hotkey: return "当前：\(settings.hotKey.displayString)"
        case .translate: return settings.smartChineseEnglish ? "中英智能互翻已开启" : "使用手动语言"
        case .general: return "登录项与窗口行为"
        }
    }

    // MARK: - Sections

    private var serviceSection: some View {
        settingsCard(title: "DeepSeek 服务", subtitle: "接口凭证与模型") {
            labeledField("API Key") {
                HStack(spacing: 8) {
                    Group {
                        if showAPIKey {
                            TextField("sk-…", text: $settings.apiKey)
                        } else {
                            SecureField("sk-…", text: $settings.apiKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)

                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
            }

            labeledField("API Base URL") {
                TextField("https://api.deepseek.com", text: $settings.apiBaseURL)
                    .textFieldStyle(.roundedBorder)
            }

            labeledField("模型") {
                TextField("deepseek-chat", text: $settings.model)
                    .textFieldStyle(.roundedBorder)
            }

            Text("也可填写 deepseek-reasoner 等兼容模型名")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var hotkeySection: some View {
        settingsCard(title: "唤起快捷键", subtitle: "需包含至少一个修饰键（⌘ ⌥ ⇧ ⌃）") {
            HStack(spacing: 12) {
                Text(settings.hotKey.displayString)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isRecordingHotKey
                                  ? Color.accentColor.opacity(0.18)
                                  : Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isRecordingHotKey ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2))
                    )

                Button(isRecordingHotKey ? "按下组合键…" : "录制") {
                    if isRecordingHotKey { stopRecording() } else { startRecording() }
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecordingHotKey ? .red : .accentColor)

                Button("重置") {
                    settings.hotKey = .default
                    NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
                }
                .buttonStyle(.bordered)
            }

            Text(isRecordingHotKey
                 ? "请按下新的组合键，Esc 取消"
                 : "例如 ⌘⇧T、⌥Space、⌃⌥T")
                .font(.caption)
                .foregroundStyle(isRecordingHotKey ? .red : .secondary)
        }
    }

    private var translateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard(title: "语言策略", subtitle: "决定如何选择源语言与目标语言") {
                Toggle(isOn: $settings.smartChineseEnglish) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("中英智能互翻")
                        Text("中文→英文，英文→中文")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                if !settings.smartChineseEnglish {
                    Divider()
                    Picker("源语言", selection: $settings.sourceLanguage) {
                        ForEach(TranslateLanguage.sourceOptions) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    Picker("目标语言", selection: $settings.targetLanguage) {
                        ForEach(TranslateLanguage.targetOptions) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                }
            }

            settingsCard(title: "打开与结果", subtitle: "窗口唤起后的默认行为") {
                Toggle("打开时清空上次内容", isOn: $settings.clearOnOpen)
                Toggle("打开时读取剪贴板", isOn: $settings.useClipboardOnOpen)
                Toggle("译完自动复制", isOn: $settings.autoCopyOnComplete)

                Text("剪贴板仅填入原文，需手动点击翻译")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var generalSection: some View {
        settingsCard(title: "通用", subtitle: "系统与启动") {
            Toggle("登录时启动", isOn: $settings.launchAtLogin)
            if let error = settings.launchAtLoginError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Text("开启后随 macOS 登录自动在后台运行")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func settingsCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.12))
        )
    }

    private func labeledField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecordingHotKey = true

        let applyConfig: (HotKeyConfig) -> Void = { config in
            DispatchQueue.main.async {
                settings.hotKey = config
                NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
                stopRecording()
            }
        }

        let keyHandle: (NSEvent) -> NSEvent? = { event in
            if event.keyCode == UInt16(kVK_Escape) {
                DispatchQueue.main.async { stopRecording() }
                return nil
            }
            if let config = HotKeyConfig.fromKeyEvent(event) {
                applyConfig(config)
                return nil
            }
            return event
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: keyHandle)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            _ = keyHandle(event)
        }
    }

    private func stopRecording() {
        isRecordingHotKey = false
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }
}

extension Notification.Name {
    static let hotKeyDidChange = Notification.Name("hotKeyDidChange")
}
