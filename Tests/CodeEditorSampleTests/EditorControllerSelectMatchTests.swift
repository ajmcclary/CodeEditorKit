#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import CodeEditorSearch
@testable import CodeEditorView
import Foundation
import Testing

@MainActor
@Suite("EditorController.selectMatch")
struct EditorControllerSelectMatchTests {
    private func makeAttached(text: String) -> (EditorController, CodeEditorView) {
        let view = CodeEditorView(frame: .zero)
        view.string = text
        let controller = EditorController()
        controller.attach(to: view)
        return (controller, view)
    }

    @Test("selects the matched substring on the indexed line")
    func selectsMatchedSubstring() {
        let text = "line one\nlet foo = 1\nlast line"
        let (controller, view) = makeAttached(text: text)
        let result = ProjectSearchResult(
            fileURL: URL(fileURLWithPath: "/tmp/x.swift"),
            lineNumber: 2,
            column: 5,
            matchedText: "foo",
            contextLine: "let foo = 1"
        )

        let ok = controller.selectMatch(result)

        #expect(ok)
        let nsText = text as NSString // swiftlint:disable:this legacy_objc_type
        let expectedRange = nsText.range(of: "foo")
        #expect(view.selectedRange() == expectedRange)
    }

    @Test("returns false when the line is out of range")
    func outOfRangeReturnsFalse() {
        let text = "single line"
        let (controller, _) = makeAttached(text: text)
        let result = ProjectSearchResult(
            fileURL: URL(fileURLWithPath: "/tmp/x.swift"),
            lineNumber: 99,
            column: 1,
            matchedText: "x",
            contextLine: ""
        )

        let ok = controller.selectMatch(result)

        #expect(!ok)
    }
}
#endif
