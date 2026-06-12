#!/bin/bash
# 生成 App 图标
# 优先使用 assets/AppIcon-1024.png（正式 logo），否则用 make_icon.swift 画占位图标
set -e
cd "$(dirname "$0")/.."

ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

SOURCE="assets/AppIcon-1024.png"
if [ -f "$SOURCE" ]; then
    echo "▶ 使用正式 logo: $SOURCE"
    for entry in "16 icon_16x16" "32 icon_16x16@2x" "32 icon_32x32" "64 icon_32x32@2x" \
                 "128 icon_128x128" "256 icon_128x128@2x" "256 icon_256x256" "512 icon_256x256@2x" \
                 "512 icon_512x512" "1024 icon_512x512@2x"; do
        size="${entry%% *}"
        name="${entry#* }"
        sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/$name.png" >/dev/null
    done
else
    echo "▶ 未找到 $SOURCE，生成占位图标"
    swift Scripts/make_icon.swift "$ICONSET"
fi

iconutil -c icns "$ICONSET" -o build/AppIcon.icns
echo "✅ build/AppIcon.icns"
