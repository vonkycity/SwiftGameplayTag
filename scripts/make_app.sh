#!/bin/bash
# 把 SwiftPM release 构建产物打包为可双击运行的 .app
# 用法：./scripts/make_app.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SwiftGameplayTag"
APP_BUNDLE="${PROJECT_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"

BIN_SRC="${PROJECT_DIR}/.build/release/${APP_NAME}"
ICON_SRC="${PROJECT_DIR}/Resources/AppIcon.icns"

if [[ ! -f "$BIN_SRC" ]]; then
  echo "❌ 找不到 ${BIN_SRC}，请先执行 swift build -c release"
  exit 1
fi

echo "📦 清理旧包..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "📋 复制二进制..."
cp "$BIN_SRC" "$MACOS_DIR/${APP_NAME}"
chmod +x "$MACOS_DIR/${APP_NAME}"

# 复制图标（如果存在）
if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "${RESOURCES_DIR}/AppIcon.icns"
fi

# 写入 Info.plist
cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.gametools.${APP_NAME}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>GameplayTag Editor</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSSupportsAutomaticTermination</key>
  <true/>
  <key>NSSupportsSuddenTermination</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>© 2026 GameTools</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>CSV Tags</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.comma-separated-values-text</string>
        <string>public.plain-text</string>
      </array>
    </dict>
    <dict>
      <key>CFBundleTypeName</key>
      <string>UE GameplayTags Config</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.plain-text</string>
      </array>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>ini</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

# PkgInfo
printf "APPL????" > "${CONTENTS}/PkgInfo"

# 写一个简单的 PkgInfo / Credits 可选
echo "📦 已生成 ${APP_BUNDLE}"
