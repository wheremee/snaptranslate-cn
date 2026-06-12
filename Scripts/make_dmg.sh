#!/bin/bash
# 打包 DMG 安装镜像
set -e
cd "$(dirname "$0")/.."

APP="build/SnapTranslate CN.app"
if [ ! -d "$APP" ]; then
    bash Scripts/build_app.sh
fi

STAGING="build/dmg"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

DMG="build/SnapTranslateCN-1.0.0.dmg"
rm -f "$DMG"
hdiutil create -volname "SnapTranslate CN" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

echo "✅ $DMG"
