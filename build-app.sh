#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="AI翻译"
APP_PATH="${HOME}/Desktop/${APP_NAME}.app"
SRC_DIR="${ROOT_DIR}/AITranslatorApp"
BUILD_BIN="${SRC_DIR}/.build/release/AITranslator"
APP_VERSION="1.0.0"

echo "正在用 Swift/SwiftUI 编译 ${APP_NAME}..."
cd "${SRC_DIR}"
swift build -c release

echo "正在生成 ${APP_PATH} ..."
rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS"
mkdir -p "${APP_PATH}/Contents/Resources"

cp "${BUILD_BIN}" "${APP_PATH}/Contents/MacOS/AITranslator"
chmod +x "${APP_PATH}/Contents/MacOS/AITranslator"

cat > "${APP_PATH}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>local.ai.translator</string>
  <key>CFBundleVersion</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleExecutable</key>
  <string>AITranslator</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSScreenCaptureUsageDescription</key>
  <string>截图翻译需要选取屏幕区域以识别文字。</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

# 桌面图标：使用仓库根目录 logo.png（与 deploy-tools 相同方式生成 icns）
ICON_SRC="${ROOT_DIR}/logo.png"
if [[ ! -f "${ICON_SRC}" ]]; then
  ICON_SRC="${ROOT_DIR}/app-icon.png"
fi
if [[ -f "${ICON_SRC}" ]] && command -v sips >/dev/null && command -v iconutil >/dev/null; then
  ICONSET="${ROOT_DIR}/.build/AppIcon.iconset"
  mkdir -p "${ROOT_DIR}/.build"
  rm -rf "${ICONSET}"
  mkdir -p "${ICONSET}"
  for size in 16 32 128 256 512; do
    sips -z "${size}" "${size}" "${ICON_SRC}" --out "${ICONSET}/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "${ICON_SRC}" --out "${ICONSET}/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "${ICONSET}" -o "${APP_PATH}/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "${APP_PATH}/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile AppIcon' "${APP_PATH}/Contents/Info.plist" 2>/dev/null || true
  echo "已写入应用图标：${ICON_SRC}"
fi

# 清除隔离标记，避免「无法打开 / 已损坏」误报（与 deploy-tools 一致）
xattr -cr "${APP_PATH}" 2>/dev/null || true

# 同步一份到仓库 dist，方便查找
DIST_DIR="${ROOT_DIR}/dist"
mkdir -p "${DIST_DIR}"
rm -rf "${DIST_DIR}/${APP_NAME}.app"
cp -R "${APP_PATH}" "${DIST_DIR}/${APP_NAME}.app"
xattr -cr "${DIST_DIR}/${APP_NAME}.app" 2>/dev/null || true

echo "完成：${APP_PATH}"
echo "副本：${DIST_DIR}/${APP_NAME}.app"
echo "源码：${SRC_DIR}"
echo ""
echo "说明：这是菜单栏应用，启动后看屏幕右上角菜单栏图标（书本图标）。"
echo "默认快捷键 ⌘⇧T 唤起翻译窗口；菜单栏图标 → 设置 可配置 API Key。"
