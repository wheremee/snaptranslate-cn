import Foundation
import Combine

/// 配置管理：本地 JSON 文件读写
final class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    @Published var config: AppConfig {
        didSet { save() }
    }

    let directory: URL
    var configFileURL: URL { directory.appendingPathComponent("config.json") }
    var historyDirectory: URL { directory.appendingPathComponent("History", isDirectory: true) }

    /// directory 可注入，便于测试
    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SnapTranslateCN", isDirectory: true)
        self.directory = dir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.config = Self.load(from: dir.appendingPathComponent("config.json"))
    }

    static func load(from url: URL) -> AppConfig {
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return config
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: configFileURL, options: .atomic)
    }

    func reload() {
        config = Self.load(from: configFileURL)
    }
}
