import Foundation
import AppKit
import CoreGraphics
import Testing
@testable import SnapTranslate

struct OCRTests {
    let ocr = OCRService()
    let screenshot = ScreenshotService()

    /// 画一张带文字的测试图
    private func makeImage(text: String?, size: CGSize = CGSize(width: 400, height: 120)) -> CGImage {
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

    // OCR 识别英文
    @Test func recognizeEnglishText() async throws {
        let result = try await ocr.recognize(makeImage(text: "Hello World"))
        #expect(result.lowercased().contains("hello"), "OCR 结果: \(result)")
    }

    // 无文字图片 → 空结果
    @Test func blankImageReturnsEmpty() async throws {
        let result = try await ocr.recognize(makeImage(text: nil))
        #expect(result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "空白图不应识别出文字: \(result)")
    }

    // 空截图（文件不存在）
    @Test func missingScreenshotFileThrows() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID().uuidString).png")
        #expect(throws: ScreenshotError.emptyScreenshot) {
            _ = try screenshot.loadImage(at: url)
        }
    }

    // 损坏的截图文件
    @Test func corruptedScreenshotFileThrows() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupted-\(UUID().uuidString).png")
        try Data([0x00, 0x01, 0x02]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: (any Error).self) {
            _ = try screenshot.loadImage(at: url)
        }
    }

    // 权限检查可调用、不崩溃
    @Test func permissionPreflightDoesNotCrash() {
        _ = CGPreflightScreenCaptureAccess()
    }
}
