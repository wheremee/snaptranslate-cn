import AppKit
import SwiftUI
import Carbon

// MARK: - 服务商预设

struct ProviderPreset: Identifiable {
    let id: String
    let name: String
    let baseURL: String
    let models: [String]

    static let all: [ProviderPreset] = [
        ProviderPreset(id: "minimax", name: "MiniMax", baseURL: "https://api.minimaxi.com",
                       models: ["MiniMax-M2", "MiniMax-Text-01"]),
        ProviderPreset(id: "deepseek", name: "DeepSeek", baseURL: "https://api.deepseek.com",
                       models: ["deepseek-chat", "deepseek-reasoner"]),
        ProviderPreset(id: "kimi", name: "Kimi（月之暗面）", baseURL: "https://api.moonshot.cn",
                       models: ["kimi-latest", "moonshot-v1-8k"]),
        ProviderPreset(id: "qwen", name: "通义千问", baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
                       models: ["qwen-plus", "qwen-turbo", "qwen-max"]),
        ProviderPreset(id: "zhipu", name: "智谱 GLM", baseURL: "https://open.bigmodel.cn/api/paas/v4",
                       models: ["glm-4-flash", "glm-4-plus"]),
        ProviderPreset(id: "openai", name: "OpenAI", baseURL: "https://api.openai.com",
                       models: ["gpt-4o-mini", "gpt-4o"])
    ]
}

// MARK: - 快捷键录制控件

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var hotkey: HotkeyConfig

    func makeNSView(context: Context) -> RecorderField {
        let field = RecorderField()
        field.onCapture = { keyCode, modifiers in
            hotkey = HotkeyConfig(keyCode: keyCode, modifiers: modifiers,
                                  display: KeyCodeMap.display(keyCode: keyCode, carbonModifiers: modifiers))
        }
        return field
    }

    func updateNSView(_ nsView: RecorderField, context: Context) {
        nsView.display = hotkey.display
    }

    final class RecorderField: NSView {
        var onCapture: ((UInt32, UInt32) -> Void)?
        var display: String = "" { didSet { needsDisplay = true } }
        private var recording = false { didSet { needsDisplay = true } }

        override var acceptsFirstResponder: Bool { true }
        override var intrinsicContentSize: NSSize { NSSize(width: 140, height: 24) }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            recording = true
        }

        override func resignFirstResponder() -> Bool {
            recording = false
            return super.resignFirstResponder()
        }

        override func keyDown(with event: NSEvent) {
            guard recording else { super.keyDown(with: event); return }
            if event.keyCode == 53 { // Esc 取消录制
                recording = false
                window?.makeFirstResponder(nil)
                return
            }
            let modifiers = KeyCodeMap.carbonModifiers(from: event.modifierFlags)
            guard modifiers != 0 else { return } // 必须带修饰键
            onCapture?(UInt32(event.keyCode), modifiers)
            recording = false
            window?.makeFirstResponder(nil)
        }

        override func draw(_ dirtyRect: NSRect) {
            let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
            let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
            (recording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill()
            path.fill()
            (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
            path.stroke()

            let text = recording ? "按下快捷键…" : display
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: recording ? NSColor.secondaryLabelColor : NSColor.labelColor
            ]
            let size = text.size(withAttributes: attributes)
            text.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                                  y: (bounds.height - size.height) / 2),
                      withAttributes: attributes)
        }
    }
}

// MARK: - 设置页

struct SettingsView: View {
    @ObservedObject var configManager = ConfigManager.shared
    @State private var launchError: String?
    @State private var testing = false
    @State private var testResult: String?
    @State private var testPassed = false

    private var currentPreset: ProviderPreset? {
        ProviderPreset.all.first { $0.baseURL == configManager.config.openAIBaseURL }
    }

    var body: some View {
        Form {
            Section {
                Picker("翻译服务", selection: $configManager.config.provider) {
                    ForEach(TranslationProviderType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                if configManager.config.provider == .openAI {
                    Picker("服务商", selection: presetBinding) {
                        ForEach(ProviderPreset.all) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                        Text("自定义").tag("custom")
                    }

                    HStack(spacing: 6) {
                        TextField("模型", text: $configManager.config.openAIModel)
                        if let preset = currentPreset {
                            Menu {
                                ForEach(preset.models, id: \.self) { model in
                                    Button(model) { configManager.config.openAIModel = model }
                                }
                            } label: {
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 24)
                        }
                    }

                    TextField("API 地址", text: $configManager.config.openAIBaseURL)
                }

                SecureField("API Key", text: $configManager.config.apiKey)

                Picker("目标语言", selection: $configManager.config.targetLanguage) {
                    ForEach(TargetLanguage.options, id: \.code) { option in
                        Text(option.name).tag(option.code)
                    }
                }

                HStack(spacing: 8) {
                    Button(testing ? "测试中…" : "测试连接") { testConnection() }
                        .disabled(testing || configManager.config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    if let testResult = testResult {
                        Text(testResult)
                            .font(.system(size: 11))
                            .foregroundColor(testPassed ? .green : .red)
                            .lineLimit(2)
                    }
                }
            } header: {
                Text("翻译")
            }

            Section {
                LabeledContent("截图快捷键") {
                    HotkeyRecorderView(hotkey: $configManager.config.hotkey)
                        .frame(width: 140, height: 24)
                }
                Toggle("开机自启", isOn: Binding(
                    get: { configManager.config.launchAtLogin },
                    set: { newValue in
                        configManager.config.launchAtLogin = newValue
                        launchError = LaunchAtLogin.set(newValue)
                    }
                ))
                if let launchError = launchError {
                    Text(launchError)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                Toggle("翻译完成后自动复制译文", isOn: $configManager.config.autoCopyResult)
                Toggle("记录模式（保留翻译记录）", isOn: $configManager.config.keepHistory)
            } header: {
                Text("通用")
            }

            Section {
                HStack {
                    Text("设置自动保存")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("完成") { SettingsWindowController.shared.close() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .frame(minHeight: 440)
        .onChange(of: configManager.config.hotkey) { newValue in
            HotkeyManager.shared.register(newValue)
        }
    }

    /// 服务商预设选择：切换时自动填地址和默认模型
    private var presetBinding: Binding<String> {
        Binding(
            get: { currentPreset?.id ?? "custom" },
            set: { id in
                guard let preset = ProviderPreset.all.first(where: { $0.id == id }) else { return }
                configManager.config.openAIBaseURL = preset.baseURL
                configManager.config.openAIModel = preset.models[0]
                testResult = nil
            }
        )
    }

    private func testConnection() {
        testing = true
        testResult = nil
        Task { @MainActor in
            defer { testing = false }
            do {
                _ = try await TranslationService.shared.translate("Hello", config: configManager.config)
                testResult = "连接成功，配置可用 ✓"
                testPassed = true
            } catch {
                testResult = error.localizedDescription
                testPassed = false
            }
        }
    }
}

// MARK: - WindowController

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "设置"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView())
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }
}
