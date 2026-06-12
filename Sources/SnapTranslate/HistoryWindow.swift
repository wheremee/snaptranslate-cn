import AppKit
import SwiftUI

// MARK: - 记录模型与读取

struct HistoryRecord: Identifiable {
    let id: String          // 文件名时间戳
    let date: String
    let original: String
    let translation: String
}

enum HistoryLoader {
    /// 读取 History 目录下的全部记录，按时间倒序
    static func load() -> [HistoryRecord] {
        let dir = ConfigManager.shared.historyDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil) else { return [] }

        return files
            .filter { $0.pathExtension == "txt" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .compactMap { url in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let stem = url.deletingPathExtension().lastPathComponent
                let (original, translation) = parse(content)
                return HistoryRecord(
                    id: stem,
                    date: stem.replacingOccurrences(of: "_", with: " "),
                    original: original,
                    translation: translation
                )
            }
    }

    static func parse(_ content: String) -> (original: String, translation: String) {
        let parts = content.components(separatedBy: "【译文】")
        let original = parts[0]
            .replacingOccurrences(of: "【原文】", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let translation = parts.count > 1
            ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        return (original, translation)
    }

    static func clearAll() {
        let dir = ConfigManager.shared.historyDirectory
        try? FileManager.default.removeItem(at: dir)
    }
}

// MARK: - 记录窗口

struct HistoryView: View {
    @ObservedObject var configManager = ConfigManager.shared
    @State private var records: [HistoryRecord] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("记录模式", isOn: $configManager.config.keepHistory)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Spacer()
                Button("打开文件夹") {
                    let dir = ConfigManager.shared.historyDirectory
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(dir)
                }
                .controlSize(.small)
                Button("清空记录") {
                    HistoryLoader.clearAll()
                    records = []
                }
                .controlSize(.small)
                .disabled(records.isEmpty)
            }
            .padding(12)

            Divider()

            if records.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text(configManager.config.keepHistory
                         ? "还没有翻译记录，截图翻译后会自动保存在这里"
                         : "记录模式未开启，打开上方开关后翻译会自动存档")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(records) { record in
                            recordRow(record)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(width: 480, height: 420)
        .onAppear { records = HistoryLoader.load() }
    }

    private func recordRow(_ record: HistoryRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.id.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(record.translation.isEmpty ? record.original : record.translation,
                                         forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("复制译文")
            }
            Text(record.original)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
            if !record.translation.isEmpty {
                Text(record.translation)
                    .font(.system(size: 12))
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

@MainActor
final class HistoryWindowController {
    static let shared = HistoryWindowController()

    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "翻译记录"
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // 每次打开重建视图以刷新列表
        window?.contentView = NSHostingView(rootView: HistoryView())
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
