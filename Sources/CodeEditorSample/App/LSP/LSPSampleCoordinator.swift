#if canImport(AppKit)
import CodeEditorPlugin
import Foundation
import Observation

/// Owns the sample's LSP lifecycle. Holds a single `LSPManager`, resolves
/// sourcekit-lsp on demand (overridable for tests), and surfaces a state
/// machine to the `LSPInspectorPanel`. Diagnostics, document mirroring,
/// hover, and definition wiring are added in subsequent tasks.
@MainActor
@Observable
final class LSPSampleCoordinator {
    enum State: Equatable {
        case off
        case starting
        case initializing
        case running(capabilities: ServerCapabilitiesSummary)
        case failed(message: String)
    }

    private(set) var state: State = .off
    private(set) var resolvedServerPath: URL?
    private(set) var lastError: String?

    @ObservationIgnored
    private let memoryMonitor: MemoryMonitor

    @ObservationIgnored
    private let serverResolver: @Sendable () async -> URL?

    @ObservationIgnored
    private(set) var manager: LSPManager?

    init(
        memoryMonitor: MemoryMonitor,
        serverResolver: @escaping @Sendable () async -> URL? = LSPSampleCoordinator.defaultResolver
    ) {
        self.memoryMonitor = memoryMonitor
        self.serverResolver = serverResolver
    }

    /// Resolve sourcekit-lsp, register it with `LSPManager`, then start. Sets
    /// `state` through `.starting` → `.initializing` → `.running` or
    /// transitions to `.failed` on any error.
    func start(workspaceRoot: URL?) async {
        guard case .off = state else { return }
        state = .starting

        guard let serverURL = await serverResolver() else {
            let message = "sourcekit-lsp not found. Install Xcode or run xcode-select."
            state = .failed(message: message)
            resolvedServerPath = nil
            return
        }
        resolvedServerPath = serverURL

        let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: workspaceRoot)
        self.manager = manager

        let config = LanguageServerConfig(
            languageId: "swift",
            serverPath: serverURL.path,
            fileExtensions: ["swift"],
            autoStart: false
        )
        manager.registerLanguageServer(config)

        state = .initializing
        do {
            try await manager.startLanguageServer(for: "swift")
        } catch {
            lastError = "\(error)"
            state = .failed(message: error.localizedDescription)
            return
        }

        let caps = ServerCapabilitiesSummary(manager.client(for: "swift")?.serverCapabilities)
        state = .running(capabilities: caps)
    }

    /// Stop the language server and reset state. Safe to call when already
    /// `.off`.
    func stop() async {
        guard state != .off else { return }
        manager?.stopLanguageServer(for: "swift")
        manager = nil
        state = .off
    }

    /// Default `xcrun --find sourcekit-lsp` lookup. Replaced in tests via
    /// `StubProcessResolver`.
    static let defaultResolver: @Sendable () async -> URL? = {
        await Task.detached(priority: .userInitiated) {
            let task = Process()
            task.launchPath = "/usr/bin/xcrun"
            task.arguments = ["--find", "sourcekit-lsp"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            do {
                try task.run()
                task.waitUntilExit()
                guard task.terminationStatus == 0 else { return nil }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !path.isEmpty else { return nil }
                return URL(fileURLWithPath: path)
            } catch {
                return nil
            }
        }.value
    }
}
#endif
