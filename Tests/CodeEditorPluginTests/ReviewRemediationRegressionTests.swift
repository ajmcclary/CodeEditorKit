@testable import CodeEditorPlugin
import XCTest

@MainActor
final class ReviewRemediationRegressionTests: XCTestCase {
    func testPrivateLayoutSelectorIsNotPresentInTextLayoutFragmentSource() throws {
        let source = try String(
            contentsOfFile: sourcePath("Sources/CodeEditorPlugin/Text/TextLayoutFragment.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("perform(Selector"))
        XCTAssertFalse(source.contains("\"l\" + \"oya\""))
    }

    func testTreeSitterPublicFlagIsNotEnabledByPackage() throws {
        let packageSource = try String(contentsOfFile: sourcePath("Package.swift"), encoding: .utf8)

        XCTAssertFalse(packageSource.contains("CAN_IMPORT_TREE_SITTER"))
        XCTAssertFalse(packageSource.contains("useTreeSitterHighlighting"))
    }

    func testAnnotationAndCodeEditorErrorAreSendable() {
        assertSendable(Annotation(range: NSRange(location: 0, length: 1), content: "note"))
        assertSendable(CodeEditorError.serviceUnavailable("CodeFoldingEngine"))
        assertSendable(CodeEditorError.completionRequestFailed("cancelled"))
    }

    func testConfigurationAssignmentRejectsInvalidConfiguration() {
        let textView = CodeEditorView(frame: .zero)
        let originalConfiguration = textView.configuration

        var invalidConfiguration = originalConfiguration
        invalidConfiguration.display.fontSize = -1

        textView.configuration = invalidConfiguration

        XCTAssertEqual(textView.configuration, originalConfiguration)
        XCTAssertEqual(textView.configuration.display.fontSize, originalConfiguration.display.fontSize)
    }

    func testConfigurationApplyThrowsBeforeMutatingView() {
        let textView = CodeEditorView(frame: .zero)
        let originalConfiguration = textView.configuration

        var invalidConfiguration = originalConfiguration
        invalidConfiguration.layout.tabWidth = 0

        XCTAssertThrowsError(try invalidConfiguration.apply(to: textView))
        XCTAssertEqual(textView.configuration, originalConfiguration)
    }

    func testEmptyLineGeometryStoreRangeQueriesReturnEmptyCollections() {
        let store = LineGeometryStore()

        XCTAssertTrue(store.lineGeometries(in: NSRange(location: 0, length: 0)).isEmpty)
        XCTAssertTrue(store.lineGeometries(inYRange: 0...100).isEmpty)
        XCTAssertNil(store.visibleLineRange(for: CGRect(x: 0, y: 0, width: 100, height: 100)))
    }

    func testCodeFoldingCoordinatorServiceReportsMissingEngineInsteadOfCrashing() {
        let registry = BusinessLogicServiceRegistry()

        XCTAssertThrowsError(try registry.codeFoldingCoordinatorService()) { error in
            guard case CodeEditorError.serviceUnavailable(let serviceName) = error else {
                return XCTFail("Expected serviceUnavailable, got \(error)")
            }
            XCTAssertEqual(serviceName, "CodeFoldingEngine")
        }
    }

    private func assertSendable<T: Sendable>(_: T) {}

    private func sourcePath(_ relativePath: String) -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
            .path
    }
}
