#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
@testable import CodeEditorView
import SwiftUI
import XCTest

/// Behavioral tests for `LSPInspectorPanel`. Snapshot tests are deferred —
/// the integration smoke test covers visual rendering against a live server.
final class LSPInspectorPanelTests: XCTestCase {
    @MainActor
    func testOffStateAcceptsToggleCall() {
        var toggled = false
        let panel = LSPInspectorPanel(
            state: .off,
            counts: .zero,
            serverPath: nil,
            lastError: nil,
            isSwiftActive: true
        ) { toggled = true }
        _ = panel.body
        XCTAssertFalse(toggled)  // body render doesn't fire the toggle
    }

    @MainActor
    func testRunningStateAcceptsCapabilities() {
        let capabilities = ServerCapabilitiesSummary(
            hasHover: true,
            hasDefinition: true,
            hasDiagnostics: true,
            hasDocumentSymbols: true,
            hasCompletion: false
        )
        let panel = LSPInspectorPanel(
            state: .running(capabilities: capabilities),
            counts: .init(),
            serverPath: URL(fileURLWithPath: "/fake/sourcekit-lsp"),
            lastError: nil,
            isSwiftActive: true
        ) {}
        _ = panel.body
    }

    @MainActor
    func testFailedStateRenders() {
        let panel = LSPInspectorPanel(
            state: .failed(message: "sourcekit-lsp not found"),
            counts: .zero,
            serverPath: nil,
            lastError: nil,
            isSwiftActive: true
        ) {}
        _ = panel.body
    }
}
#endif
