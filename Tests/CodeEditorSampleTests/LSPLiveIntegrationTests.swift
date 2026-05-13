#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

/// End-to-end smoke test that requires real sourcekit-lsp on PATH. Gated
/// behind the `CODE_EDITOR_LSP_LIVE` environment variable so CI doesn't
/// fail when Xcode/sourcekit-lsp is unavailable.
///
/// To run locally: `CODE_EDITOR_LSP_LIVE=1 swift test --filter LSPLiveIntegrationTests`.
final class LSPLiveIntegrationTests: XCTestCase {
    @MainActor
    func testDiagnosticAppearsForKnownTypeError() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CODE_EDITOR_LSP_LIVE"] == "1",
            "Set CODE_EDITOR_LSP_LIVE=1 to run live sourcekit-lsp tests."
        )

        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("LSPLive-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let appState = AppState()
        appState.workspaceRoot = workspace

        await appState.lsp.start(workspaceRoot: workspace)
        guard case .running = appState.lsp.state else {
            XCTFail("LSP failed to start: \(appState.lsp.state)")
            return
        }

        let tabID = UUID()
        let badText = "let x: Int = \"oops\"\n"
        _ = await appState.lsp.openTab(id: tabID, text: badText, language: .swift)

        // Poll up to 10 seconds for diagnostics to land in the hub.
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if !appState.annotationsHub.diagnosticAnnotations.isEmpty { break }
            try await Task.sleep(nanoseconds: 250_000_000)
        }

        XCTAssertFalse(
            appState.annotationsHub.diagnosticAnnotations.isEmpty,
            "expected at least one diagnostic from sourcekit-lsp"
        )
        XCTAssertTrue(
            appState.annotationsHub.diagnosticAnnotations.contains { $0.content.hasPrefix("ERROR:") },
            "expected at least one error-severity diagnostic"
        )

        await appState.lsp.stop()
    }
}
#endif
