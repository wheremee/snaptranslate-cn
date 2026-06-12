import Foundation
import Combine

enum LicenseError: LocalizedError, Equatable {
    case emptyKey
    case api(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .emptyKey: return "请输入许可证 Key"
        case .api(let message): return "激活失败：\(message)"
        case .network(let detail): return "网络请求失败：\(detail)"
        }
    }
}

enum LicenseStatus: Equatable {
    case licensed
    case trial(daysLeft: Int)
    case expired

    var displayText: String {
        switch self {
        case .licensed: return "已激活"
        case .trial(let days): return "试用中，还剩 \(days) 天"
        case .expired: return "试用已结束"
        }
    }
}

struct LicenseState: Codable, Equatable {
    var trialStart: Date?
    var licenseKey: String?
    var instanceID: String?
}

/// 许可证管理：7 天试用 + LemonSqueezy 许可证激活
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager(directory: ConfigManager.shared.directory)

    /// TODO: 创建 LemonSqueezy 商店后替换为你的购买页链接
    static let buyURL = URL(string: "https://YOUR-STORE.lemonsqueezy.com")!
    static let trialDays = 7
    static let activateEndpoint = URL(string: "https://api.lemonsqueezy.com/v1/licenses/activate")!

    @Published private(set) var state: LicenseState
    private let fileURL: URL
    private let session: URLSession
    /// 可注入当前时间，便于测试
    var now: () -> Date = { Date() }

    init(directory: URL, session: URLSession = .shared) {
        self.fileURL = directory.appendingPathComponent("license.json")
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? decoder.decode(LicenseState.self, from: data) {
            self.state = loaded
        } else {
            self.state = LicenseState()
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if let data = try? encoder.encode(state) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// 首次启动开始试用计时
    func beginTrialIfNeeded() {
        guard state.trialStart == nil, state.licenseKey == nil else { return }
        state.trialStart = now()
        save()
    }

    var status: LicenseStatus {
        if state.licenseKey != nil { return .licensed }
        guard let start = state.trialStart else { return .trial(daysLeft: Self.trialDays) }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: now()).day ?? 0
        let left = Self.trialDays - elapsed
        return left > 0 ? .trial(daysLeft: left) : .expired
    }

    var isUsable: Bool {
        status != .expired
    }

    // MARK: - LemonSqueezy 激活

    struct ActivationResponse: Decodable {
        struct Instance: Decodable { let id: String }
        let activated: Bool
        let error: String?
        let instance: Instance?
    }

    /// 解析激活响应（独立函数便于测试）
    static func parseActivation(_ data: Data) throws -> String? {
        guard let response = try? JSONDecoder().decode(ActivationResponse.self, from: data) else {
            throw LicenseError.api("无法解析服务器响应")
        }
        guard response.activated else {
            throw LicenseError.api(response.error ?? "许可证无效")
        }
        return response.instance?.id
    }

    @MainActor
    func activate(key: String) async throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LicenseError.emptyKey }

        var request = URLRequest(url: Self.activateEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let deviceName = Host.current().localizedName ?? "Mac"
        let allowed = CharacterSet.alphanumerics
        let encodedKey = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) ?? trimmed
        let encodedName = deviceName.addingPercentEncoding(withAllowedCharacters: allowed) ?? "Mac"
        request.httpBody = Data("license_key=\(encodedKey)&instance_name=\(encodedName)".utf8)

        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw LicenseError.network(error.localizedDescription)
        }

        let instanceID = try Self.parseActivation(data)
        state.licenseKey = trimmed
        state.instanceID = instanceID
        save()
    }
}
