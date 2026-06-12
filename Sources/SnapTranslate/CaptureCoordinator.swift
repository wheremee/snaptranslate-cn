import AppKit

/// 主流程：截图 → OCR → 翻译 → 弹窗
@MainActor
final class CaptureCoordinator {
    static let shared = CaptureCoordinator()

    private let screenshot = ScreenshotService()
    private let ocr = OCRService()
    private var running = false

    func start() {
        guard !running else { return }
        guard LicenseManager.shared.isUsable else {
            LicenseWindowController.shared.show()
            return
        }
        guard PermissionManager.ensureScreenCapturePermission() else { return }
        running = true

        Task { @MainActor in
            defer { running = false }
            do {
                guard let url = try await screenshot.captureInteractive() else { return } // 用户取消
                let image = try screenshot.loadImage(at: url)
                let text = try await ocr.recognize(image)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if ConfigManager.shared.config.keepHistory {
                    HistoryStore.save(screenshotURL: url, originalText: text)
                }

                guard !text.isEmpty else {
                    ResultWindowController.shared.showInfo("未识别到文字", detail: "截图中没有检测到可识别的文字，请重试。")
                    return
                }
                ResultWindowController.shared.showAndTranslate(original: text)
            } catch {
                ResultWindowController.shared.showInfo("出错了", detail: error.localizedDescription)
            }
        }
    }
}

/// 截图历史：保存截图与文本
enum HistoryStore {
    static func save(screenshotURL: URL, originalText: String, translation: String? = nil) {
        let dir = ConfigManager.shared.historyDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let stamp = formatter.string(from: Date())

        try? FileManager.default.copyItem(at: screenshotURL, to: dir.appendingPathComponent("\(stamp).png"))
        var content = "【原文】\n\(originalText)\n"
        if let translation = translation {
            content += "\n【译文】\n\(translation)\n"
        }
        try? content.write(to: dir.appendingPathComponent("\(stamp).txt"), atomically: true, encoding: .utf8)
    }

    /// 翻译完成后补写译文
    static func appendTranslation(_ translation: String) {
        let dir = ConfigManager.shared.historyDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]),
              let latest = files.filter({ $0.pathExtension == "txt" }).max(by: {
                  let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                  let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                  return a < b
              }),
              var content = try? String(contentsOf: latest, encoding: .utf8),
              !content.contains("【译文】") else { return }
        content += "\n【译文】\n\(translation)\n"
        try? content.write(to: latest, atomically: true, encoding: .utf8)
    }
}
