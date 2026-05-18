#if canImport(AppKit)
import CodeEditorAnnotations
import CodeEditorPlugin
@testable import CodeEditorSample
@testable import CodeEditorView
import XCTest

final class AnnotationsHubDiagnosticsTests: XCTestCase {
    @MainActor
    func testReplaceDiagnosticAnnotationsKeepsBreakpoints() {
        let hub = AnnotationsHub()
        hub.toggleBreakpoint(at: 5)

        let diagnostic = Annotation(
            range: NSRange(location: 0, length: 1),
            content: "ERROR: type mismatch",
            id: "diag-1"
        )
        hub.replaceDiagnosticAnnotations([diagnostic])

        XCTAssertTrue(hub.breakpointLines.contains(5))
        XCTAssertEqual(hub.diagnosticAnnotations.count, 1)
        XCTAssertEqual(hub.diagnosticAnnotations.first?.content, "ERROR: type mismatch")
    }

    @MainActor
    func testReplaceDiagnosticAnnotationsClearsPreviousDiagnostics() {
        let hub = AnnotationsHub()
        let first = Annotation(
            range: NSRange(location: 0, length: 1),
            content: "ERROR: old",
            id: "diag-1"
        )
        let second = Annotation(
            range: NSRange(location: 5, length: 1),
            content: "WARNING: new",
            id: "diag-2"
        )

        hub.replaceDiagnosticAnnotations([first])
        hub.replaceDiagnosticAnnotations([second])

        XCTAssertEqual(hub.diagnosticAnnotations.count, 1)
        XCTAssertEqual(hub.diagnosticAnnotations.first?.content, "WARNING: new")
    }

    @MainActor
    func testAnnotationsForRangeIncludesDiagnostics() {
        let hub = AnnotationsHub()
        let diag = Annotation(
            range: NSRange(location: 0, length: 5),
            content: "ERROR: boom",
            id: "diag-1"
        )
        hub.replaceDiagnosticAnnotations([diag])

        let visible = hub.annotations(for: NSRange(location: 0, length: 10))
        XCTAssertTrue(visible.contains { $0.content == "ERROR: boom" })
    }
}
#endif
