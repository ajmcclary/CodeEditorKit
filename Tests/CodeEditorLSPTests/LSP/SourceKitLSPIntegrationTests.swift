#if canImport(AppKit)
@testable import CodeEditorLSP
import Foundation
import XCTest

/// Drives the installed sourcekit-lsp through a full session. Skipped when
/// `xcrun --find sourcekit-lsp` finds nothing.
@MainActor
final class SourceKitLSPIntegrationTests: XCTestCase {
    private static func sourceKitLSPPath() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["--find", "sourcekit-lsp"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let path = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let path, !path.isEmpty, access(path, X_OK) == 0 else { return nil }
        return path
    }

    func testInitializeOpenHoverCompleteShutdown() async throws {
        guard let serverPath = Self.sourceKitLSPPath() else {
            throw XCTSkip("sourcekit-lsp not found")
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SourceKitLSPIntegration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = """
        struct Foo {
            func greet(name: String, times: Int) -> String { name }
        }

        let f = Foo()
        f.
        """
        let fileURL = root.appendingPathComponent("b.swift")
        try source.write(to: fileURL, atomically: true, encoding: .utf8)
        let uri = fileURL.absoluteString

        let client = LSPClient(transport: ProcessTransport(executablePath: serverPath, workingDirectory: root))
        await client.setupMessageHandler()
        try await client.connect(configuration: LSPClient.ServerConfiguration(
            languageId: "swift",
            serverPath: serverPath,
            workspaceRoot: root
        ))
        XCTAssertEqual(client.connectionState, .initialized)
        XCTAssertEqual(client.serverCapabilities?.hoverProvider, true)

        try await client.openDocument(uri: uri, languageId: "swift", version: 1, text: source)

        // Blank space: sourcekit-lsp answers `"result": null`.
        let blankHover = try await client.requestHover(uri: uri, position: Position(line: 3, character: 0))
        XCTAssertNil(blankHover)

        let completion = try await client.requestCompletion(uri: uri, position: Position(line: 5, character: 2))
        XCTAssertTrue(
            completion.items.contains { $0.label.hasPrefix("greet") },
            "completion items: \(completion.items.prefix(10).map(\.label))"
        )

        let symbols = try await client.requestDocumentSymbols(uri: uri)
        XCTAssertTrue(symbols.contains { $0.name == "Foo" }, "symbols: \(symbols.map(\.name))")

        client.disconnect()
        for _ in 0..<500 where client.connectionState != .disconnected {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(client.connectionState, .disconnected)
    }
}
#endif
