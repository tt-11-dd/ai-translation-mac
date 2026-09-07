#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="AI翻译"
APP_FILE_NAME="AI-Translator"
APP_PATH="${HOME}/Desktop/${APP_NAME}.app"
SRC_DIR="${ROOT_DIR}/AITranslatorApp"
BUILD_BIN="${SRC_DIR}/.build/release/AITranslator"
DIST_DIR="${ROOT_DIR}/dist"
DIST_APP="${DIST_DIR}/${APP_NAME}.app"
ZIP_PATH="${DIST_DIR}/${APP_FILE_NAME}-macOS.zip"
APP_VERSION="1.0.0"

echo "正在用 Swift/SwiftUI 编译 ${APP_NAME}..."
cd "${SRC_DIR}"
if swift build -c release --arch arm64 --arch x86_64; then
  BUILD_BIN="${SRC_DIR}/.build/apple/Products/Release/AITranslator"
else
  echo "通用二进制失败，改编当前架构..."
  swift build -c release
  BUILD_BIN="${SRC_DIR}/.build/release/AITranslator"
fi

pack_app() {
  local dest="$1"
  rm -rf "${dest}"
  mkdir -p "${dest}/Contents/MacOS"
  mkdir -p "${dest}/Contents/Resources"

  cp "${BUILD_BIN}" "${dest}/Contents/MacOS/AITranslator"
  chmod +x "${dest}/Contents/MacOS/AITranslator"

  cat > "${dest}/Contents/Info.plist" <<EOF
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

  local icon_src="${ROOT_DIR}/logo.png"
  if [[ ! -f "${icon_src}" ]]; then
    icon_src="${ROOT_DIR}/app-icon.png"
  fi
  if [[ -f "${icon_src}" ]] && command -v sips >/dev/null && command -v iconutil >/dev/null; then
    local iconset="${ROOT_DIR}/.build/AppIcon.iconset"
    mkdir -p "${ROOT_DIR}/.build"
    rm -rf "${iconset}"
    mkdir -p "${iconset}"
    for size in 16 32 128 256 512; do
      sips -z "${size}" "${size}" "${icon_src}" --out "${iconset}/icon_${size}x${size}.png" >/dev/null
      sips -z $((size * 2)) $((size * 2)) "${icon_src}" --out "${iconset}/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "${iconset}" -o "${dest}/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "${dest}/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile AppIcon' "${dest}/Contents/Info.plist" 2>/dev/null || true
  fi

  xattr -cr "${dest}" 2>/dev/null || true
  # 整包 ad-hoc 签名：绑定 Info.plist，避免对方打开时报「已损坏」（xattr 清不掉残缺 linker 签名）
  codesign --force --deep --sign - "${dest}"
}

echo "正在生成 ${APP_PATH} ..."
pack_app "${APP_PATH}"

echo "正在生成分发包..."
mkdir -p "${DIST_DIR}"
pack_app "${DIST_APP}"
rm -f "${ZIP_PATH}"
ditto -c -k --keepParent "${DIST_APP}" "${ZIP_PATH}"
cp "${ZIP_PATH}" "${HOME}/Desktop/${APP_FILE_NAME}-macOS.zip"

echo "完成：${APP_PATH}"
echo "副本：${DIST_APP}"
echo "分发 ZIP：${ZIP_PATH}"
echo "桌面 ZIP：${HOME}/Desktop/${APP_FILE_NAME}-macOS.zip"
echo "源码：${SRC_DIR}"
echo ""
echo "发给别人：把 ZIP 发过去（不要直接发 .app，微信会弄坏签名）。"
echo "对方解压后右键 → 打开。仍提示无法打开时再执行：xattr -cr ~/Desktop/AI翻译.app"
echo "这是菜单栏应用，启动后看屏幕右上角。"
