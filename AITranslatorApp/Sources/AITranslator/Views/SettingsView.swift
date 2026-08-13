import SwiftUI
import Carbon
import AppKit

struct SettingsView: View {
    var onClose: (() -> Void)? = nil

    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var usageStore = UsageStore.shared
    @State private var recordingField: HotKeyField?
    @State private var showAPIKey = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?
    @State private var newGlossarySource = ""
    @State private var newGlossaryTarget = ""
    @State private var axTrusted = AccessibilityHelper.isTrusted

    private enum HotKeyField {
        case toggle, selection, screenshot
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    serviceBlock
                    hotkeyBlock
                    translateBlock
                    glossaryBlock
                    generalBlock
                    usageBlock
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(width: 520, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            settings.refreshLaunchAtLoginStatus()
            axTrusted = AccessibilityHelper.isTrusted
        }
        .onDisappear { stopRecording() }
        .onExitCommand {
            if recordingField != nil {
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
            Text("唤起 \(settings.hotKey.displayString)  ·  选中 \(settings.selectionHotKey.displayString)  ·  截图 \(settings.screenshotHotKey.displayString)")
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

            if settings.needsAPIKey {
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
        section("快捷键", tip: "录制时先关掉已注册热键，避免按了没反应") {
            hotKeyRow("唤起窗口", config: settings.hotKey, field: .toggle, fallback: .default)
            hotKeyRow("翻译选中", config: settings.selectionHotKey, field: .selection, fallback: .defaultSelection)
            hotKeyRow("截图翻译", config: settings.screenshotHotKey, field: .screenshot, fallback: .defaultScreenshot)

            Text(recordingField != nil
                 ? "请按下任意键或组合键，Esc 取消"
                 : "例如 F8、⌘⇧T、⌥Space")
                .font(.caption)
                .foregroundStyle(recordingField != nil ? .red : .secondary)
        }
    }

    private func hotKeyRow(_ title: String, config: HotKeyConfig, field: HotKeyField, fallback: HotKeyConfig) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(config.displayString)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(recordingField == field
                              ? Color.accentColor.opacity(0.18)
                              : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(recordingField == field ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.18))
                )
            Button(recordingField == field ? "按下…" : "录制") {
                if recordingField == field { stopRecording() } else { startRecording(field) }
            }
            .buttonStyle(.borderedProminent)
            .tint(recordingField == field ? .red : .accentColor)
            .controlSize(.small)
            Button("重置") {
                applyHotKey(fallback, to: field)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var translateBlock: some View {
        section("翻译偏好", tip: "语言策略与打开行为") {
            Toggle(isOn: $settings.smartChineseEnglish) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("中英智能互翻")
                    Text("中文→英文，英文→中文；窗口内可点语言临时改")
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
            Toggle("识别图片后自动翻译", isOn: $settings.autoTranslateOnOpen)
            Toggle("译完自动复制", isOn: $settings.autoCopyOnComplete)
        }
    }

    private var glossaryBlock: some View {
        section("术语表", tip: "指定术语的强制译法，可直接改") {
            if settings.glossary.isEmpty {
                Text("暂无术语。添加后翻译时会优先使用你指定的译法。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach($settings.glossary) { $entry in
                    HStack(spacing: 8) {
                        TextField("原文", text: $entry.source)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Text("→")
                            .foregroundStyle(.secondary)
                        TextField("译法", text: $entry.target)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button {
                            settings.glossary.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
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
        section("通用", tip: "启动、权限与显示") {
            Toggle("登录时启动", isOn: $settings.launchAtLogin)
            if let error = settings.launchAtLoginError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Text("编辑器字号 \(Int(settings.editorFontSize)) pt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $settings.editorFontSize, in: 12...22, step: 1)
            }

            Divider().padding(.vertical, 2)

            if axTrusted {
                Label("已授权辅助功能（翻译选中文本）", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Label("翻译选中文本需要辅助功能权限", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("去授权") {
                        AccessibilityHelper.requestTrust()
                        AccessibilityHelper.openSettings()
                    }
                    .controlSize(.small)
                }
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

    private func applyHotKey(_ config: HotKeyConfig, to field: HotKeyField) {
        switch field {
        case .toggle: settings.hotKey = config
        case .selection: settings.selectionHotKey = config
        case .screenshot: settings.screenshotHotKey = config
        }
        NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
    }

    private func startRecording(_ field: HotKeyField) {
        stopRecording()
        recordingField = field
        HotKeyManager.shared.unregister()

        let applyConfig: (HotKeyConfig) -> Void = { config in
            DispatchQueue.main.async {
                applyHotKey(config, to: field)
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
        recordingField = nil
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
    }
}

extension Notification.Name {
    static let hotKeyDidChange = Notification.Name("hotKeyDidChange")
}
