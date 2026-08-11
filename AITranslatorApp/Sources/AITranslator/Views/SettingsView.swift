import SwiftUI
import Carbon
import AppKit

struct SettingsView: View {
    var onClose: (() -> Void)? = nil

    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var usageStore = UsageStore.shared
    @State private var isRecordingHotKey = false
    @State private var showAPIKey = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?
    @State private var newGlossarySource = ""
    @State private var newGlossaryTarget = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 860)
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

    /// 左中右三栏布局
    private var content: some View {
        HStack(alignment: .top, spacing: 14) {
            leftColumn
            middleColumn
            rightColumn
        }
        .padding(16)
    }

    /// 左栏：翻译服务
    private var leftColumn: some View {
        serviceBlock
            .frame(maxWidth: .infinity)
    }

    /// 中栏：快捷键 + 翻译偏好
    private var middleColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            hotkeyBlock
            translateBlock
        }
        .frame(maxWidth: .infinity)
    }

    /// 右栏：术语表 + 通用 + 用量
    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            glossaryBlock
            generalBlock
            usageBlock
        }
        .frame(maxWidth: .infinity)
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
        section("翻译服务", tip: "支持 DeepSeek 等 OpenAI 兼容接口") {
            Picker("服务商", selection: $settings.providerPreset) {
                ForEach(ProviderPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: settings.providerPreset) { _, newValue in
                if newValue != .custom {
                    settings.apiBaseURL = newValue.baseURL
                    settings.model = newValue.defaultModel
                }
            }

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

            if settings.apiKey.isEmpty {
                Label("未配置 API Key，翻译前请先填写", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
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

            Picker("翻译风格", selection: $settings.translationStyle) {
                ForEach(TranslationStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }

            Toggle("打开时清空上次内容", isOn: $settings.clearOnOpen)
            Toggle("打开时读取剪贴板", isOn: $settings.useClipboardOnOpen)
            Toggle("译完自动复制", isOn: $settings.autoCopyOnComplete)
        }
    }

    private var glossaryBlock: some View {
        section("术语表", tip: "指定术语的强制译法，翻译时生效") {
            if settings.glossary.isEmpty {
                Text("暂无术语。添加后翻译时会优先使用你指定的译法。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(settings.glossary) { entry in
                    HStack(spacing: 8) {
                        Text(entry.source)
                            .font(.system(.body, design: .monospaced))
                        Text("→")
                            .foregroundStyle(.secondary)
                        Text(entry.target)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            settings.glossary.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider().padding(.vertical, 2)

            HStack(spacing: 8) {
                TextField("原文术语", text: $newGlossarySource)
                    .textFieldStyle(.roundedBorder)
                TextField("译法", text: $newGlossaryTarget)
                    .textFieldStyle(.roundedBorder)
                Button("添加") {
                    let source = newGlossarySource.trimmingCharacters(in: .whitespacesAndNewlines)
                    let target = newGlossaryTarget.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !source.isEmpty, !target.isEmpty else { return }
                    settings.glossary.append(GlossaryEntry(source: source, target: target))
                    newGlossarySource = ""
                    newGlossaryTarget = ""
                }
                .disabled(newGlossarySource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || newGlossaryTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var usageBlock: some View {
        section("用量统计", tip: "本地记录，仅用于参考 API 消耗") {
            let current = usageStore.currentUsage
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(UsageStore.formatted(current.characterCount))
                        .font(.title3.weight(.semibold))
                    Text("本月字符")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(UsageStore.formatted(current.requestCount))
                        .font(.title3.weight(.semibold))
                    Text("本月请求")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(UsageStore.formatted(usageStore.totalCharacters))
                        .font(.title3.weight(.semibold))
                    Text("累计字符")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)

            Button("重置统计", role: .destructive) {
                usageStore.reset()
            }
            .controlSize(.small)
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
