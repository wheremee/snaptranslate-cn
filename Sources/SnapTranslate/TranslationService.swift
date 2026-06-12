import Foundation

enum TranslationError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidURL
    case http(Int, String)
    case emptyResult
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "未配置 API Key，请到「设置」中填写"
        case .invalidURL: return "翻译服务地址无效，请检查设置"
        case .http(let code, let message): return "翻译服务返回错误（\(code)）：\(message)"
        case .emptyResult: return "翻译服务返回了空结果"
        case .network(let detail): return "网络请求失败：\(detail)"
        }
    }
}

/// 翻译提供方协议
protocol TranslationProvider {
    func translate(_ text: String, to targetLanguage: String) async throws -> String
}

/// 长文本分段：按段落切分，每段不超过 limit 字符
enum TextChunker {
    static func split(_ text: String, limit: Int = 3000) -> [String] {
        guard text.count > limit else { return [text] }
        var chunks: [String] = []
        var current = ""
        for paragraph in text.components(separatedBy: "\n") {
            if current.isEmpty {
                current = paragraph
            } else if current.count + paragraph.count + 1 <= limit {
                current += "\n" + paragraph
            } else {
                chunks.append(current)
                current = paragraph
            }
            // 单段超长时硬切
            while current.count > limit {
                let index = current.index(current.startIndex, offsetBy: limit)
                chunks.append(String(current[..<index]))
                current = String(current[index...])
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}

/// 翻译服务入口：根据配置选择提供方，自动分段
final class TranslationService {
    static let shared = TranslationService()

    private let session: URLSession

    init(session: URLSession = .shared) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = session === URLSession.shared ? URLSession(configuration: configuration) : session
    }

    func makeProvider(config: AppConfig) -> TranslationProvider {
        switch config.provider {
        case .openAI:
            return OpenAIProvider(apiKey: config.apiKey, model: config.openAIModel,
                                  baseURL: config.openAIBaseURL, session: session)
        case .deepL:
            return DeepLProvider(apiKey: config.apiKey, session: session)
        case .google:
            return GoogleProvider(apiKey: config.apiKey, session: session)
        }
    }

    func translate(_ text: String, config: AppConfig) async throws -> String {
        guard !config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw TranslationError.missingAPIKey
        }
        let provider = makeProvider(config: config)
        let chunks = TextChunker.split(text)
        var results: [String] = []
        for chunk in chunks {
            results.append(try await provider.translate(chunk, to: config.targetLanguage))
        }
        return results.joined(separator: "\n")
    }
}
