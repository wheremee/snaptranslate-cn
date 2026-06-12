import AppKit
import CoreGraphics
import ServiceManagement

/// macOS 权限处理
enum PermissionManager {

    /// 屏幕录制权限。无权限时弹窗引导去系统设置
    @MainActor
    @discardableResult
    static func ensureScreenCapturePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        // 触发系统授权弹窗（首次）
        CGRequestScreenCaptureAccess()

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "需要「屏幕录制」权限"
        alert.informativeText = "SnapTranslate CN 需要屏幕录制权限才能截图识别文字。\n\n请在「系统设置 → 隐私与安全性 → 屏幕录制」中勾选本应用，然后重新启动应用。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        if alert.runModal() == .alertFirstButtonReturn {
            openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        }
        return false
    }

    static func openSystemSettings(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

/// 开机自启（macOS 13+ SMAppService，仅在打包为 .app 后生效）
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 返回错误信息；成功返回 nil
    @discardableResult
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return "设置开机自启失败：\(error.localizedDescription)\n（提示：需要以打包后的 .app 运行，swift run 模式不支持）"
        }
    }
}
