@testable import CodeEditorLSP
import Foundation
import Testing

@Suite("LSP document manager state")
struct LSPDocumentManagerTests {
    /// A document whose server could not start was never opened by any
    /// server, so it must not be tracked as open (later didChanges would be
    /// sent for it).
    @Test @MainActor func failedServerStartLeavesTheDocumentClosed() async throws {
        let registry = LSPClientRegistry { await LSPClient.createAndSetup() }
        registry.workspaceRoot = URL(fileURLWithPath: "/tmp")
        let manager = LSPDocumentManager(clientRegistry: registry)

        try await manager.openDocument(filePath: "/tmp/a.zz", content: "a", languageId: "no-such-language")

        #expect(manager.getDocument(for: "/tmp/a.zz") == nil)
    }

    /// The app opens a document and, at once, updates the completion
    /// context, which opens it too if it is not open yet. Two opens in
    /// flight for one document must send one `didOpen` (the spec forbids a
    /// second open without a close).
    @Test @MainActor func concurrentOpensOfOneDocumentSendOneDidOpen() async throws {
        let server = ScriptedLSPServerTransport()
        let registry = LSPClientRegistry {
            let client = LSPClient(transport: server)
            await client.setupMessageHandler()
            client.recordingHandler = { _, languageId in
                try? await client.connect(configuration: LSPClient.ServerConfiguration(
                    languageId: languageId,
                    serverPath: "scripted",
                    workspaceRoot: URL(fileURLWithPath: "/tmp/proj")
                ))
            }
            return client
        }
        registry.workspaceRoot = URL(fileURLWithPath: "/tmp/proj")
        registry.registerLanguageServer(.remote(
            languageId: "swift",
            url: try #require(URL(string: "wss://example.invalid/swift")),
            fileExtensions: ["swift"]
        ))
        let manager = LSPDocumentManager(clientRegistry: registry)

        async let first: Void = manager.openDocument(filePath: "/tmp/proj/c.swift", content: "let a = 1", languageId: "swift")
        async let second: Void = manager.openDocument(filePath: "/tmp/proj/c.swift", content: "let a = 1", languageId: "swift")
        _ = try await (first, second)

        let opens = await server.clientNotifications.filter { $0 == "textDocument/didOpen" }.count
        #expect(opens == 1)
        #expect(manager.getDocument(for: "/tmp/proj/c.swift") != nil)
    }

    /// Closing a document whose open is still in flight closes it on the
    /// server once the open completes (it used to find nothing recorded and
    /// return, leaving the server's document open).
    ///
    /// The open is held in flight by a gate in the client factory until the
    /// close has been issued. Two `async let`s did not order them: when the
    /// close ran first it rightly found nothing to close (CI, macOS 27.0).
    @Test @MainActor func closingDuringAnOpenSendsTheClose() async throws {
        let server = ScriptedLSPServerTransport()
        let gate = MainActorGate()
        let registry = LSPClientRegistry {
            await gate.wait()
            let client = LSPClient(transport: server)
            await client.setupMessageHandler()
            client.recordingHandler = { _, languageId in
                try? await client.connect(configuration: LSPClient.ServerConfiguration(
                    languageId: languageId,
                    serverPath: "scripted",
                    workspaceRoot: URL(fileURLWithPath: "/tmp/proj")
                ))
            }
            return client
        }
        registry.workspaceRoot = URL(fileURLWithPath: "/tmp/proj")
        registry.registerLanguageServer(.remote(
            languageId: "swift",
            url: try #require(URL(string: "wss://example.invalid/swift")),
            fileExtensions: ["swift"]
        ))
        let manager = LSPDocumentManager(clientRegistry: registry)

        let path = "/tmp/proj/d.swift"

        let opening = Task { @MainActor in
            try await manager.openDocument(filePath: path, content: "let a = 1", languageId: "swift")
        }
        // The open records itself as in flight, then waits at the gate.
        for _ in 0..<1_000 where !manager.isOpenOrOpening(filePath: path) {
            await Task.yield()
        }
        try #require(manager.isOpenOrOpening(filePath: path))
        try #require(manager.getDocument(for: path) == nil)

        let closing = Task { @MainActor in
            try await manager.closeDocument(filePath: path)
        }
        // Let the close reach its wait for the open before releasing it.
        await Task.yield()
        gate.open()
        try await opening.value
        try await closing.value

        let notifications = await server.clientNotifications
        #expect(notifications.filter { $0 == "textDocument/didOpen" }.count == 1)
        #expect(notifications.filter { $0 == "textDocument/didClose" }.count == 1)
        #expect(manager.getDocument(for: path) == nil)
    }
}

/// Holds its waiters until `open()`; waits after that return at once.
@MainActor
private final class MainActorGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let resumed = waiters
        waiters.removeAll()
        for waiter in resumed {
            waiter.resume()
        }
    }
}
