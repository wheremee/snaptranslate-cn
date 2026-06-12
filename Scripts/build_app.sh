#!/bin/bash
# 构建 SnapTranslate CN.app
set -e
cd "$(dirname "$0")/.."

echo "▶ swift build -c release"
swift build -c release

APP="build/SnapTranslate CN.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/SnapTranslate "$APP/Contents/MacOS/SnapTranslate"
cp Sources/SnapTranslate/Resources/Info.plist "$APP/Contents/Info.plist"

# 图标（每次重新生成，确保 assets/ 中的正式 logo 生效）
bash Scripts/make_icon.sh || echo "⚠ 图标生成失败，跳过"
[ -f build/AppIcon.icns ] && cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc 签名（本机运行足够；分发需开发者证书）
codesign --force --deep --sign - "$APP"

echo "✅ 构建完成: $APP"
echo "   运行: open \"$APP\""
