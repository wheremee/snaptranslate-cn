import Foundation

// MARK: - 公共工具

private func performRequest(_ request: URLRequest, session: URLSession) async throws -> Data {
    let data: Data
    let response: URLResponse
    do {
        (data, response) = try await session.data(for: request)
    } catch {
        throw TranslationError.network(error.localizedDescription)
    }
    guard let http = response as? HTTPURLResponse else {
        throw TranslationError.network("无效响应")
    }
    guard (200..<300).contains(http.statusCode) else {
        let body = String(data: data.prefix(500), encoding: .utf8) ?? ""
        throw TranslationError.http(http.statusCode, body)
    }
    return data
}

private func languageName(_ code: String) -> String {
    switch code {
    case "zh-Hans": return "Simplified Chinese"
    case "zh-Hant": return "Traditional Chinese"
    case "en": return "English"
    case "ja": return "Japanese"
    case "ko": return "Korean"
    default: return code
    }
}

// MARK: - OpenAI

struct OpenAIProvider: TranslationProvider {
    let apiKey: String
    let model: String
    let baseURL: String
    let session: URLSession

    func translate(_ text: String, to targetLanguage: String) async throws -> String {
        var base = baseURL.trimmingCharacters(in: .whitespaces)
        if base.hasSuffix("/") { base = String(base.dropLast()) }
        // 兼容不同厂商：地址已含版本段（…/v1、…/v4）时不再重复拼 /v1
        let path = (base.hasSuffix("/v1") || base.hasSuffix("/v4") || base.hasSuffix("/v2") || base.hasSuffix("/v3"))
            ? "/chat/completions"
            : "/v1/chat/completions"
        guard let url = URL(string: "\(base)\(path)"),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else {
            throw TranslationError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.2,
            "messages": [
                ["role": "system",
                 "content": "You are a translation engine. Translate the user's text into \(languageName(targetLanguage)). Output only the translation, no explanations."],
                ["role": "user", "content": text]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await performRequest(request, session: session)

        struct Response: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let content = decoded.choices.first?.message.content,
              !content.isEmpty else {
            throw TranslationError.emptyResult
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - DeepL

struct DeepLProvider: TranslationProvider {
    let apiKey: String
    let session: URLSession
    /// 可覆盖（测试用）；nil 时根据 key 自动选择免费/付费域名
    var endpoint: URL? = nil

    func translate(_ text: String, to targetLanguage: String) async throws -> String {
        let host = apiKey.hasSuffix(":fx") ? "api-free.deepl.com" : "api.deepl.com"
        guard let url = endpoint ?? URL(string: "https://\(host)/v2/translate") else {
            throw TranslationError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")

        let target: String
        switch targetLanguage {
        case "zh-Hans", "zh-Hant": target = "ZH"
        default: target = targetLanguage.uppercased()
        }
        let body: [String: Any] = ["text": [text], "target_lang": target]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await performRequest(request, session: session)

        struct Response: Decodable {
            struct Translation: Decodable { let text: String }
            let translations: [Translation]
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let result = decoded.translations.first?.text, !result.isEmpty else {
            throw TranslationError.emptyResult
        }
        return result
    }
}

// MARK: - Google Translate

struct GoogleProvider: TranslationProvider {
    let apiKey: String
    let session: URLSession
    var endpoint: URL? = nil

    func translate(_ text: String, to targetLanguage: String) async throws -> String {
        let target: String
        switch targetLanguage {
        case "zh-Hans": target = "zh-CN"
        case "zh-Hant": target = "zh-TW"
        default: target = targetLanguage
        }
        guard let url = endpoint ?? URL(string: "https://translation.googleapis.com/language/translate/v2?key=\(apiKey)") else {
            throw TranslationError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["q": text, "target": target, "format": "text"]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await performRequest(request, session: session)

        struct Response: Decodable {
            struct DataField: Decodable {
                struct Translation: Decodable { let translatedText: String }
                let translations: [Translation]
            }
            let data: DataField
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let result = decoded.data.translations.first?.translatedText, !result.isEmpty else {
            throw TranslationError.emptyResult
        }
        return result
    }
}
