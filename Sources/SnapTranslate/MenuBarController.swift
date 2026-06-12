import AppKit

/// 菜单栏图标与菜单
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let captureItem = NSMenuItem(title: "截图翻译", action: #selector(captureAction), keyEquivalent: "")
    private let licenseItem = NSMenuItem(title: "许可证…", action: #selector(licenseAction), keyEquivalent: "")

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "SnapTranslate CN")
            button.image?.isTemplate = true
            button.toolTip = "左键：截图翻译　右键：菜单"
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        menu.delegate = self

        captureItem.target = self
        menu.addItem(captureItem)
        menu.addItem(.separator())

        let historyItem = NSMenuItem(title: "翻译记录…", action: #selector(historyAction), keyEquivalent: "")
        historyItem.target = self
        menu.addItem(historyItem)

        let settingsItem = NSMenuItem(title: "设置…", action: #selector(settingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        licenseItem.target = self
        menu.addItem(licenseItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "关于 SnapTranslate CN", action: #selector(aboutAction), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "退出", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        // 注意：不设置 statusItem.menu，左键走 action 直接截图，右键手动弹出菜单
    }

    /// 左键：直接截图翻译；右键 / ⌃左键：弹出菜单
    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
        } else {
            CaptureCoordinator.shared.start()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        // 弹出后立即解绑，保证下次左键仍触发截图
        statusItem.menu = nil
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        captureItem.title = "截图翻译（\(ConfigManager.shared.config.hotkey.display)）"
        licenseItem.title = "许可证（\(LicenseManager.shared.status.displayText)）…"
    }

    @objc private func licenseAction() {
        LicenseWindowController.shared.show()
    }

    @objc private func captureAction() {
        CaptureCoordinator.shared.start()
    }

    @objc private func settingsAction() {
        SettingsWindowController.shared.show()
    }

    @objc private func historyAction() {
        HistoryWindowController.shared.show()
    }

    @objc private func aboutAction() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "SnapTranslate CN"
        alert.informativeText = "截图 → OCR → 翻译\n版本 1.0.0\n\n快捷键截图后自动识别文字并翻译成中文。"
        alert.runModal()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}
