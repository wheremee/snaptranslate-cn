import Foundation
import Testing
@testable import SnapTranslate

struct ConfigTests {
    private func makeTempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("snaptranslate-tests-\(UUID().uuidString)")
    }

    @Test func defaultConfig() {
        let config = AppConfig()
        #expect(config.provider == .openAI)
        #expect(config.targetLanguage == "zh-Hans")
        #expect(config.hotkey == .default)
        #expect(!config.launchAtLogin)
    }

    @Test func saveAndReload() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let manager = ConfigManager(directory: dir)
        manager.config.apiKey = "test-key-123"
        manager.config.provider = .deepL
        manager.config.autoCopyResult = true

        let manager2 = ConfigManager(directory: dir)
        #expect(manager2.config.apiKey == "test-key-123")
        #expect(manager2.config.provider == .deepL)
        #expect(manager2.config.autoCopyResult)
    }

    @Test func corruptedConfigFallsBackToDefault() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "not json{{".write(to: dir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)

        let manager = ConfigManager(directory: dir)
        #expect(manager.config == AppConfig())
    }

    @Test func partialConfigUsesDefaults() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #"{"apiKey": "abc"}"#.write(to: dir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)

        let manager = ConfigManager(directory: dir)
        #expect(manager.config.apiKey == "abc")
        #expect(manager.config.provider == .openAI) // 缺失字段用默认值
        #expect(manager.config.hotkey == .default)
    }
}
