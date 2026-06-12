# SnapTranslate CN

macOS 截图翻译工具：快捷键截图 → Vision OCR 识别文字 → 自动翻译成中文 → 弹窗显示结果。

菜单栏常驻、轻量、原生 Swift/SwiftUI 实现。支持 macOS 13+。

## 快速开始

```bash
# 1. 构建并启动（需要 Xcode 或 Command Line Tools）
bash Scripts/run.sh

# 2. 首次使用：点击菜单栏「译」图标 → 设置… → 填写 API Key

# 3. 按 ⇧⌘2 框选屏幕区域，松手后自动识别并翻译
```

首次截图时 macOS 会要求授予「屏幕录制」权限，按弹窗指引到 系统设置 → 隐私与安全性 → 屏幕录制 勾选本应用后重新启动。

## 功能

截图翻译（默认快捷键 ⇧⌘2，可自定义；**左键点菜单栏图标也可直接截图**，右键弹出菜单）、结果弹窗（原文 / 译文 / 一键复制 / 重新翻译）、三种翻译服务可选（OpenAI 兼容 / DeepL / Google Translate，自备 API Key）、目标语言可选（默认简体中文）、开机自启、自动复制译文、记录模式（翻译记录窗口浏览 / 复制 / 清空）。

## 设置说明

| 项目 | 说明 |
|---|---|
| 翻译服务 | OpenAI（默认，可改模型和 API 地址，兼容中转站）/ DeepL（自动识别免费版 `:fx` key）/ Google v2 |
| API Key | 仅保存在本机配置文件中 |
| 截图快捷键 | 点击输入框后按下组合键（必须含 ⌘/⌥/⌃/⇧ 修饰键），Esc 取消 |
| 开机自启 | 需以打包后的 .app 运行才生效 |
| 截图历史 | 开启后截图与文本保存在配置目录的 History 文件夹 |

配置文件位置：`~/Library/Application Support/SnapTranslateCN/config.json`

## 开发

```bash
swift build                          # 编译
swift run SnapTranslate --selfcheck  # 运行自检（仅需 Command Line Tools）
swift test                           # 运行测试（需要完整 Xcode，CLT 不带测试框架）
bash Scripts/build_app.sh   # 打包 .app 到 build/
bash Scripts/make_dmg.sh    # 打包 DMG 安装镜像
```

环境要求：macOS 13+，Xcode 14.1+（或 Swift 5.7+ toolchain）。检查：`swift --version`；缺少时安装：`xcode-select --install`。

## 项目结构

```
Sources/SnapTranslate/
├── App.swift                 # 入口 + AppDelegate
├── MenuBarController.swift   # 菜单栏
├── CaptureCoordinator.swift  # 主流程 + 历史记录
├── ScreenshotService.swift   # 截图（screencapture 交互选区）
├── OCRService.swift          # Vision OCR
├── TranslationService.swift  # 翻译入口 + 分段
├── TranslationProviders.swift# OpenAI / DeepL / Google
├── AppConfig.swift           # 配置模型
├── ConfigManager.swift       # 配置读写
├── HotkeyManager.swift       # 全局热键（Carbon）
├── PermissionManager.swift   # 权限 + 开机自启
├── ResultWindow.swift        # 结果弹窗
└── SettingsWindow.swift      # 设置页 + 快捷键录制
```

## 许可证

7 天全功能免费试用，到期后需购买许可证激活（LemonSqueezy，一次买断）。详见 [SELLING.md](SELLING.md)。

其他文档：[INSTALL.md](INSTALL.md) 安装说明 · [PRIVACY.md](PRIVACY.md) 隐私说明 · [SELLING.md](SELLING.md) 售卖指南 · [CHANGELOG.md](CHANGELOG.md) 更新日志 · [ROADMAP.md](ROADMAP.md) 版本规划
