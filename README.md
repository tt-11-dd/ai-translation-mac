# AI 翻译（macOS）

基于 DeepSeek 大模型的 macOS 菜单栏翻译工具。打包方式与 `deploy-tools` 一致：Swift Package + 手动组装 `.app`。

## 使用

双击桌面「AI翻译.app」→ 看屏幕**右上角菜单栏**。

1. 设置里填写 DeepSeek **API Key / URL / 模型**
2. 复制文本 → 按快捷键（默认 `⌘⇧T`）
3. 点「翻译」或 `⌘↩`

### 常用快捷键

| 快捷键 | 作用 |
|--------|------|
| `⌘⇧T`（可改） | 唤起 / 关闭翻译窗口 |
| `⌘↩` | 执行翻译 |
| `Esc` | 关闭窗口 |

## 主要功能

- **中英智能互翻**：中文→英文，英文→中文
- **译完自动复制**：翻译完成后写入剪贴板
- 流式输出、登录启动、自定义键盘组合快捷键
- 设置以独立弹窗打开，不覆盖翻译窗口

## 重新编译 / 打包

```bash
/Users/code/ai-translation-mac/build-app.sh
```

生成：`~/Desktop/AI翻译.app` 与 `dist/AI翻译.app`

若提示无法打开：右键 → 打开；或 `xattr -cr ~/Desktop/AI翻译.app`

## 文件

| 路径 | 说明 |
|------|------|
| `AITranslatorApp/` | SwiftUI 源码（SPM） |
| `build-app.sh` | 编译并生成桌面 App |
| `logo.png` | 应用图标 |
