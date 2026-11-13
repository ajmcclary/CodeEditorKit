@testable import CodeEditorLSP
import Foundation
import XCTest

/// Payloads captured from sourcekit-lsp (Xcode 27), trimmed. They omit the
/// spec-optional fields the client used to require.
enum CapturedSourceKitPayloads {
    static let initializeResult = #"""
    {"capabilities": {"documentSymbolProvider": true, "foldingRangeProvider": true,
     "textDocumentSync": {"save": {"includeText": false}, "willSaveWaitUntil": false, "openClose": true, "change": 2, "willSave": true},
     "hoverProvider": true, "documentFormattingProvider": {"workDoneProgress": false},
     "completionProvider": {"triggerCharacters": ["."], "resolveProvider": true},
     "codeLensProvider": {}, "definitionProvider": true, "renameProvider": {"prepareProvider": true}}}
    """#

    static let completionList = #"""
    {"isIncomplete": true, "items": [
     {"insertTextFormat": 1, "data": {"itemId": 0, "sessionId": 0, "uri": "file:///tmp/proj/b.swift"}, "label": "self",
      "detail": "Foo", "sortText": "4998.58250000-self", "deprecated": false, "kind": 14, "filterText": "self", "insertText": "self",
      "textEdit": {"newText": "self", "range": {"end": {"line": 5, "character": 2}, "start": {"line": 5, "character": 2}}}},
     {"insertTextFormat": 2, "data": {"itemId": 1, "sessionId": 0, "uri": "file:///tmp/proj/b.swift"},
      "label": "greet(name: String, times: Int)", "detail": "String", "sortText": "4998.54706250-greet(name: String, times: Int)",
      "deprecated": false, "kind": 2, "filterText": "greet(name:times:)", "insertText": "greet(name: ${1:String}, times: ${2:Int})",
      "textEdit": {"newText": "greet(name: ${1:String}, times: ${2:Int})", "range": {"end": {"line": 5, "character": 2}, "start": {"line": 5, "character": 2}}}}]}
    """#

    static let publishDiagnostics = #"""
    {"uri": "file:///tmp/proj/b.swift", "diagnostics": [{"tags": [], "source": "SourceKit", "severity": 1,
     "range": {"end": {"line": 5, "character": 1}, "start": {"line": 5, "character": 1}}, "message": "Expected member name following '.'"}]}
    """#

    static let documentSymbols = #"""
    [{"children": [{"kind": 6, "children": [], "selectionRange": {"end": {"character": 40, "line": 1}, "start": {"character": 9, "line": 1}},
       "range": {"end": {"character": 59, "line": 1}, "start": {"line": 1, "character": 4}}, "name": "greet(name:times:)"}],
      "range": {"start": {"line": 0, "character": 0}, "end": {"line": 2, "character": 1}}, "name": "Foo", "kind": 23,
      "selectionRange": {"start": {"line": 0, "character": 7}, "end": {"line": 0, "character": 10}}},
     {"children": [], "range": {"end": {"character": 13, "line": 4}, "start": {"character": 0, "line": 4}}, "name": "f", "kind": 13,
      "selectionRange": {"end": {"character": 5, "line": 4}, "start": {"character": 4, "line": 4}}}]
    """#
}

/// An in-memory server that behaves like sourcekit-lsp where it matters:
/// after `initialized` it sends `client/registerCapability` and answers
/// nothing else until the client replies to it.
actor ScriptedLSPServerTransport: LSPTransport {
    private var dataHandler: (@Sendable (Data) async -> Void)?
    private var disconnectHandler: (@Sendable () async -> Void)?
    private var connected = false
    private var blockedUntilReply: String?
    private var heldRequests: [[String: Any]] = []
    private(set) var clientReplyData: [Data] = []
    private(set) var clientNotifications: [String] = []
    /// Methods the server never answers (to exercise timeouts / loss).
    var silentMethods: Set<String> = []
    private(set) var receivedMethods: [String] = []

    var isConnected: Bool { connected }

    func connect() async throws { connected = true }

    func disconnect() async { connected = false }

    func receive() async throws -> Data { throw LSPTransportError.notConnected }

    func setDataHandler(_ handler: @escaping @Sendable (Data) async -> Void) async {
        dataHandler = handler
    }

    func setDisconnectHandler(_ handler: @escaping @Sendable () async -> Void) async {
        disconnectHandler = handler
    }

    func setSilent(_ methods: Set<String>) { silentMethods = methods }

    /// Simulates the server process exiting.
    func simulateServerExit() async {
        connected = false
        await disconnectHandler?()
    }

    /// Sends a server→client request.
    func sendServerRequest(id: String, method: String, paramsJSON: String) async {
        await deliverRaw(#"{"jsonrpc":"2.0","id":"\#(id)","method":"\#(method)","params":\#(paramsJSON)}"#)
    }

    func send(_ data: Data) async throws {
        guard connected else { throw LSPTransportError.notConnected }
        guard let message = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let method = message["method"] as? String {
            receivedMethods.append(method)
            if message["id"] == nil {
                clientNotifications.append(method)
                if method == "initialized" {
                    blockedUntilReply = "sk-0"
                    await sendServerRequest(
                        id: "sk-0",
                        method: "client/registerCapability",
                        paramsJSON: #"{"registrations":[{"id":"r1","method":"workspace/didChangeWatchedFiles"}]}"#
                    )
                }
                return
            }
            if blockedUntilReply != nil {
                heldRequests.append(message)
            } else {
                await answer(message)
            }
            return
        }
        // A reply to one of our requests.
        clientReplyData.append(data)
        if let id = message["id"] as? String, id == blockedUntilReply {
            blockedUntilReply = nil
            let held = heldRequests
            heldRequests.removeAll()
            for request in held {
                await answer(request)
            }
        }
    }

    private func answer(_ request: [String: Any]) async {
        guard let method = request["method"] as? String, let id = request["id"] else { return }
        if silentMethods.contains(method) { return }
        let result: String
        switch method {
        case "initialize":
            result = CapturedSourceKitPayloads.initializeResult

        case "textDocument/hover", "textDocument/definition", "shutdown":
            result = "null"

        case "textDocument/completion":
            result = CapturedSourceKitPayloads.completionList

        case "textDocument/documentSymbol":
            result = CapturedSourceKitPayloads.documentSymbols

        default:
            result = "null"
        }
        let idJSON = (try? JSONSerialization.data(withJSONObject: id, options: [.fragmentsAllowed]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "null"
        await deliverRaw(#"{"jsonrpc":"2.0","id":\#(idJSON),"result":\#(result)}"#)
    }

    func deliverNotification(method: String, paramsJSON: String) async {
        await deliverRaw(#"{"jsonrpc":"2.0","method":"\#(method)","params":\#(paramsJSON)}"#)
    }

    private func deliverRaw(_ json: String) async {
        await dataHandler?(LSPFrameCodec.encode(Data(json.utf8)))
    }
}

@MainActor
final class LSPClientServerInteractionTests: XCTestCase {
    private func replies(from server: ScriptedLSPServerTransport) async -> [[String: Any]] {
        await server.clientReplyData.compactMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    private func connectedClient(_ server: ScriptedLSPServerTransport) async throws -> LSPClient {
        let client = LSPClient(transport: server)
        await client.setupMessageHandler()
        try await client.connect(configuration: LSPClient.ServerConfiguration(
            languageId: "swift",
            serverPath: "scripted",
            workspaceRoot: URL(fileURLWithPath: "/tmp/proj")
        ))
        return client
    }

    private func waitUntil(_ condition: @escaping () async -> Bool) async {
        for _ in 0..<3_000 where !(await condition()) { // 30 s: a failure to arrive
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func testClientAnswersRegisterCapabilityAndRequestsThenComplete() async throws {
        let server = ScriptedLSPServerTransport()
        let client = try await connectedClient(server)
        XCTAssertEqual(client.connectionState, .initialized)
        XCTAssertEqual(client.serverCapabilities?.hoverProvider, true)
        XCTAssertEqual(client.serverCapabilities?.completionProvider?.triggerCharacters, ["."])

        let uri = "file:///tmp/proj/b.swift"
        let hover = try await client.requestHover(uri: uri, position: Position(line: 0, character: 0))
        XCTAssertNil(hover, "a null hover result is no hover")

        let completion = try await client.requestCompletion(uri: uri, position: Position(line: 5, character: 2))
        XCTAssertEqual(completion.items.map(\.label), ["self", "greet(name: String, times: Int)"])
        XCTAssertEqual(completion.items.last?.insertTextFormat, .snippet)

        let symbols = try await client.requestDocumentSymbols(uri: uri)
        XCTAssertEqual(symbols.map(\.name), ["Foo", "f"])
        XCTAssertEqual(symbols.first?.children.first?.tags, [])

        let definition = try await client.requestDefinition(uri: uri, position: Position(line: 0, character: 0))
        XCTAssertEqual(definition.count, 0)

        let replies = await replies(from: server)
        XCTAssertEqual(replies.count, 1)
        XCTAssertEqual(replies.first?["id"] as? String, "sk-0")
        XCTAssertTrue(replies.first?["result"] is NSNull)
        client.disconnect()
    }

    func testPublishedDiagnosticsWithoutOptionalFieldsAreKept() async throws {
        let server = ScriptedLSPServerTransport()
        let client = try await connectedClient(server)
        await server.deliverNotification(
            method: "textDocument/publishDiagnostics",
            paramsJSON: CapturedSourceKitPayloads.publishDiagnostics
        )
        await waitUntil { await MainActor.run { !client.diagnostics.isEmpty } }
        let diagnostics = client.diagnostics["file:///tmp/proj/b.swift"]
        XCTAssertEqual(diagnostics?.count, 1)
        XCTAssertEqual(diagnostics?.first?.severity, .error)
        XCTAssertEqual(diagnostics?.first?.relatedInformation.count, 0)
        client.disconnect()
    }

    func testUnknownServerRequestIsRejectedAndConfigurationGetsNulls() async throws {
        let server = ScriptedLSPServerTransport()
        let client = try await connectedClient(server)
        await waitUntil { await server.clientReplyData.count == 1 }

        await server.sendServerRequest(id: "x-1", method: "workspace/applyEdit", paramsJSON: #"{"edit":{}}"#)
        await server.sendServerRequest(
            id: "x-2",
            method: "workspace/configuration",
            paramsJSON: #"{"items":[{"section":"a"},{"section":"b"}]}"#
        )
        await waitUntil { await server.clientReplyData.count == 3 }

        let replies = await replies(from: server)
        let applyEdit = replies.first { $0["id"] as? String == "x-1" }
        XCTAssertEqual((applyEdit?["error"] as? [String: Any])?["code"] as? Int, -32_601)
        let configuration = replies.first { $0["id"] as? String == "x-2" }
        XCTAssertEqual((configuration?["result"] as? [Any])?.count, 2)
        XCTAssertTrue((configuration?["result"] as? [Any])?.allSatisfy { $0 is NSNull } ?? false)
        client.disconnect()
    }

    func testServerExitFailsPendingRequestsAndLeavesTheConnection() async throws {
        let server = ScriptedLSPServerTransport()
        let client = try await connectedClient(server)
        await server.setSilent(["textDocument/hover"])

        let hover = Task { @MainActor in
            try await client.requestHover(uri: "file:///tmp/proj/b.swift", position: Position(line: 0, character: 0))
        }
        await waitUntil { await server.receivedMethods.contains("textDocument/hover") }
        await server.simulateServerExit()

        do {
            _ = try await hover.value
            XCTFail("the pending hover must fail when the server exits")
        } catch let error as LSPError {
            guard case .connectionFailed = error else { return XCTFail("unexpected \(error)") }
        }
        await waitUntil { await MainActor.run { client.connectionState == .disconnected } }
        XCTAssertEqual(client.connectionState, .disconnected)
    }

    /// Nothing restarts a server that exits; the host must be able to see
    /// that it did (to offer a restart) after the client settles in
    /// `.disconnected`, which an ordinary stop also ends in.
    func testAnUnexpectedServerExitStaysObservable() async throws {
        let server = ScriptedLSPServerTransport()
        let client = try await connectedClient(server)
        XCTAssertFalse(client.serverExitedUnexpectedly)

        await server.simulateServerExit()
        await waitUntil { await MainActor.run { client.connectionState == .disconnected } }

        XCTAssertTrue(client.serverExitedUnexpectedly)
    }
}
