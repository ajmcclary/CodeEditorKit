@testable import CodeEditorLSP
import Foundation
import Testing

/// Spec-optional fields are optional: real server payloads that omit them,
/// or use the alternative shapes the spec allows, decode.
@Suite struct LSPWireDecodingTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    @Test func capturedSourceKitPayloadsDecode() throws {
        let initialize = try decode(InitializeResult.self, CapturedSourceKitPayloads.initializeResult)
        #expect(initialize.capabilities.textDocumentSync?.change == .incremental)
        #expect(initialize.capabilities.definitionProvider)

        let diagnostics = try decode(PublishDiagnosticsParams.self, CapturedSourceKitPayloads.publishDiagnostics)
        #expect(diagnostics.diagnostics.count == 1)

        let completion = try decode(CompletionList.self, CapturedSourceKitPayloads.completionList)
        #expect(completion.items.count == 2)
        #expect(completion.items.first?.additionalTextEdits.isEmpty == true)

        let symbols = try decode([LSPDocumentSymbol].self, CapturedSourceKitPayloads.documentSymbols)
        #expect(symbols.count == 2)
        #expect(symbols.last?.detail == nil)
    }

    @Test func serverCapabilitiesAcceptOptionObjectsAndBareSyncKind() throws {
        let capabilities = try decode(
            ServerCapabilities.self,
            #"{"textDocumentSync": 2, "hoverProvider": {}, "definitionProvider": {"workDoneProgress": true}}"#
        )
        #expect(capabilities.textDocumentSync?.change == .incremental)
        #expect(capabilities.hoverProvider)
        #expect(capabilities.definitionProvider)
        #expect(!capabilities.documentSymbolProvider)
        #expect(try decode(ServerCapabilities.self, "{}").completionProvider == nil)
    }

    @Test func completionResultMayBeABareArray() throws {
        let list = try decode(CompletionList.self, #"[{"label": "a"}, {"label": "b", "kind": 99}]"#)
        #expect(!list.isIncomplete)
        #expect(list.items.map(\.label) == ["a", "b"])
        #expect(list.items.last?.kind == nil)
    }

    @Test func unknownEnumValuesDoNotFailThePayload() throws {
        let diagnostic = try decode(
            Diagnostic.self,
            #"{"range": {"start": {"line": 0, "character": 0}, "end": {"line": 0, "character": 1}}, "message": "m", "severity": 9, "tags": [1, 7]}"#
        )
        #expect(diagnostic.severity == nil)
        #expect(diagnostic.tags == [.unnecessary])

        let symbol = try decode(
            LSPDocumentSymbol.self,
            #"{"name": "x", "kind": 255, "range": {"start": {"line": 0, "character": 0}, "end": {"line": 0, "character": 1}}, "selectionRange": {"start": {"line": 0, "character": 0}, "end": {"line": 0, "character": 1}}}"#
        )
        #expect(symbol.kind == .variable)
        #expect(symbol.children.isEmpty)
    }

    @Test func serverRequestRepliesAreWellFormed() throws {
        func json(_ reply: LSPServerRequestReply) throws -> [String: Any] {
            try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(reply)) as? [String: Any])
        }
        let register = try json(.reply(to: "client/registerCapability", id: .string("sk-0"), params: Data()))
        #expect(register["id"] as? String == "sk-0")
        #expect(register["result"] is NSNull)

        let progress = try json(.reply(to: "window/workDoneProgress/create", id: .number(3), params: Data()))
        #expect(progress["result"] is NSNull)

        let folders = try json(.reply(
            to: "workspace/workspaceFolders",
            id: .number(4),
            params: Data(),
            workspaceFolders: [WorkspaceFolder(uri: "file:///tmp/p", name: "p")]
        ))
        #expect((folders["result"] as? [[String: Any]])?.first?["name"] as? String == "p")

        let unknown = try json(.reply(to: "workspace/applyEdit", id: .number(5), params: Data()))
        #expect((unknown["error"] as? [String: Any])?["code"] as? Int == -32_601)
        #expect(unknown["result"] == nil)
    }

    @Test func messageHandlerRoutesServerRequestsSeparatelyFromNotifications() async throws {
        actor Inbox {
            var requests: [(RequestId, String)] = []
            var notifications: [String] = []

            func request(_ id: RequestId, _ method: String) { requests.append((id, method)) }
            func notification(_ method: String) { notifications.append(method) }
        }
        let inbox = Inbox()
        let handler = LSPMessageHandler()
        await handler.setServerRequestCallback { id, method, _ in Task { await inbox.request(id, method) } }
        await handler.setNotificationCallback { method, _ in Task { await inbox.notification(method) } }

        let request = #"{"jsonrpc":"2.0","id":"sk-0","method":"client/registerCapability","params":{"registrations":[]}}"#
        let notification = #"{"jsonrpc":"2.0","method":"window/logMessage","params":null}"#
        await handler.processIncomingData(LSPFrameCodec.encode(Data(request.utf8)) + LSPFrameCodec.encode(Data(notification.utf8)))

        for _ in 0..<200 {
            let requestCount = await inbox.requests.count
            let notificationCount = await inbox.notifications.count
            if requestCount == 1 && notificationCount == 1 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        let requests = await inbox.requests
        #expect(requests.map(\.1) == ["client/registerCapability"])
        #expect(requests.first?.0 == .string("sk-0"))
        #expect(await inbox.notifications == ["window/logMessage"])
    }
}
