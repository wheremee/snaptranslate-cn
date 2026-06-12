import AppKit
import CoreGraphics
import Foundation

// MARK: - 自检用 URL Mock

final class SelfCheckURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - 自检（swift run SnapTranslate --selfcheck）

final class SelfCheck {
    private var passed = 0
    private var failed = 0

    private func check(_ name: String, _ condition: Bool, _ detail: String = "") {
        if condition {
            passed += 1
            print("✅ \(name)")
        } else {
            failed += 1
            print("❌ \(name)  \(detail)")
        }
    }

    static func runAll() -> Int32 {
        let runner = SelfCheck()
        print("SnapTranslate CN 自检\n")
        runner.configChecks()
        runner.chunkerChecks()
        runner.licenseChecks()

        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            await runner.providerChecks()
            await runner.ocrChecks()
            semaphore.signal()
        }
        semaphore.wait()

        runner.screenshotChecks()
        runner.permissionChecks()

        print("\n结果：通过 \(runner.passed) 项，失败 \(runner.failed) 项")
        return runner.failed == 0 ? 0 : 1
    }

    // 配置读写
    private func configChecks() {
        let defaults = AppConfig()
        check("默认配置", defaults.provider == .openAI && defaults.targetLanguage == "zh-Hans"
              && defaults.hotkey == .default && !defaults.launchAtLogin)

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snaptranslate-selfcheck-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        let m1 = ConfigManager(directory: dir)
        m1.config.apiKey = "test-key-123"
        m1.config.provider = .deepL
        let m2 = ConfigManager(directory: dir)
        check("配置保存与重载", m2.config.apiKey == "test-key-123" && m2.config.provider == .deepL)

        try? "not json{{".write(to: dir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        check("损坏配置回退默认值", ConfigManager(directory: dir).config == AppConfig())

        try? #"{"apiKey": "abc"}"#.write(to: dir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        let partial = ConfigManager(directory: dir).config
        check("部分配置补默认值", partial.apiKey == "abc" && partial.provider == .openAI && partial.hotkey == .default)
    }

    // 长文本分段
    private func chunkerChecks() {
        check("短文本不分段", TextChunker.split("hello", limit: 100) == ["hello"])

        let two = String(repeating: "a", count: 60) + "\n" + String(repeating: "b", count: 60)
        check("按段落分段", TextChunker.split(two, limit: 100).count == 2)

        let long = String(repeating: "x", count: 250)
        let chunks = TextChunker.split(long, limit: 100)
        check("超长段落硬切且无丢失", chunks.count == 3 && chunks.joined() == long)
    }

    // 许可证：试用计时与激活响应解析
    private func licenseChecks() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snaptranslate-license-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        let start = Date()
        let manager = LicenseManager(directory: dir)
        manager.now = { start }
        manager.beginTrialIfNeeded()
        check("试用开始为 7 天", manager.status == .trial(daysLeft: 7))

        manager.now = { start.addingTimeInterval(3 * 86400) }
        check("试用第 3 天剩 4 天", manager.status == .trial(daysLeft: 4))

        manager.now = { start.addingTimeInterval(8 * 86400) }
        check("第 8 天试用到期", manager.status == .expired && !manager.isUsable)

        // 试用计时持久化
        let reloaded = LicenseManager(directory: dir)
        reloaded.now = { start.addingTimeInterval(2 * 86400) }
        check("试用计时持久化", reloaded.status == .trial(daysLeft: 5))

        // 激活响应解析
        let ok = Data(#"{"activated":true,"instance":{"id":"inst-123"}}"#.utf8)
        check("激活成功解析", (try? LicenseManager.parseActivation(ok)) == "inst-123")

        let bad = Data(#"{"activated":false,"error":"license_key not found"}"#.utf8)
        do {
            _ = try LicenseManager.parseActivation(bad)
            check("无效 Key 报错", false)
        } catch {
            check("无效 Key 报错", (error as? LicenseError) == .api("license_key not found"))
        }
    }

    // 翻译接口（mock 网络）
    private func providerChecks() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SelfCheckURLProtocol.self]
        let session = URLSession(configuration: configuration)

        // 缺 API Key
        var config = AppConfig()
        config.apiKey = "  "
        do {
            _ = try await TranslationService.shared.translate("hello", config: config)
            check("缺少 API Key 报错", false)
        } catch {
            check("缺少 API Key 报错", (error as? TranslationError) == .missingAPIKey)
        }

        // OpenAI 正常
        SelfCheckURLProtocol.handler = { request in
            let pathOK = request.url?.path == "/v1/chat/completions"
            let authOK = request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test"
            return pathOK && authOK
                ? (200, Data(#"{"choices":[{"message":{"content":"你好，世界"}}]}"#.utf8))
                : (500, Data("bad request shape".utf8))
        }
        let openAI = OpenAIProvider(apiKey: "sk-test", model: "gpt-4o-mini",
                                    baseURL: "https://api.openai.com", session: session)
        do {
            let r = try await openAI.translate("Hello, world", to: "zh-Hans")
            check("OpenAI 翻译解析", r == "你好，世界")
        } catch {
            check("OpenAI 翻译解析", false, "\(error)")
        }

        // API 报错
        SelfCheckURLProtocol.handler = { _ in (401, Data(#"{"error":{"message":"Invalid key"}}"#.utf8)) }
        do {
            _ = try await openAI.translate("Hello", to: "zh-Hans")
            check("API 401 报错", false)
        } catch let error as TranslationError {
            if case .http(let code, _) = error { check("API 401 报错", code == 401) }
            else { check("API 401 报错", false, "\(error)") }
        } catch {
            check("API 401 报错", false, "\(error)")
        }

        // 空结果
        SelfCheckURLProtocol.handler = { _ in (200, Data(#"{"choices":[]}"#.utf8)) }
        do {
            _ = try await openAI.translate("Hello", to: "zh-Hans")
            check("空结果报错", false)
        } catch {
            check("空结果报错", (error as? TranslationError) == .emptyResult)
        }

        // DeepL
        SelfCheckURLProtocol.handler = { request in
            request.value(forHTTPHeaderField: "Authorization") == "DeepL-Auth-Key key:fx"
                ? (200, Data(#"{"translations":[{"text":"你好"}]}"#.utf8))
                : (500, Data("bad auth".utf8))
        }
        do {
            let r = try await DeepLProvider(apiKey: "key:fx", session: session).translate("Hello", to: "zh-Hans")
            check("DeepL 翻译解析", r == "你好")
        } catch {
            check("DeepL 翻译解析", false, "\(error)")
        }

        // Google
        SelfCheckURLProtocol.handler = { _ in (200, Data(#"{"data":{"translations":[{"translatedText":"世界"}]}}"#.utf8)) }
        do {
            let r = try await GoogleProvider(apiKey: "g-key", session: session).translate("World", to: "zh-Hans")
            check("Google 翻译解析", r == "世界")
        } catch {
            check("Google 翻译解析", false, "\(error)")
        }

        // 地址已含 /v1 时不重复拼接（通义/智谱等兼容模式）
        SelfCheckURLProtocol.handler = { request in
            request.url?.path == "/compatible-mode/v1/chat/completions"
                ? (200, Data(#"{"choices":[{"message":{"content":"好"}}]}"#.utf8))
                : (500, Data("wrong path: \(request.url?.path ?? "?")".utf8))
        }
        let qwen = OpenAIProvider(apiKey: "k", model: "qwen-plus",
                                  baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", session: session)
        do {
            let r = try await qwen.translate("Hi", to: "zh-Hans")
            check("兼容 /v1 结尾地址", r == "好")
        } catch {
            check("兼容 /v1 结尾地址", false, "\(error)")
        }

        // 无效地址
        let bad = OpenAIProvider(apiKey: "k", model: "m", baseURL: " not a url ", session: session)
        do {
            _ = try await bad.translate("Hello", to: "zh-Hans")
            check("无效 API 地址报错", false)
        } catch {
            check("无效 API 地址报错", (error as? TranslationError) == .invalidURL)
        }

        SelfCheckURLProtocol.handler = nil
    }

    // OCR
    private func ocrChecks() async {
        let ocr = OCRService()
        do {
            let r = try await ocr.recognize(Self.makeImage(text: "Hello World"))
            check("OCR 识别英文", r.lowercased().contains("hello"), "结果: \(r)")
        } catch {
            check("OCR 识别英文", false, "\(error)")
        }
        do {
            let r = try await ocr.recognize(Self.makeImage(text: nil))
            check("空白图片无文字", r.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "结果: \(r)")
        } catch {
            check("空白图片无文字", false, "\(error)")
        }
    }

    // 截图文件异常
    private func screenshotChecks() {
        let service = ScreenshotService()
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).png")
        do {
            _ = try service.loadImage(at: missing)
            check("截图文件不存在报错", false)
        } catch {
            check("截图文件不存在报错", (error as? ScreenshotError) == .emptyScreenshot)
        }

        let corrupted = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupted-\(UUID().uuidString).png")
        try? Data([0x00, 0x01, 0x02]).write(to: corrupted)
        defer { try? FileManager.default.removeItem(at: corrupted) }
        do {
            _ = try service.loadImage(at: corrupted)
            check("损坏截图文件报错", false)
        } catch {
            check("损坏截图文件报错", true)
        }
    }

    // 权限
    private func permissionChecks() {
        let granted = CGPreflightScreenCaptureAccess()
        check("屏幕录制权限检查可调用（当前：\(granted ? "已授权" : "未授权")）", true)
    }

    private static func makeImage(text: String?, size: CGSize = CGSize(width: 400, height: 120)) -> CGImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        if let text = text {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 36, weight: .medium),
                .foregroundColor: NSColor.black
            ]
            text.draw(at: NSPoint(x: 20, y: 40), withAttributes: attributes)
        }
        image.unlockFocus()
        var rect = CGRect(origin: .zero, size: size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
    }
}
