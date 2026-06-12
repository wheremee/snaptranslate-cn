import AppKit
import SwiftUI

// MARK: - ViewModel

@MainActor
final class ResultViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case translating
        case done
        case error(String)
        case info(String)
    }

    @Published var original: String = ""
    @Published var translation: String = ""
    @Published var state: State = .idle
    @Published var copied = false

    private var translateTask: Task<Void, Never>?

    func translate() {
        translateTask?.cancel()
        let text = original
        state = .translating
        translation = ""
        copied = false

        translateTask = Task {
            do {
                let config = ConfigManager.shared.config
                let result = try await TranslationService.shared.translate(text, config: config)
                guard !Task.isCancelled else { return }
                translation = result
                state = .done
                if config.autoCopyResult { copyTranslation() }
                if config.keepHistory { HistoryStore.appendTranslation(result) }
            } catch {
                guard !Task.isCancelled else { return }
                state = .error(error.localizedDescription)
            }
        }
    }

    func copyTranslation() {
        guard !translation.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(translation, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copied = false
        }
    }
}

// MARK: - View

struct ResultView: View {
    @ObservedObject var model: ResultViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if case .info(let message) = model.state {
                infoView(message)
            } else {
                textSection(title: "原文", text: model.original)
                Divider()
                translationSection
                buttons
            }
        }
        .padding(14)
        .frame(width: 440)
    }

    private func infoView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
            Text(message)
                .font(.system(size: 13))
                .textSelection(.enabled)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func textSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            ScrollView {
                Text(text)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 130)
        }
    }

    @ViewBuilder
    private var translationSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("译文")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            switch model.state {
            case .translating:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("翻译中…").font(.system(size: 13)).foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            case .error(let message):
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
            default:
                ScrollView {
                    Text(model.translation)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 170)
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Button(action: { model.copyTranslation() }) {
                Label(model.copied ? "已复制" : "复制译文", systemImage: model.copied ? "checkmark" : "doc.on.doc")
            }
            .disabled(model.translation.isEmpty)

            Button(action: { model.translate() }) {
                Label("重新翻译", systemImage: "arrow.clockwise")
            }
            .disabled(model.state == .translating)

            Spacer()

            Button("设置…") {
                SettingsWindowController.shared.show()
            }
            .buttonStyle(.link)
            .font(.system(size: 11))
        }
        .controlSize(.small)
    }
}

// MARK: - WindowController

@MainActor
final class ResultWindowController {
    static let shared = ResultWindowController()

    private var panel: NSPanel?
    private let model = ResultViewModel()

    private func ensurePanel() -> NSPanel {
        if let panel = panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "SnapTranslate CN"
        panel.titlebarAppearsTransparent = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: ResultView(model: model))
        self.panel = panel
        return panel
    }

    private func present() {
        let panel = ensurePanel()
        if !panel.isVisible {
            // 显示在鼠标所在屏幕的中上方
            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
            if let frame = screen?.visibleFrame {
                let x = frame.midX - panel.frame.width / 2
                let y = frame.midY + frame.height * 0.15
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func showAndTranslate(original: String) {
        model.original = original
        model.state = .idle
        present()
        model.translate()
    }

    func showInfo(_ title: String, detail: String) {
        model.original = ""
        model.translation = ""
        model.state = .info("\(title)：\(detail)")
        present()
    }
}
