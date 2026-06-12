import AppKit

@main
struct SnapTranslateApp {
    static func main() {
        if CommandLine.arguments.contains("--selfcheck") {
            exit(SelfCheck.runAll())
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏常驻，无 Dock 图标
        NSApp.setActivationPolicy(.accessory)

        // 主菜单（让 ⌘C/⌘V/⌘A 等编辑快捷键在输入框中生效）
        setupMainMenu()

        menuBarController = MenuBarController()

        // 首次启动开始试用计时
        LicenseManager.shared.beginTrialIfNeeded()

        // 还没配置 API Key 时，启动后自动打开设置窗口引导
        if ConfigManager.shared.config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                SettingsWindowController.shared.show()
            }
        }

        // 注册全局快捷键
        HotkeyManager.shared.onHotkey = {
            CaptureCoordinator.shared.start()
        }
        HotkeyManager.shared.register(ConfigManager.shared.config.hotkey)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出 SnapTranslate CN",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }
}
