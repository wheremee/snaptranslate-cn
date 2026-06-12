import Foundation
import CoreGraphics
import ImageIO

enum ScreenshotError: LocalizedError, Equatable {
    case captureFailed
    case emptyScreenshot
    case imageLoadFailed

    var errorDescription: String? {
        switch self {
        case .captureFailed: return "截图失败，请重试"
        case .emptyScreenshot: return "截图为空"
        case .imageLoadFailed: return "无法读取截图文件"
        }
    }
}

/// 截图：调用系统 screencapture 交互式选区
final class ScreenshotService {

    /// 交互式截图。用户按 Esc 取消时返回 nil
    func captureInteractive() async throws -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snaptranslate-\(UUID().uuidString).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", "-t", "png", url.path]

        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { p in
                continuation.resume(returning: p.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ScreenshotError.captureFailed)
            }
        }

        guard status == 0 else { throw ScreenshotError.captureFailed }

        // 用户取消（Esc）时不会生成文件
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? Int) ?? 0
        guard size > 0 else { throw ScreenshotError.emptyScreenshot }
        return url
    }

    /// 从文件加载 CGImage
    func loadImage(at url: URL) throws -> CGImage {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ScreenshotError.emptyScreenshot
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ScreenshotError.imageLoadFailed
        }
        return image
    }
}
