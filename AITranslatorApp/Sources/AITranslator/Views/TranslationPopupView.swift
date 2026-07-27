import SwiftUI

struct TranslationPopupView: View {
    @ObservedObject var viewModel: TranslationViewModel
    var onClose: () -> Void

    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if showSettings {
                settingsPane
            } else {
                content
                Divider()
                footer
            }
        }
        .frame(minWidth: 480, minHeight: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .onExitCommand {
            if showSettings {
                showSettings = false
            } else {
                onClose()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openInAppSettings)) { _ in
            showSettings = true
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            if showSettings {
                Button {
                    showSettings = false
                } label: {
                    Label("返回翻译", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)

                Text("设置")
                    .font(.headline)

                Spacer()
            } else {
                if AppSettings.shared.smartChineseEnglish {
                    Text("\(viewModel.sourceLanguage.displayName) → \(viewModel.targetLanguage.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("中英智能互翻")
                } else {
                    Picker("源语言", selection: $viewModel.sourceLanguage) {
                        ForEach(TranslateLanguage.sourceOptions) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 140)

                    Button {
                        viewModel.swapLanguages()
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                    }
                    .buttonStyle(.borderless)
                    .help("交换语言")

                    Picker("目标语言", selection: $viewModel.targetLanguage) {
                        ForEach(TranslateLanguage.targetOptions) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 140)
                }

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("设置")

                Button("翻译") {
                    Task { await viewModel.translate() }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(viewModel.isTranslating || viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("关闭 (Esc)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var settingsPane: some View {
        SettingsView(embedded: true) {
            showSettings = false
        }
    }

    private var content: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 6) {
                Text("原文")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AutohidingTextEditor(text: $viewModel.inputText)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2))
                    )
            }
            .padding(12)

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
                }
                .frame(height: 16)
                AutohidingTextEditor(text: $viewModel.outputText, isEditable: true)
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

    private var footer: some View {
        HStack(spacing: 12) {
            Group {
                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                        .lineLimit(1)
                } else if let status = viewModel.statusMessage, !viewModel.isTranslating {
                    // 翻译中时不在底部显示状态，避免高度跳动（加载在「译文」旁）
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(" ")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("清空") {
                viewModel.clear()
            }
            .disabled(viewModel.inputText.isEmpty && viewModel.outputText.isEmpty)

            Button("复制译文") {
                viewModel.copyResult()
            }
            .disabled(viewModel.outputText.isEmpty)
        }
        .frame(minHeight: 20)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

extension Notification.Name {
    static let openInAppSettings = Notification.Name("openInAppSettings")
}
