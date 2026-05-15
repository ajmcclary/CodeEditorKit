#if canImport(AppKit)
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

@MainActor
final class DocumentsModelTests: XCTestCase {
    func testAttachAnnotationsInstallsDataSourceAfterControllerAttaches() {
        let model = DocumentsModel(workspaceRootProvider: { nil })
        let hub = AnnotationsHub()

        model.attachAnnotations(hub)

        XCTAssertFalse(
            model.editorController.isAttached,
            "Freshly-constructed controller should be unattached."
        )

        let view = CodeEditorView(frame: .zero)
        model.editorController.attach(to: view)

        XCTAssertTrue(
            model.editorController.isAttached,
            "Controller should be attached after attach(to:)."
        )

        XCTAssertIdentical(
            view.annotationsDataSource,
            hub,
            "AnnotationsHub must be installed as the view's data source after attach."
        )
    }

    func testHandleSaveOutcomeAcceptsAllCases() {
        let model = DocumentsModel(workspaceRootProvider: { nil })
        model.handleSaveOutcome(.saved(url: URL(fileURLWithPath: "/tmp/x")))
        model.handleSaveOutcome(.untitled)
        model.handleSaveOutcome(.noTab)
        model.handleSaveOutcome(
            .failed(error: NSError(domain: "test", code: 0))
        )
    }
}
#endif
