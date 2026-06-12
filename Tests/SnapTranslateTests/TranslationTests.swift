import Foundation
import Testing
@testable import SnapTranslate

// MARK: - URL Mock

final class MockURLProtocol: URLProtocol {
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

func mockSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}

// MARK: - 分段逻辑（无共享状态，可并行）

struct ChunkerTests {
    @Test func shortText() {
        #expect(TextChunker.split("hello", limit: 100) == ["hello"])
    }

    @Test func splitsByParagraph() {
        let text = String(repeating: "a", count: 60) + "\n" + String(repeating: "b", count: 60)
        let chunks = TextChunker.split(text, limit: 100)
        #expect(chunks.count == 2)
        #expect(chunks[0].allSatisfy { $0 == "a" })
    }

    @Test func hardSplitsLongParagraph() {
        let text = String(repeating: "x", count: 250)
        let chunks = TextChunker.split(text, limit: 100)
        #expect(chunks.count == 3)
        #expect(chunks.joined() == text)
    }
}

// MARK: - 翻译接口（MockURLProtocol 为共享状态，串行执行）

@Suite(.serialized)
struct TranslationTests {

    @Test func missingAPIKey() async {
        var config = AppConfig()
        config.apiKey = "  "
        await #expect(throws: TranslationError.missingAPIKey) {
            _ = try await TranslationService.shared.translate("hello", config: config)
        }
    }

    @Test func openAISuccess() async throws {
        MockURLProtocol.handler = { request in
            #expect(request.url?.path == "/v1/chat/completions")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
            return (200, Data(#"{"choices":[{"message":{"content":"你好，世界"}}]}"#.utf8))
        }
        defer { MockURLProtocol.handler = nil }
        let provider = OpenAIProvider(apiKey: "sk-test", model: "gpt-4o-mini",
                                      baseURL: "https://api.openai.com", session: mockSession())
        let result = try await provider.translate("Hello, world", to: "zh-Hans")
        #expect(result == "你好，世界")
    }

    @Test func openAIHTTPError() async {
        MockURLProtocol.handler = { _ in
            (401, Data(#"{"error":{"message":"Invalid key"}}"#.utf8))
        }
        defer { MockURLProtocol.handler = nil }
        let provider = OpenAIProvider(apiKey: "bad", model: "gpt-4o-mini",
                                      baseURL: "https://api.openai.com", session: mockSession())
        do {
            _ = try await provider.translate("Hello", to: "zh-Hans")
            Issue.record("应当抛出 http 错误")
        } catch let error as TranslationError {
            guard case .http(let code, _) = error else {
                Issue.record("错误类型不对: \(error)")
                return
            }
            #expect(code == 401)
        } catch {
            Issue.record("错误类型不对: \(error)")
        }
    }

    @Test func openAIEmptyResult() async {
        MockURLProtocol.handler = { _ in (200, Data(#"{"choices":[]}"#.utf8)) }
        defer { MockURLProtocol.handler = nil }
        let provider = OpenAIProvider(apiKey: "sk-test", model: "gpt-4o-mini",
                                      baseURL: "https://api.openai.com", session: mockSession())
        await #expect(throws: TranslationError.emptyResult) {
            _ = try await provider.translate("Hello", to: "zh-Hans")
        }
    }

    @Test func deepLSuccess() async throws {
        MockURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "DeepL-Auth-Key key:fx")
            return (200, Data(#"{"translations":[{"text":"你好"}]}"#.utf8))
        }
        defer { MockURLProtocol.handler = nil }
        let provider = DeepLProvider(apiKey: "key:fx", session: mockSession())
        let result = try await provider.translate("Hello", to: "zh-Hans")
        #expect(result == "你好")
    }

    @Test func googleSuccess() async throws {
        MockURLProtocol.handler = { _ in
            (200, Data(#"{"data":{"translations":[{"translatedText":"世界"}]}}"#.utf8))
        }
        defer { MockURLProtocol.handler = nil }
        let provider = GoogleProvider(apiKey: "g-key", session: mockSession())
        let result = try await provider.translate("World", to: "zh-Hans")
        #expect(result == "世界")
    }

    @Test func invalidBaseURL() async {
        let provider = OpenAIProvider(apiKey: "k", model: "m", baseURL: " not a url ", session: mockSession())
        await #expect(throws: TranslationError.invalidURL) {
            _ = try await provider.translate("Hello", to: "zh-Hans")
        }
    }
}
