import Foundation

/// 翻译服务类型
enum TranslationProviderType: String, Codable, CaseIterable, Identifiable {
    case openAI
    case deepL
    case google

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .deepL: return "DeepL"
        case .google: return "Google Translate"
        }
    }
}

/// 全局快捷键配置（Carbon keyCode / modifiers）
struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var display: String

    /// 默认 ⇧⌘2
    static let `default` = HotkeyConfig(keyCode: 19, modifiers: 0x0100 | 0x0200, display: "⇧⌘2")
}

/// 应用配置（保存为本地 JSON）
struct AppConfig: Codable, Equatable {
    var provider: TranslationProviderType = .openAI
    var apiKey: String = ""
    var openAIModel: String = "gpt-4o-mini"
    var openAIBaseURL: String = "https://api.openai.com"
    var targetLanguage: String = "zh-Hans"
    var hotkey: HotkeyConfig = .default
    var launchAtLogin: Bool = false
    var autoCopyResult: Bool = false
    var keepHistory: Bool = false

    init() {}

    // 自定义解码：缺失字段使用默认值，保证旧配置向前兼容
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppConfig()
        provider = (try? c.decodeIfPresent(TranslationProviderType.self, forKey: .provider)) ?? defaults.provider
        apiKey = (try? c.decodeIfPresent(String.self, forKey: .apiKey)) ?? defaults.apiKey
        openAIModel = (try? c.decodeIfPresent(String.self, forKey: .openAIModel)) ?? defaults.openAIModel
        openAIBaseURL = (try? c.decodeIfPresent(String.self, forKey: .openAIBaseURL)) ?? defaults.openAIBaseURL
        targetLanguage = (try? c.decodeIfPresent(String.self, forKey: .targetLanguage)) ?? defaults.targetLanguage
        hotkey = (try? c.decodeIfPresent(HotkeyConfig.self, forKey: .hotkey)) ?? defaults.hotkey
        launchAtLogin = (try? c.decodeIfPresent(Bool.self, forKey: .launchAtLogin)) ?? defaults.launchAtLogin
        autoCopyResult = (try? c.decodeIfPresent(Bool.self, forKey: .autoCopyResult)) ?? defaults.autoCopyResult
        keepHistory = (try? c.decodeIfPresent(Bool.self, forKey: .keepHistory)) ?? defaults.keepHistory
    }
}

/// 支持的目标语言
enum TargetLanguage {
    static let options: [(code: String, name: String)] = [
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁体中文"),
        ("en", "English"),
        ("ja", "日本語"),
        ("ko", "한국어")
    ]

    static func displayName(for code: String) -> String {
        options.first { $0.code == code }?.name ?? code
    }
}
