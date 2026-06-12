# 安装说明

## 方式一：从源码运行（开发者）

```bash
xcode-select --install        # 如未安装 Command Line Tools
bash Scripts/run.sh           # 构建并启动
```

## 方式二：DMG 安装

```bash
bash Scripts/make_dmg.sh
```

打开 `build/SnapTranslateCN-1.0.0.dmg`，将 SnapTranslate CN 拖入 Applications，从启动台打开。

由于使用 ad-hoc 签名，首次打开如提示"无法验证开发者"：右键 App → 打开，或在 系统设置 → 隐私与安全性 中点击"仍要打开"。

## 首次配置

1. 点击菜单栏「译」图标 → 设置…
2. 选择翻译服务并填入 API Key：
   - OpenAI：https://platform.openai.com/api-keys （也支持兼容 OpenAI 协议的中转地址）
   - DeepL：https://www.deepl.com/pro-api （免费版 key 以 `:fx` 结尾）
   - Google：https://console.cloud.google.com/ 启用 Cloud Translation API
3. 按 ⇧⌘2 测试截图翻译

## 权限

| 权限 | 用途 | 设置路径 |
|---|---|---|
| 屏幕录制 | 截取屏幕内容做 OCR | 系统设置 → 隐私与安全性 → 屏幕录制 |
| 网络 | 调用翻译 API | 无需手动设置 |

全局快捷键使用系统 RegisterEventHotKey，不需要辅助功能权限。授权屏幕录制后需重新启动应用。

## 卸载

删除 App 本体及配置目录 `~/Library/Application Support/SnapTranslateCN/`。
