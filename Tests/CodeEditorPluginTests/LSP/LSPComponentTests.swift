@testable import CodeEditorLSP
import Foundation
import Testing

private actor LSPComponentProbe {
    private(set) var count = 0
    private(set) var methods: [String] = []

    func increment() {
        count += 1
    }

    func record(_ method: String) {
        methods.append(method)
    }
}

@MainActor
@Suite("LSP focused components")
struct LSPComponentTests {
    @Test("connection teardown is idempotent while active")
    func connectionTeardownIdempotence() async {
        let lifecycle = LSPConnectionLifecycle()
        let probe = LSPComponentProbe()

        #expect(lifecycle.beginDisconnect {
            await probe.increment()
            try? await Task.sleep(for: .milliseconds(20))
        })
        #expect(!lifecycle.beginDisconnect {
            await probe.increment()
        })
        while lifecycle.isDisconnecting {
            await Task.yield()
        }

        #expect(await probe.count == 1)
    }

    @Test("document session builds notifications and clears closed diagnostics")
    func documentSessionOwnership() {
        let session = LSPDocumentSession()
        let uri = "file:///tmp/Test.swift"
        let diagnostic = LSPDiagnostic(
            range: LSPRange(
                start: Position(line: 0, character: 0),
                end: Position(line: 0, character: 1)
            ),
            message: "warning"
        )
        session.updateDiagnostics([diagnostic], for: uri)

        let open = session.openParameters(
            uri: uri,
            languageID: "swift",
            version: 1,
            text: "let value = 1"
        )
        let close = session.closeParameters(uri: uri)

        #expect(open.textDocument.uri == uri)
        #expect(close.textDocument.uri == uri)
        #expect(session.diagnostics[uri] == nil)
    }

    @Test("feature client owns request method and response parsing")
    func featureRequestAndParse() async throws {
        let probe = LSPComponentProbe()
        let client = LSPLanguageFeatureClient { method, _ in
            await probe.record(method)
            let dictionary: [String: Any] = [
                "jsonrpc": "2.0",
                "id": 1,
                "result": ["isIncomplete": false, "items": []]
            ]
            return LSPResponse(
                data: try JSONSerialization.data(withJSONObject: dictionary),
                messageDict: dictionary
            )
        }

        let result = try await client.completion(
            uri: "file:///tmp/Test.swift",
            position: Position(line: 0, character: 0)
        )

        #expect(result.items.isEmpty)
        #expect(await probe.methods == [LSPLanguageFeatures.Methods.completion])
    }
}
