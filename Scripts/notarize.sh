#!/bin/bash
# Developer ID 签名 + 公证（注册 Apple Developer Program 后使用）
#
# 前置步骤：
# 1. 注册 https://developer.apple.com/programs/ （$99/年）
# 2. Keychain 中安装 "Developer ID Application" 证书
# 3. 生成 App 专用密码: https://appleid.apple.com → 登录与安全 → App 专用密码
# 4. 存储凭据（一次性）:
#    xcrun notarytool store-credentials snaptranslate \
#        --apple-id "你的AppleID邮箱" --team-id "你的TeamID" --password "App专用密码"
# 5. 填写下方 IDENTITY 后运行本脚本
set -e
cd "$(dirname "$0")/.."

IDENTITY="Developer ID Application: YOUR NAME (TEAMID)"   # TODO: 替换
PROFILE="snaptranslate"

if [[ "$IDENTITY" == *"YOUR NAME"* ]]; then
    echo "❌ 请先编辑本脚本，填写你的 Developer ID 证书名称（IDENTITY）"
    exit 1
fi

bash Scripts/build_app.sh
APP="build/SnapTranslate CN.app"

echo "▶ Developer ID 签名"
codesign --force --deep --options runtime --sign "$IDENTITY" "$APP"

echo "▶ 打包 DMG"
bash Scripts/make_dmg.sh
DMG="build/SnapTranslateCN-1.0.0.dmg"

echo "▶ 提交公证（可能需要几分钟）"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait

echo "▶ 装订公证票据"
xcrun stapler staple "$DMG"

echo "✅ 完成：$DMG 可直接分发，用户双击即可安装"
