import SwiftUI
import Carbon
import AppKit

struct SettingsView: View {
    var onClose: (() -> Void)? = nil

    @ObservedObject private var settings = AppSettings.shared
    @State private var isRecordingHotKey = false
    @State private var showAPIKey = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    serviceBlock
                    hotkeyBlock
                    translateBlock
                    generalBlock
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(width: 480, height: 640)
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

    private var footer: some View {
        HStack {
            Text("当前快捷键：\(settings.hotKey.displayString)")
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

    // MARK: - Blocks

    private var serviceBlock: some View {
        section("DeepSeek 服务", tip: "翻译请求使用这里的配置") {
            field("API Key") {
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

            field("API Base URL") {
                TextField("https://api.deepseek.com", text: $settings.apiBaseURL)
                    .textFieldStyle(.roundedBorder)
            }

            field("模型") {
                TextField("deepseek-chat", text: $settings.model)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var hotkeyBlock: some View {
        section("唤起快捷键", tip: "支持单键或组合键，也可录制键盘自定义键") {
            HStack(spacing: 10) {
                Text(settings.hotKey.displayString)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
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
                            .stroke(isRecordingHotKey ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.18))
                    )

                Button(isRecordingHotKey ? "按下…" : "录制") {
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
                 ? "请按下任意键或组合键，Esc 取消"
                 : "例如 F8、⌘⇧T、⌥Space，或你键盘上的自定义键")
                .font(.caption)
                .foregroundStyle(isRecordingHotKey ? .red : .secondary)
        }
    }

    private var translateBlock: some View {
        section("翻译偏好", tip: "语言策略与打开行为") {
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

            Divider().padding(.vertical, 2)

            Toggle("打开时清空上次内容", isOn: $settings.clearOnOpen)
            Toggle("打开时读取剪贴板", isOn: $settings.useClipboardOnOpen)
            Toggle("译完自动复制", isOn: $settings.autoCopyOnComplete)
        }
    }

    private var generalBlock: some View {
        section("通用", tip: "系统启动项") {
            Toggle("登录时启动", isOn: $settings.launchAtLogin)
            if let error = settings.launchAtLoginError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Layout helpers

    private func section<Content: View>(
        _ title: String,
        tip: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(tip)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1))
        )
    }

    private func field<Content: View>(
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

    // MARK: - Hotkey recording

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
