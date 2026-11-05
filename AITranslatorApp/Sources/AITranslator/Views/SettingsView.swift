import SwiftUI
import Carbon
import AppKit

struct SettingsView: View {
    var onClose: (() -> Void)? = nil

    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var usageStore = UsageStore.shared
    @State private var selectedTab: SettingsTab = .service
    @State private var recordingField: HotKeyField?
    @State private var showAPIKey = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?
    @State private var newGlossarySource = ""
    @State private var newGlossaryTarget = ""
    @State private var axTrusted = AccessibilityHelper.isTrusted
    @State private var isTestingConnection = false
    @State private var testConnectionResult: (success: Bool, message: String)?

    enum SettingsTab: String, CaseIterable, Identifiable {
        case service = "模型与服务"
        case hotkey = "快捷键"
        case translation = "翻译偏好"
        case glossary = "术语库"
        case general = "通用与统计"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .service: return "cpu"
            case .hotkey: return "keyboard"
            case .translation: return "slider.horizontal.3"
            case .glossary: return "character.book.closed"
            case .general: return "chart.bar.xaxis"
            }
        }
    }

    private enum HotKeyField {
        case toggle, selection, screenshot
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider().background(AppTheme.divider)

            Group {
                switch selectedTab {
                case .service:
                    serviceTab
                case .hotkey:
                    hotkeyTab
                case .translation:
                    translationTab
                case .glossary:
                    glossaryTab
                case .general:
                    generalTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().background(AppTheme.divider)
            footer
        }
        .frame(width: 580, height: 530)
        .background(AppTheme.windowBg)
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

    // MARK: - 顶部选项卡
    private var tabBar: some View {
        HStack(spacing: 12) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? AppTheme.accent : Color.secondary)
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingHand()
                .overlay(alignment: .bottom) {
                    if selectedTab == tab {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(AppTheme.accent)
                            .frame(height: 2.5)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var footer: some View {
        HStack {
            Text("AI 翻译 · 快捷唤起 \(settings.hotKey.displayString)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("完成") {
                stopRecording()
                onClose?()
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    // MARK: - 1. 服务与模型 Tab
    private var serviceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 服务商选择
                cardSection(title: "模型服务商", icon: "server.rack") {
                    Picker("服务商预设", selection: $settings.providerPreset) {
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

                    Text("支持所有兼容 OpenAI 格式的接口（DeepSeek、Kimi、Ollama 本地等）。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 凭据与地址
                cardSection(title: "API 配置", icon: "key.fill") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            if showAPIKey {
                                TextField("sk-…", text: $settings.apiKey)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("sk-…", text: $settings.apiKey)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Button {
                                showAPIKey.toggle()
                            } label: {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                        Text("Key 仅保存在 macOS 原生钥匙串（Keychain），安全防泄露。")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                    }

                    if settings.needsAPIKey {
                        Label("未配置 API Key，翻译前请先填写", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Base URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("https://api.deepseek.com", text: $settings.apiBaseURL)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("模型名称 (Model)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("deepseek-chat", text: $settings.model)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 测试连接按钮
                    HStack(spacing: 8) {
                        Button {
                            testConnection()
                        } label: {
                            HStack(spacing: 4) {
                                if isTestingConnection {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "bolt.horizontal.fill")
                                }
                                Text("测试 API 连通性")
                            }
                        }
                        .disabled(isTestingConnection || settings.needsAPIKey)
                        .controlSize(.small)

                        if let result = testConnectionResult {
                            HStack(spacing: 4) {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.success ? .green : .red)
                                Text(result.message)
                                    .font(.caption)
                                    .foregroundStyle(result.success ? .green : .red)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
        }
    }

    // MARK: - 2. 快捷键 Tab
    private var hotkeyTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                cardSection(title: "全局快捷键", icon: "command") {
                    Text("在任意软件中通过键盘组合键快速唤起相应功能。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    hotKeyRow("唤起主窗口", desc: "快速展开或关闭翻译面板", config: settings.hotKey, field: .toggle, fallback: .default)
                    hotKeyRow("翻译选中文本", desc: "读取当前选中的高亮文本并翻译", config: settings.selectionHotKey, field: .selection, fallback: .defaultSelection)
                    hotKeyRow("截图翻译", desc: "系统选区截屏 OCR 识别后直接翻译", config: settings.screenshotHotKey, field: .screenshot, fallback: .defaultScreenshot)

                    if recordingField != nil {
                        Text("请在键盘上按下你想要的新按键组合，按 Esc 取消录制")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(16)
        }
    }

    private func hotKeyRow(_ title: String, desc: String, config: HotKeyConfig, field: HotKeyField, fallback: HotKeyConfig) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()

            // 物理按键键帽质感
            Text(config.displayString)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(recordingField == field
                              ? Color.red.opacity(0.15)
                              : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(recordingField == field ? Color.red : Color.primary.opacity(0.12), lineWidth: 1)
                )

            Button(recordingField == field ? "录制中…" : "修改") {
                if recordingField == field { stopRecording() } else { startRecording(field) }
            }
            .buttonStyle(.borderedProminent)
            .tint(recordingField == field ? .red : .accentColor)
            .controlSize(.small)

            Button("默认") {
                applyHotKey(fallback, to: field)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 3. 翻译偏好 Tab
    private var translationTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                cardSection(title: "智能互翻与默认语种", icon: "globe") {
                    Toggle(isOn: $settings.smartChineseEnglish) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("中英智能互翻")
                                .font(.system(size: 13, weight: .medium))
                            Text("自动识别输入语种：输入中文翻英文，输入英文翻中文")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    if !settings.smartChineseEnglish {
                        HStack(spacing: 12) {
                            Picker("默认源语言", selection: $settings.sourceLanguage) {
                                ForEach(TranslateLanguage.sourceOptions) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                            Picker("默认目标语言", selection: $settings.targetLanguage) {
                                ForEach(TranslateLanguage.targetOptions) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                        }
                    }
                }

                cardSection(title: "交互与自动化行为", icon: "hand.tap.fill") {
                    Toggle(isOn: $settings.useClipboardOnOpen) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("唤起时自动读取剪贴板")
                            Text("快捷键打开时，自动填入剪贴板文本或截图")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Toggle(isOn: $settings.autoTranslateOnOpen) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("填入剪贴板后立即开翻")
                            Text("无需手动点击翻译或回车")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .disabled(!settings.useClipboardOnOpen)

                    Toggle(isOn: $settings.autoCopyOnComplete) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("翻译完成后自动复制译文")
                            Text("生成完毕后静默写入系统剪贴板")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Toggle("每次打开时清空上次翻译内容", isOn: $settings.clearOnOpen)
                        .toggleStyle(.switch)
                }
            }
            .padding(16)
        }
    }

    // MARK: - 4. 术语库 Tab
    private var glossaryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("自定义术语映射表 (\(settings.glossary.count)条)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("大模型翻译时将严格遵循设定的专有名词译法")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // 添加新条目
            HStack(spacing: 8) {
                TextField("原文术语 (如 Prompt)", text: $newGlossarySource)
                    .textFieldStyle(.roundedBorder)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                TextField("目标译法 (如 提示词)", text: $newGlossaryTarget)
                    .textFieldStyle(.roundedBorder)
                Button("添加条目") {
                    let source = newGlossarySource.trimmingCharacters(in: .whitespacesAndNewlines)
                    let target = newGlossaryTarget.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !source.isEmpty, !target.isEmpty else { return }
                    settings.glossary.append(GlossaryEntry(source: source, target: target))
                    newGlossarySource = ""
                    newGlossaryTarget = ""
                }
                .controlSize(.small)
                .disabled(newGlossarySource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || newGlossaryTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)

            // 术语列表
            if settings.glossary.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "character.book.closed")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("暂无术语对照")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("添加专业名词、公司产品名或专属黑话，AI 翻译时将优先采用")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach($settings.glossary) { $entry in
                            HStack(spacing: 8) {
                                TextField("原文", text: $entry.source)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("译法", text: $entry.target)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                Button {
                                    settings.glossary.removeAll { $0.id == entry.id }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }
        }
    }

    // MARK: - 5. 通用与统计 Tab
    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 用量卡片
                cardSection(title: "用量累计与统计", icon: "chart.pie.fill") {
                    let current = usageStore.currentUsage
                    HStack(spacing: 16) {
                        StatCard(title: "本月翻译字符", value: UsageStore.formatted(current.characterCount), icon: "text.word.spacing")
                        StatCard(title: "本月请求次数", value: UsageStore.formatted(current.requestCount), icon: "network")
                        StatCard(title: "历史累计字符", value: UsageStore.formatted(usageStore.totalCharacters), icon: "sum")
                    }

                    HStack {
                        Spacer()
                        Button("重置统计数据", role: .destructive) {
                            usageStore.reset()
                        }
                        .controlSize(.small)
                    }
                }

                // 系统与显示
                cardSection(title: "系统偏好与外观", icon: "gearshape.2.fill") {
                    Toggle("开机自动启动 AI 翻译", isOn: $settings.launchAtLogin)
                        .toggleStyle(.switch)

                    if let error = settings.launchAtLoginError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("编辑框字体大小")
                                .font(.system(size: 12))
                            Spacer()
                            Text("\(Int(settings.editorFontSize)) pt")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.editorFontSize, in: 12...22, step: 1)
                    }

                    // 权限状态
                    HStack {
                        if axTrusted {
                            Label("系统辅助功能权限已授予（支持选中文字翻译）", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Label("选中文本翻译需要系统辅助功能权限", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Spacer()
                            Button("前往授权") {
                                AccessibilityHelper.requestTrust()
                                AccessibilityHelper.openSettings()
                            }
                            .controlSize(.small)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
        }
    }

    // MARK: - 辅助卡片包装
    private func cardSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    // MARK: - API 连通性测试
    private func testConnection() {
        isTestingConnection = true
        testConnectionResult = nil

        Task { @MainActor in
            do {
                let testTranslator = DeepSeekTranslator.makeDefault()
                _ = try await testTranslator.translateStream(
                    text: "Hi",
                    source: .english,
                    target: .chinese,
                    onUpdate: { _ in }
                )
                isTestingConnection = false
                testConnectionResult = (true, "连接成功！接口返回正常")
            } catch {
                isTestingConnection = false
                testConnectionResult = (false, "连接失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 快捷键录制逻辑
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

// 统计微卡片
private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.controlBg)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

extension Notification.Name {
    static let hotKeyDidChange = Notification.Name("hotKeyDidChange")
}
