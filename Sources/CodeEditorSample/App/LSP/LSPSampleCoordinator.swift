#if canImport(AppKit)
import CodeEditorCommon
import CodeEditorLanguages
import CodeEditorPlugin
import Combine
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
    private(set) var diagnosticCounts: DiagnosticsBridge.Counts = .zero

    /// Hover popover state — bound by `WindowBody.popover(item:)`. Coordinator
    /// owns it so dismissals during state-change tear down cleanly.
    let hoverSession = HoverSession()

    @ObservationIgnored
    private let memoryMonitor: MemoryMonitor

    @ObservationIgnored
    private let serverResolver: @Sendable () async -> URL?

    @ObservationIgnored
    private(set) var manager: LSPManager?

    @ObservationIgnored
    private var mirror: DocumentMirror?

    @ObservationIgnored
    private var bridge: DiagnosticsBridge?

    @ObservationIgnored
    private var lspCompletionProvider: LSPCompletionProvider?

    @ObservationIgnored
    private weak var controller: EditorController?

    @ObservationIgnored
    private weak var hub: AnnotationsHub?

    @ObservationIgnored
    private var activeURI: (@MainActor () -> String?)?

    init(
        memoryMonitor: MemoryMonitor,
        serverResolver: @escaping @Sendable () async -> URL? = LSPSampleCoordinator.defaultResolver
    ) {
        self.memoryMonitor = memoryMonitor
        self.serverResolver = serverResolver
    }

    /// Connect the coordinator to the host's editor controller, annotations
    /// hub, and the closure that returns the current document URI. Called
    /// once by `AppState` after all three are constructed.
    func attach(
        controller: EditorController,
        hub: AnnotationsHub,
        activeURI: @escaping @MainActor () -> String?
    ) {
        self.controller = controller
        self.hub = hub
        self.activeURI = activeURI
    }

    /// Resolve sourcekit-lsp, register it with `LSPManager`, then start. Sets
    /// `state` through `.starting` → `.initializing` → `.running` or
    /// transitions to `.failed` on any error.
    func start(workspaceRoot: URL?) async {
        guard case .off = state else { return }
        state = .starting

        guard let serverURL = await serverResolver() else {
            // Surface a `CodeEditorError` with a built-in recovery suggestion.
            // The framework's `LocalizedError` conformance carries the user-
            // facing copy; the coordinator just renders it.
            let error = CodeEditorError.languageServerNotAvailable("Swift")
            state = .failed(message: Self.userFacingMessage(for: error))
            resolvedServerPath = nil
            return
        }
        resolvedServerPath = serverURL

        // The framework's LSPClientRegistry requires a non-nil workspaceRoot
        // to start a server. When the host hasn't picked one, fall back to a
        // sample-owned scratch directory under the system temp dir — the
        // mirror writes shadow files there too, so a single root drives both
        // the LSP root URI and the mirror.
        let effectiveRoot: URL = workspaceRoot ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("CodeEditorSample-LSP")
        try? FileManager.default.createDirectory(
            at: effectiveRoot, withIntermediateDirectories: true
        )

        let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: effectiveRoot)
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
            // Map low-level errors back through `CodeEditorError` so the
            // inspector can show the framework's recoverySuggestion alongside
            // the raw cause.
            let wrapped = CodeEditorError.languageServerCommunicationFailed(error.localizedDescription)
            lastError = Self.userFacingMessage(for: wrapped)
            state = .failed(message: error.localizedDescription)
            return
        }

        let caps = ServerCapabilitiesSummary(manager.client(for: "swift")?.serverCapabilities)
        state = .running(capabilities: caps)

        // Register the framework's `LSPCompletionProvider` with the editor's
        // completion manager so trigger characters fire LSP-backed
        // completions in the running session.
        if let controller {
            let provider = LSPCompletionProvider(lspManager: manager, supportedLanguages: [.swift])
            controller.registerCompletionProvider(provider)
            self.lspCompletionProvider = provider
        }

        // Mirror Swift documents under the same root so the LSP's idea of
        // the workspace and the on-disk shadow files agree.
        let mirror = DocumentMirror(rootDirectory: effectiveRoot)
        mirror.cleanupStaleShadows()
        self.mirror = mirror

        // Bridge diagnostics into the gutter + temporary attributes overlay.
        if let client = manager.client(for: "swift"),
           let hub,
           let controller,
           let activeURI {
            let bridge = DiagnosticsBridge(
                diagnosticsPublisher: client.$diagnostics.eraseToAnyPublisher(),
                hub: hub,
                applyDecoration: { [weak controller] attributes, range in
                    controller?.applyTemporaryAttributes(attributes, to: range)
                },
                clearAllDecorations: { [weak controller] in
                    controller?.clearAllTemporaryAttributes()
                },
                activeURI: activeURI
            ) { [weak controller] lspRange in
                controller?.nsRange(forLSPRange: lspRange)
            }
            bridge.start()
            self.bridge = bridge
        }
    }

    /// Stop the language server and reset state. Safe to call when already
    /// `.off`.
    func stop() async {
        guard state != .off else { return }
        bridge?.stop()
        bridge = nil
        if let provider = lspCompletionProvider {
            controller?.unregisterCompletionProvider(withId: provider.id)
            lspCompletionProvider = nil
        }
        mirror = nil
        manager?.stopLanguageServer(for: "swift")
        manager = nil
        diagnosticCounts = .zero
        state = .off
    }

    // MARK: - Document lifecycle

    /// Open a Swift tab into the LSP session: write a shadow file via the
    /// mirror and send `textDocument/didOpen`. Returns the shadow URL on
    /// success, nil if LSP isn't running or `language != .swift`.
    @discardableResult
    func openTab(id: UUID, text: String, language: Language) async -> URL? {
        guard language == .swift,
              let manager,
              let mirror,
              case .running = state else {
            return nil
        }
        guard let url = try? mirror.openTab(id: id, text: text, fileExtension: "swift") else {
            return nil
        }
        try? await manager.openDocument(filePath: url.path, content: text, languageId: "swift")
        // Point the LSP completion provider at the freshly-opened shadow so
        // trigger-character completions land in the right file.
        lspCompletionProvider?.updateContext(filePath: url.path, text: text)
        return url
    }

    /// Forward a buffer change. Debounced inside the mirror; the manager
    /// receives a full-sync `textDocument/didChange` after the quiet period.
    func handleTextChange(id: UUID, newText: String) {
        guard let mirror,
              let url = mirror.url(for: id) else { return }
        mirror.handleTextChange(id: id, newText: newText)
        Task { [weak self] in
            try? await self?.manager?.updateDocument(filePath: url.path, content: newText)
        }
        // Keep the LSP completion provider's cached text in sync.
        lspCompletionProvider?.updateContext(filePath: url.path, text: newText)
    }

    /// Tear down a tab from the LSP session and delete its shadow file.
    func closeTab(id: UUID) {
        guard let mirror,
              let url = mirror.url(for: id) else { return }
        Task { [weak self] in
            try? await self?.manager?.closeDocument(filePath: url.path)
            await MainActor.run { mirror.closeTab(id: id) }
        }
    }

    /// Shadow URL for a tab, if open.
    func mirrorURL(for id: UUID) -> URL? {
        mirror?.url(for: id)
    }

    // MARK: - Language features

    /// Request hover content for the given position in the named tab.
    /// Returns nil if LSP isn't running, the document isn't open, or the
    /// server has no information for the position.
    func requestHover(at position: SourcePosition, in tabID: UUID) async -> Hover? {
        guard let manager,
              let mirror,
              let url = mirror.url(for: tabID) else { return nil }
        return try? await manager.requestHover(
            filePath: url.path,
            line: position.line,
            character: position.character
        )
    }

    /// Request definition locations for the given position. Returns an empty
    /// array on miss or when LSP isn't running.
    func requestDefinition(at position: SourcePosition, in tabID: UUID) async -> [Location] {
        guard let manager,
              let mirror,
              let url = mirror.url(for: tabID) else { return [] }
        return (try? await manager.requestDefinition(
            filePath: url.path,
            line: position.line,
            character: position.character
        )) ?? []
    }

    enum DefinitionTarget: Equatable {
        case openInWorkspace(url: URL, line: Int)
        case toast(message: String)
        case empty
    }

    /// Closure injected by `AppState` so the coordinator can open a tab via
    /// the app's `EditorDocuments` without depending on it directly.
    /// Returns the new document's id when the open succeeded.
    var onRequestOpen: ((URL) -> UUID?)?

    /// Closure injected by `AppState` to scroll the active tab to a line.
    var onRequestScroll: ((Int) -> Void)?

    /// Workspace root used for in/out-of-scope checks. Tracked separately
    /// so it can change without restarting the coordinator.
    var currentWorkspaceRoot: URL?

    func jumpToDefinition(at position: SourcePosition, in tabID: UUID) async {
        let locations = await requestDefinition(at: position, in: tabID)
        let target = Self.resolveDefinitionTarget(
            locations: locations,
            workspaceRoot: currentWorkspaceRoot
        )
        apply(target: target)
    }

    /// Pure resolver — picks the first location and classifies the jump as
    /// in-workspace (open + scroll), out-of-workspace (toast), or none.
    static func resolveDefinitionTarget(
        locations: [Location],
        workspaceRoot: URL?
    ) -> DefinitionTarget {
        guard let first = locations.first else { return .empty }
        guard let uri = URL(string: first.uri) else {
            return .toast(message: "Could not parse definition URI: \(first.uri)")
        }
        let line = first.range.start.line
        let path = uri.path
        if let root = workspaceRoot, path.hasPrefix(root.path) {
            return .openInWorkspace(url: uri, line: line)
        }
        return .toast(message: "Defined in \(uri.lastPathComponent):\(line)")
    }

    private func apply(target: DefinitionTarget) {
        switch target {
        case let .openInWorkspace(url, line):
            if onRequestOpen?(url) != nil {
                onRequestScroll?(line + 1)  // EditorController.gotoLine is 1-based
            }

        case let .toast(message):
            lastError = message

        case .empty:
            lastError = "No definition found."
        }
    }

    /// Single entry point used by the `.onTextHover` modifier. Dismisses when
    /// the pointer leaves text or the server isn't running; otherwise asks
    /// for hover content and posts to the popover.
    func handleHover(at position: SourcePosition?, in tabID: UUID) async {
        guard case .running = state else {
            hoverSession.dismiss()
            return
        }
        guard let position else {
            hoverSession.dismiss()
            return
        }
        if let hover = await requestHover(at: position, in: tabID) {
            hoverSession.show(markdown: hover.contents.markdownString)
        } else {
            hoverSession.dismiss()
        }
    }

    /// Renders a `CodeEditorError` as a user-facing string that includes the
    /// `recoverySuggestion` when one is available. Centralised here so all
    /// LSP failure paths surface the same shape of message.
    private static func userFacingMessage(for error: CodeEditorError) -> String {
        if let suggestion = error.recoverySuggestion, !suggestion.isEmpty {
            return "\(error.errorDescription ?? "\(error)") — \(suggestion)"
        }
        return error.errorDescription ?? "\(error)"
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
