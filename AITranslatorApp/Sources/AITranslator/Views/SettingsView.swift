import SwiftUI
import Carbon
import AppKit

struct SettingsView: View {
    var embedded: Bool = false
    var onClose: (() -> Void)? = nil

    @ObservedObject private var settings = AppSettings.shared
    @State private var isRecordingHotKey = false
    @State private var showAPIKey = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?
    @State private var localMouseMonitor: Any?
    @State private var globalMouseMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("DeepSeek") {
                    HStack {
                        if showAPIKey {
                            TextField("API Key", text: $settings.apiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("API Key", text: $settings.apiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button {
                            showAPIKey.toggle()
                        } label: {
                            Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .help(showAPIKey ? "隐藏" : "显示")
                    }

                    TextField("API Base URL", text: $settings.apiBaseURL)
                        .textFieldStyle(.roundedBorder)

                    TextField("模型", text: $settings.model)
                        .textFieldStyle(.roundedBorder)
                    Text("在设置中填写 Key / URL / 模型，翻译时会使用这里的配置")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("快捷键") {
                    HStack {
                        Text("唤起翻译窗口")
                        Spacer()
                        Text(settings.hotKey.displayString)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isRecordingHotKey
                                          ? Color.accentColor.opacity(0.2)
                                          : Color(nsColor: .controlBackgroundColor))
                            )

                        Button(isRecordingHotKey ? "按下…" : "录制") {
                            if isRecordingHotKey {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        }
                        .foregroundStyle(isRecordingHotKey ? .red : .primary)

                        Button("中键") {
                            settings.hotKey = .mouseMiddle
                            if !AccessibilityHelper.isTrusted {
                                AccessibilityHelper.requestTrust()
                            }
                            NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
                        }
                        .help("设为鼠标中键唤醒")

                        Button("重置") {
                            settings.hotKey = .default
                            NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
                        }
                    }

                    Text(isRecordingHotKey
                         ? "请按下单键 / 组合键，或点击鼠标中键；Esc 取消"
                         : "支持单键、组合键、鼠标中键（可带 ⌘⌥⇧⌃）")
                        .font(.caption)
                        .foregroundStyle(isRecordingHotKey ? .red : .secondary)

                    if settings.hotKey.kind == .mouseMiddle && !AccessibilityHelper.isTrusted {
                        HStack {
                            Text("鼠标中键需要「辅助功能」权限")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Button("去开启") {
                                AccessibilityHelper.openSettings()
                            }
                            .font(.caption)
                        }
                    }
                }

                Section("默认语言") {
                    Toggle("中英智能互翻", isOn: $settings.smartChineseEnglish)
                    Text(settings.smartChineseEnglish
                         ? "按原文自动识别：中文→英文，英文→中文"
                         : "使用下方手动选择的语言")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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
                }

                Section("行为") {
                    Toggle("登录时启动", isOn: $settings.launchAtLogin)
                    if let error = settings.launchAtLoginError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Toggle("打开时清空上次内容", isOn: $settings.clearOnOpen)
                    Text(settings.clearOnOpen ? "每次打开窗口会清空原文和译文" : "保留上次翻译内容")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("打开时读取划词", isOn: $settings.useSelectionOnOpen)
                    Text("优先抓取当前选中文本（需辅助功能权限）")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if settings.useSelectionOnOpen && !AccessibilityHelper.isTrusted {
                        HStack {
                            Text("划词需要「辅助功能」权限")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Button("去开启") {
                                AccessibilityHelper.openSettings()
                            }
                            .font(.caption)
                        }
                    }

                    Toggle("打开时读取剪贴板", isOn: $settings.useClipboardOnOpen)
                    Text("无划词时再使用剪贴板；仅填入原文，需手动点「翻译」")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("译完自动复制", isOn: $settings.autoCopyOnComplete)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Text("当前快捷键：\(settings.hotKey.displayString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(embedded ? "返回翻译" : "完成") {
                    stopRecording()
                    onClose?()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            settings.refreshLaunchAtLoginStatus()
        }
        .onDisappear {
            stopRecording()
        }
        .onExitCommand {
            if isRecordingHotKey {
                stopRecording()
            } else {
                onClose?()
            }
        }
    }

    private func startRecording() {
        stopRecording()
        isRecordingHotKey = true

        // 鼠标中键录制时也需要辅助功能（全局）
        if !AccessibilityHelper.isTrusted {
            AccessibilityHelper.requestTrust()
        }

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

        let mouseHandle: (NSEvent) -> Void = { event in
            if let config = HotKeyConfig.fromMouseEvent(event) {
                applyConfig(config)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: keyHandle)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            _ = keyHandle(event)
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { event in
            mouseHandle(event)
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { event in
            mouseHandle(event)
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
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }
}

extension Notification.Name {
    static let hotKeyDidChange = Notification.Name("hotKeyDidChange")
}
