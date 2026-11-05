import SwiftUI
import AppKit

struct TranslationPopupView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @ObservedObject private var historyStore = HistoryStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var panelController = TranslationPanelController.shared
    @AppStorage("translationShowHistory") private var showHistory = false
    @State private var historyQuery = ""
    @State private var hasCopied = false
    @State private var swapRotation: Double = 0
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部操作栏 (全局控制 + 明确的关闭按钮)
            unifiedToolbar
            Divider().background(AppTheme.divider)

            if settings.needsAPIKey {
                setupPane
            } else {
                // 2. 模式与风格工具栏 (整齐居中，全热区点击)
                modeAndStyleBar
                Divider().background(AppTheme.divider)

                // 3. 左右完全对称的主卡片内容区
                mainContent
            }

            // 4. 底部状态与快捷键脚标
            Divider().background(AppTheme.divider)
            unifiedFooter
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(AppTheme.windowBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .onExitCommand { onClose() }
    }

    // MARK: - 1. 顶部主工具栏 (高度统一 28pt，增加右上角关闭按钮)
    private var unifiedToolbar: some View {
        HStack(spacing: 8) {
            // 品牌微标与在线状态点
            brandBadge

            // 语言对选择岛
            languageControlIsland

            Spacer(minLength: 8)

            // 窗口置顶图钉
            ToolbarIconButton(
                systemImage: panelController.isPinned ? "pin.fill" : "pin",
                tooltip: panelController.isPinned ? "取消置顶" : "置顶窗口（失焦不收起）",
                isActive: panelController.isPinned
            ) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    panelController.togglePin()
                }
            }

            // 历史记录抽屉
            ToolbarIconButton(
                systemImage: showHistory ? "clock.fill" : "clock",
                tooltip: "翻译历史 (最近50条)",
                isActive: showHistory
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showHistory.toggle()
                }
            }

            // 设置
            ToolbarIconButton(
                systemImage: "gearshape",
                tooltip: "偏好设置与快捷键",
                isActive: false
            ) {
                SettingsWindowController.shared.show()
            }

            // 主翻译/停止按钮
            actionTranslateButton

            // 窗口关闭按钮 (高可见性、全点击热区)
            ToolbarIconButton(
                systemImage: "xmark",
                tooltip: "关闭窗口 (Esc)",
                isActive: false,
                isDestructive: true
            ) {
                onClose()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - 品牌微标与状态点
    private var brandBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "character.bubble.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.accent)
            Text("AI翻译")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)

            Circle()
                .fill(settings.needsAPIKey ? Color.orange : Color.green)
                .frame(width: 5.5, height: 5.5)
                .help(settings.needsAPIKey ? "未填写 API Key" : "服务正常就绪")
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(AppTheme.controlBg)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    // MARK: - 语言选择岛
    @ViewBuilder
    private var languageControlIsland: some View {
        if settings.smartChineseEnglish && !viewModel.smartOverride {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    viewModel.smartOverride = true
                }
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.sourceLanguage.displayName)
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                    Text(viewModel.targetLanguage.displayName)
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(AppTheme.controlBg)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .pointingHand()
            .help("中英智能互翻模式，点击可自由选择语言")
        } else {
            HStack(spacing: 2) {
                // 源语言
                Menu {
                    ForEach(TranslateLanguage.sourceOptions) { lang in
                        Button(lang.displayName) {
                            viewModel.sourceLanguage = lang
                            viewModel.smartOverride = true
                        }
                    }
                } label: {
                    Text(viewModel.sourceLanguage.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .pointingHand()

                // 交换按钮
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        swapRotation += 180
                        viewModel.swapLanguages()
                    }
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .rotationEffect(.degrees(swapRotation))
                        .frame(width: 24, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingHand()
                .help("对调语言")

                // 目标语言
                Menu {
                    ForEach(TranslateLanguage.targetOptions) { lang in
                        Button(lang.displayName) {
                            viewModel.targetLanguage = lang
                            viewModel.smartOverride = true
                        }
                    }
                } label: {
                    Text(viewModel.targetLanguage.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .pointingHand()
            }
            .background(AppTheme.controlBg)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
    }

    // MARK: - 主翻译操作按钮
    @ViewBuilder
    private var actionTranslateButton: some View {
        if viewModel.isTranslating {
            Button {
                viewModel.cancelTranslating()
            } label: {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.65)
                        .frame(width: 14, height: 14)
                    Text("停止")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color.red.opacity(0.15))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .pointingHand()
            .help("取消当前生成")
        } else {
            let disabled = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button {
                Task { await viewModel.translate() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .bold))
                    Text("翻译")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(
                    disabled
                        ? AnyShapeStyle(AppTheme.controlBg)
                        : AnyShapeStyle(AppTheme.accentGradient)
                )
                .foregroundStyle(disabled ? Color.secondary.opacity(0.6) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(disabled ? AppTheme.border : Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(
                    color: disabled ? .clear : AppTheme.accent.opacity(0.3),
                    radius: 4,
                    x: 0,
                    y: 1.5
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(disabled)
            .pointingHand()
            .help("执行翻译 (⌘↩)")
        }
    }

    // MARK: - 2. 模式与风格工具栏 (全热区点击，点按钮任意位置均有效)
    private var modeAndStyleBar: some View {
        HStack(spacing: 6) {
            // AI 模式分段控制胶囊
            HStack(spacing: 3) {
                ForEach(TaskMode.allCases) { mode in
                    Button {
                        Task { await viewModel.execute(mode: mode) }
                    } label: {
                        HStack(spacing: 3.5) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 9))
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: viewModel.currentMode == mode ? .bold : .medium))

                            // 若是单词且为词典模式，展示轻量推荐小圆点
                            if mode == .dictionary && viewModel.isSingleWord {
                                Circle()
                                    .fill(AppTheme.accent)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(
                            viewModel.currentMode == mode
                                ? AppTheme.accent.opacity(0.18)
                                : Color.clear
                        )
                        .foregroundStyle(viewModel.currentMode == mode ? AppTheme.accent : Color.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .contentShape(Rectangle()) // 全面积热区点击！
                    }
                    .buttonStyle(.plain)
                    .pointingHand()
                    .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && mode != .translate)
                    .help(mode.tip)
                }
            }
            .padding(2)
            .background(AppTheme.controlBg)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )

            Spacer()

            // 翻译风格选择器 (通用/正式/口语/学术等)
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
                    Image(systemName: "sparkles")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.purple)
                    Text("风格: \(settings.translationStyle.displayName)")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(AppTheme.controlBg)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentShape(Rectangle())
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .pointingHand()
            .help("选择语气风格")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(AppTheme.sidebarBg.opacity(0.4))
    }

    // MARK: - 3. 左右完全对称的主卡片内容区
    private var mainContent: some View {
        HStack(spacing: 0) {
            if showHistory {
                unifiedHistorySidebar
                    .transition(.move(edge: .leading).combined(with: .opacity))
                Divider().background(AppTheme.divider)
            }

            HSplitView {
                // 原文卡片
                sourceCard
                    .padding(12)

                // 译文卡片
                targetCard
                    .padding(12)
            }
        }
    }

    // MARK: - 原文卡片 (使用内部精确对齐原生占位符，彻底消除光标错位)
    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片头部 (固定高度 30pt)
            HStack {
                HStack(spacing: 5) {
                    Text("原文")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("· \(viewModel.sourceLanguage.displayName)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 工具按钮组
                HStack(spacing: 6) {
                    if viewModel.inputText.isEmpty {
                        Button {
                            if let clip = NSPasteboard.general.string(forType: .string), !clip.isEmpty {
                                viewModel.inputText = clip
                                viewModel.applySmartLanguagesIfNeeded()
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 9.5))
                                Text("粘贴剪贴板")
                                    .font(.system(size: 10.5))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .frame(height: 20)
                            .background(AppTheme.controlBg)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointingHand()
                    } else {
                        Button {
                            withAnimation { viewModel.inputText = "" }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary.opacity(0.7))
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointingHand()
                        .help("清空原文")
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(AppTheme.controlBg.opacity(0.4))

            Divider().background(AppTheme.divider)

            // 原文文本编辑器：由 NSTextView 绘制原生占位符，光标与文字零错位
            AutohidingTextEditor(
                text: $viewModel.inputText,
                placeholder: "在此输入或粘贴文本，按回车 ↵ 执行，Shift+回车换行…",
                fontSize: CGFloat(settings.editorFontSize),
                focusID: "input",
                onEnter: {
                    Task { await viewModel.translate() }
                },
                onTab: {
                    EditorFocusCoordinator.shared.focus(id: "output")
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().background(AppTheme.divider)

            // 卡片底部字数栏 (固定高度 24pt)
            HStack {
                Spacer()
                Text(viewModel.inputText.isEmpty ? "0 字符" : "\(viewModel.inputText.count) 字符")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(AppTheme.controlBg.opacity(0.2))
        }
        .background(AppTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    // MARK: - 译文卡片 (使用内部精确对齐原生占位符，彻底消除光标错位)
    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片头部 (固定高度 30pt)
            HStack {
                HStack(spacing: 5) {
                    Text(viewModel.currentMode == .translate ? "译文" : viewModel.currentMode.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("· \(viewModel.targetLanguage.displayName)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if viewModel.isTranslating {
                        HStack(spacing: 2) {
                            Circle().fill(AppTheme.accent).frame(width: 4, height: 4)
                            Circle().fill(AppTheme.accent.opacity(0.6)).frame(width: 4, height: 4)
                            Circle().fill(AppTheme.accent.opacity(0.3)).frame(width: 4, height: 4)
                        }
                    }
                }

                Spacer()

                // 操作岛 (朗读、复制)
                HStack(spacing: 5) {
                    if !viewModel.outputText.isEmpty {
                        // 语音朗读
                        Button {
                            viewModel.toggleSpeakResult()
                        } label: {
                            Image(systemName: viewModel.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .font(.system(size: 11))
                                .foregroundStyle(viewModel.isSpeaking ? AppTheme.accent : Color.secondary)
                                .frame(width: 22, height: 20)
                                .background(AppTheme.controlBg)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointingHand()
                        .help("朗读文本")

                        // 一键快捷复制 (带动画反馈)
                        Button {
                            viewModel.copyResult()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                hasCopied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { hasCopied = false }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 10, weight: hasCopied ? .bold : .regular))
                                    .foregroundStyle(hasCopied ? Color.green : Color.secondary)
                                if hasCopied {
                                    Text("已复制")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color.green)
                                }
                            }
                            .padding(.horizontal, hasCopied ? 6 : 5)
                            .frame(height: 20)
                            .background(hasCopied ? Color.green.opacity(0.15) : AppTheme.controlBg)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointingHand()
                        .help("复制文本")
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(AppTheme.controlBg.opacity(0.4))

            Divider().background(AppTheme.divider)

            // 译文卡片主体：有错误时显示错误条，正常时显示 NSTextView 内置原生占位符
            ZStack(alignment: .topLeading) {
                if let error = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("请求异常")
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Button("重试") {
                            Task { await viewModel.translate() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .pointingHand()
                    }
                    .padding(14)
                } else {
                    let placeholderText: String = {
                        switch viewModel.currentMode {
                        case .translate: return "译文结果将在此呈现…"
                        case .polish: return "母语级地道润色结果将在此呈现…"
                        case .grammar: return "语法排查与纠错建议将在此呈现…"
                        case .dictionary: return "包含音标、释义、搭配与例句的词典卡片将在此呈现…"
                        case .academic: return "学术论文级严谨改写结果将在此呈现…"
                        }
                    }()

                    AutohidingTextEditor(
                        text: $viewModel.outputText,
                        placeholder: placeholderText,
                        isEditable: true,
                        fontSize: CGFloat(settings.editorFontSize),
                        focusID: "output",
                        onTab: {
                            EditorFocusCoordinator.shared.focus(id: "input")
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().background(AppTheme.divider)

            // 卡片底部字数栏 (固定高度 24pt)
            HStack {
                Spacer()
                Text(viewModel.outputText.isEmpty ? "0 字符" : "\(viewModel.outputText.count) 字符")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(AppTheme.controlBg.opacity(0.2))
        }
        .background(AppTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    // MARK: - 统一实体历史抽屉
    private var filteredHistory: [HistoryItem] {
        let q = historyQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return historyStore.items }
        return historyStore.items.filter {
            $0.source.localizedCaseInsensitiveContains(q)
                || $0.target.localizedCaseInsensitiveContains(q)
        }
    }

    private var unifiedHistorySidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("翻译历史")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                if !historyStore.items.isEmpty {
                    Button {
                        historyStore.clear()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .pointingHand()
                    .help("清空历史记录")
                }
            }
            .padding(.horizontal, 4)

            // 搜索框
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("搜索历史...", text: $historyQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                if !historyQuery.isEmpty {
                    Button {
                        historyQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(AppTheme.controlBg)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )

            if filteredHistory.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                    Text(historyStore.items.isEmpty ? "暂无翻译历史" : "无匹配条目")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(filteredHistory) { item in
                            SolidHistoryItemRow(item: item) {
                                if NSEvent.modifierFlags.contains(.option) {
                                    TranslationPanelController.shared.restoreFromHistoryAndTranslate(item)
                                } else {
                                    TranslationPanelController.shared.restoreFromHistory(item)
                                }
                            } onDelete: {
                                historyStore.remove(item)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(10)
        .frame(width: 220)
        .background(AppTheme.sidebarBg)
    }

    // MARK: - 4. 统一底部状态与快捷键脚标
    private var unifiedFooter: some View {
        HStack(spacing: 12) {
            // 左侧状态指示
            HStack(spacing: 6) {
                if viewModel.isTranslating {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.6)
                            .frame(width: 10, height: 10)
                        Text("大模型生成中…")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                } else if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 9.5))
                            .foregroundStyle(AppTheme.accent)
                        Text("\(settings.providerPreset.displayName) · \(settings.model)")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 右侧按键脚标 (KBD Pills)
            HStack(spacing: 6) {
                KbdPill(key: "⌘↩", desc: "执行")
                KbdPill(key: "⇧↩", desc: "换行")
                KbdPill(key: "Tab", desc: "换栏")
                KbdPill(key: "Esc", desc: "关闭")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - API Key 引导面板
    private var setupPane: some View {
        VStack(spacing: 18) {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.accent)
                Text("欢迎使用 AI 翻译")
                    .font(.title3.weight(.bold))
                Text("请填写 OpenAI 兼容 API Key（如 DeepSeek、Kimi 等）开始体验")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
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
                    Text("存入 macOS 钥匙串，无需担心泄露")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("打开完整偏好设置") {
                        SettingsWindowController.shared.show()
                    }
                    .font(.system(size: 11))
                }
            }
            .padding(18)
            .background(AppTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .frame(maxWidth: 380)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

// MARK: - 辅助组件

/// 顶部图标按钮 (高度统一 28pt，全热区点击支持，支持破坏性红色悬浮)
private struct ToolbarIconButton: View {
    let systemImage: String
    let tooltip: String
    let isActive: Bool
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: isActive ? .bold : .semibold))
                .foregroundStyle(isDestructive ? Color.red.opacity(0.85) : (isActive ? AppTheme.accent : Color.secondary))
                .frame(width: 28, height: 28)
                .background(
                    isDestructive
                        ? Color.red.opacity(0.12)
                        : (isActive ? AppTheme.accent.opacity(0.15) : AppTheme.controlBg)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle()) // 整个 28x28 像素完全可点！
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(
                            isDestructive ? Color.red.opacity(0.3) : (isActive ? AppTheme.accent.opacity(0.3) : AppTheme.border),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .pointingHand()
        .help(tooltip)
    }
}

/// 底部实体按键胶囊 (KBD Pill)
private struct KbdPill: View {
    let key: String
    let desc: String

    var body: some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .padding(.horizontal, 4.5)
                .padding(.vertical, 1.5)
                .background(AppTheme.controlBg)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 0.8)
                )
            Text(desc)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}

/// 历史卡片条目 (纯实色)
private struct SolidHistoryItemRow: View {
    let item: HistoryItem
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(languageBadge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                    Spacer()
                    Text(timeAgoString(from: item.timestamp))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Text(item.source)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)

                Text(item.target)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? AppTheme.controlHoverBg : AppTheme.cardBg)
            )
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isHovered ? AppTheme.accent.opacity(0.3) : AppTheme.border, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .pointingHand()
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("回填到输入框") { onSelect() }
            Divider()
            Button("复制译文") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.target, forType: .string)
            }
            Button("复制原文") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.source, forType: .string)
            }
            Divider()
            Button("删除本条", role: .destructive) { onDelete() }
        }
    }

    private var languageBadge: String {
        let src = TranslateLanguage.fromStored(item.sourceLanguage)?.displayName ?? item.sourceLanguage
        let tgt = TranslateLanguage.fromStored(item.targetLanguage)?.displayName ?? item.targetLanguage
        return "\(src) → \(tgt)"
    }

    private func timeAgoString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(seconds / 60)m前" }
        if seconds < 86400 { return "\(seconds / 3600)h前" }
        return "\(seconds / 86400)d前"
    }
}
