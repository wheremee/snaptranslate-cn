import AppKit
import SwiftUI

struct LicenseView: View {
    @ObservedObject var manager = LicenseManager.shared
    @State private var keyInput = ""
    @State private var message: String?
    @State private var messageIsError = false
    @State private var activating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: manager.status == .licensed ? "checkmark.seal.fill" : "clock")
                    .font(.system(size: 28))
                    .foregroundColor(manager.status == .licensed ? .green : .accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SnapTranslate CN")
                        .font(.system(size: 15, weight: .semibold))
                    Text(manager.status.displayText)
                        .font(.system(size: 12))
                        .foregroundColor(manager.status == .expired ? .red : .secondary)
                }
            }

            if manager.status != .licensed {
                if manager.status == .expired {
                    Text("试用期已结束。购买许可证后输入 Key 即可继续使用，一次付费永久有效。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    TextField("输入许可证 Key", text: $keyInput)
                        .textFieldStyle(.roundedBorder)
                    Button(activating ? "激活中…" : "激活") {
                        activate()
                    }
                    .disabled(activating || keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Button("购买许可证") {
                    NSWorkspace.shared.open(LicenseManager.buyURL)
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            } else {
                Text("感谢支持！本设备已永久激活。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            if let message = message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(messageIsError ? .red : .green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(width: 380)
    }

    private func activate() {
        activating = true
        message = nil
        Task { @MainActor in
            defer { activating = false }
            do {
                try await LicenseManager.shared.activate(key: keyInput)
                message = "激活成功！"
                messageIsError = false
            } catch {
                message = error.localizedDescription
                messageIsError = true
            }
        }
    }
}

@MainActor
final class LicenseWindowController {
    static let shared = LicenseWindowController()

    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "许可证"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: LicenseView())
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
