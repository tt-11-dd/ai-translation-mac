import SwiftUI

struct TranslationPopupView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @ObservedObject private var historyStore = HistoryStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @AppStorage("translationShowHistory") private var showHistory = false
    @State private var historyQuery = ""
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if settings.needsAPIKey {
                setupPane
            } else {
                content
            }
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 440)
        .background(Color(nsColor: .windowBackgroundColor))
        .onExitCommand { onClose() }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            languageControls

            Menu {
                ForEach(TranslationStyle.allCases) { style in
                    Button {
                        settings.translationStyle = style
                    } label: {
                        if settings.translationStyle == style {
                            Label(style.displayName, systemImage: "checkmark")
                        } else {
                            Text(style.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "textformat")
                        .font(.caption)
                    Text(settings.translationStyle.displayName)
                        .font(.caption)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .pointingHand()
            .help("翻译风格")

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showHistory.toggle()
                }
            } label: {
                Image(systemName: showHistory ? "clock.fill" : "clock")
            }
            .buttonStyle(.borderless)
            .pointingHand()
            .help("翻译历史")

            Button {
                SettingsWindowController.shared.show()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .pointingHand()
            .help("设置")

            if viewModel.isTranslating {
                Button("取消") {
                    viewModel.cancelTranslating()
                }
                .pointingHand()
                .help("取消当前翻译")
            } else {
                Button("翻译") {
                    Task { await viewModel.translate() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .pointingHand()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var languageControls: some View {
        if settings.smartChineseEnglish && !viewModel.smartOverride {
            Button {
                viewModel.smartOverride = true
            } label: {
                HStack(spacing: 4) {
                    Text("\(viewModel.sourceLanguage.displayName) → \(viewModel.targetLanguage.displayName)")
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .pointingHand()
            .help("点击后可改语言")
        } else {
            Picker("源语言", selection: $viewModel.sourceLanguage) {
                ForEach(TranslateLanguage.sourceOptions) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 140)
            .onChange(of: viewModel.sourceLanguage) { _, _ in
                viewModel.smartOverride = true
            }

            Button {
                viewModel.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.borderless)
            .pointingHand()
            .help("交换语言")

            Picker("目标语言", selection: $viewModel.targetLanguage) {
                ForEach(TranslateLanguage.targetOptions) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 140)
            .onChange(of: viewModel.targetLanguage) { _, _ in
                viewModel.smartOverride = true
            }
        }
    }

    private var setupPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("填写 API Key 开始使用")
                .font(.headline)
            Text("Key 只存在钥匙串，不会明文落盘。Ollama 本地可直接在设置里切换，无需 Key。")
                .font(.caption)
                .foregroundStyle(.secondary)

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

            SecureField("sk-…", text: $settings.apiKey)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("打开完整设置") {
                    SettingsWindowController.shared.show()
                }
                Spacer()
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var content: some View {
        HStack(spacing: 0) {
            if showHistory {
                historySidebar
                Divider()
            }

            HSplitView {
                editorColumn(title: "原文", text: $viewModel.inputText, focusID: "input", onEnter: {
                    Task { await viewModel.translate() }
                }, onTab: {
                    EditorFocusCoordinator.shared.focus(id: "output")
                })

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("译文")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                            .opacity(viewModel.isTranslating ? 1 : 0)
                            .frame(width: 14, height: 14)
                        Spacer(minLength: 0)

                        if !viewModel.outputText.isEmpty {
                            Button {
                                viewModel.toggleSpeakResult()
                            } label: {
                                Image(systemName: viewModel.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                            }
                            .buttonStyle(.borderless)
                            .pointingHand()
                            .help("朗读译文")
                        }
                    }
                    .frame(height: 16)
                    AutohidingTextEditor(
                        text: $viewModel.outputText,
                        isEditable: true,
                        fontSize: CGFloat(settings.editorFontSize),
                        focusID: "output",
                        onTab: { EditorFocusCoordinator.shared.focus(id: "input") }
                    )
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2))
                    )
                }
                .padding(12)
            }
        }
    }

    private func editorColumn(
        title: String,
        text: Binding<String>,
        focusID: String,
        onEnter: (() -> Void)?,
        onTab: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            AutohidingTextEditor(
                text: text,
                fontSize: CGFloat(settings.editorFontSize),
                focusID: focusID,
                onEnter: onEnter,
                onTab: onTab
            )
            .padding(4)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2))
            )
        }
        .padding(12)
    }

    private var filteredHistory: [HistoryItem] {
        let q = historyQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return historyStore.items }
        return historyStore.items.filter {
            $0.source.localizedCaseInsensitiveContains(q)
                || $0.target.localizedCaseInsensitiveContains(q)
        }
    }

    private var historySidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("历史")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !historyStore.items.isEmpty {
                    Button {
                        historyStore.clear()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .pointingHand()
                    .help("清空历史")
                }
            }
            .padding(.horizontal, 4)

            TextField("搜索", text: $historyQuery)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            if filteredHistory.isEmpty {
                Spacer()
                Text(historyStore.items.isEmpty ? "暂无历史记录" : "无匹配结果")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(filteredHistory) { item in
                            Button {
                                if NSEvent.modifierFlags.contains(.option) {
                                    TranslationPanelController.shared.restoreFromHistoryAndTranslate(item)
                                } else {
                                    TranslationPanelController.shared.restoreFromHistory(item)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.source)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .foregroundStyle(.primary)
                                    Text(item.target)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                                )
                            }
                            .buttonStyle(.plain)
                            .pointingHand()
                            .contextMenu {
                                Button("回填") {
                                    TranslationPanelController.shared.restoreFromHistory(item)
                                }
                                Button("回填并翻译") {
                                    TranslationPanelController.shared.restoreFromHistoryAndTranslate(item)
                                }
                                Divider()
                                Button("删除") {
                                    historyStore.remove(item)
                                }
                                Button("清空历史", role: .destructive) {
                                    historyStore.clear()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(10)
        .frame(width: 220)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Group {
                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                        .lineLimit(2)
                        .help(error)
                } else if viewModel.isTranslating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在翻译…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                } else if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("\(viewModel.inputText.count) → \(viewModel.outputText.count) 字")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.errorMessage != nil {
                Button("重试") {
                    Task { await viewModel.translate() }
                }
                .pointingHand()
            }

            Button("清空") {
                viewModel.clear()
            }
            .disabled(viewModel.inputText.isEmpty && viewModel.outputText.isEmpty)
            .pointingHand()

            Button("复制译文") {
                viewModel.copyResult()
            }
            .disabled(viewModel.outputText.isEmpty)
            .pointingHand()
        }
        .frame(minHeight: 20)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
