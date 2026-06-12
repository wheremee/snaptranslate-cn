import Foundation
@preconcurrency import Vision
import CoreGraphics

enum OCRError: LocalizedError {
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .recognitionFailed(let detail): return "文字识别失败：\(detail)"
        }
    }
}

/// OCR：Apple Vision 文字识别
final class OCRService {

    /// 识别图片文字，按行拼接。未识别到文字时返回空字符串
    func recognize(_ image: CGImage) async throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ja-JP", "ko-KR"]
        if #available(macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: lines.joined(separator: "\n"))
                } catch {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                }
            }
        }
    }
}
