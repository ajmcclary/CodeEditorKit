#if canImport(AppKit)
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import Combine
import XCTest

/// Regression test for the silent-no-op bug at AppState.swift:102
/// (before the onAttach migration): calling
/// `editorController.setAnnotationsDataSource(hub)` on an unattached
/// controller did nothing. After the migration the install is deferred
/// until the SwiftUI representable's attach hook fires; this test
/// reproduces that flow and asserts the data source is wired.
///
/// Related: docs/superpowers/specs/2026-05-14-editor-controller-onattach-design.md
@MainActor
final class AnnotationsHubInstallTests: XCTestCase {
    func testHubInstalledAsDataSourceAfterAttach() {
        // Construct AppState the way the app does — eager
        // editorController, AnnotationsHub, onAttach registration.
        let appState = AppState()

        // Pre-attach, the controller's underlying view is nil, so the
        // hub is NOT yet installed as a data source anywhere. The
        // attachToken inside AppState is now alive and waiting.
        XCTAssertFalse(
            appState.editorController.isAttached,
            "Freshly-constructed controller should be unattached."
        )

        // Simulate what the SwiftUI representable does: build a
        // CodeEditorView and run attach(to:).
        let view = CodeEditorView(frame: .zero)
        appState.editorController.attach(to: view)

        XCTAssertTrue(
            appState.editorController.isAttached,
            "Controller should be attached after attach(to:)."
        )

        // The annotations data source should now be the hub.
        XCTAssertIdentical(
            view.annotationsDataSource,
            appState.annotationsHub,
            "AnnotationsHub must be installed as the view's data source after attach."
        )
    }
}
#endif
