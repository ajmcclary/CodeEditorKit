#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
@testable import CodeEditorSample
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class FindReplaceOverlaySnapshotTests: XCTestCase {
    func testIdleNoQuery() {
        let model = FindReplaceModel()
        let view = overlay(model: model, isReadOnly: false)
        assertSnapshot(of: host(view), as: .image, named: "idle-no-query")
    }

    func testWithMatches() {
        let model = FindReplaceModel()
        model.findText = "search"
        model.replaceText = "replace"
        model.applyMockCounts(match: 7, position: 2)
        let view = overlay(model: model, isReadOnly: false)
        assertSnapshot(of: host(view), as: .image, named: "with-matches")
    }

    func testZeroMatches() {
        let model = FindReplaceModel()
        model.findText = "nothing"
        let view = overlay(model: model, isReadOnly: false)
        assertSnapshot(of: host(view), as: .image, named: "zero-matches")
    }

    func testOptionsExpanded() {
        let model = FindReplaceModel()
        model.isOptionsExpanded = true
        let view = overlay(model: model, isReadOnly: false)
        assertSnapshot(of: host(view), as: .image, named: "options-expanded")
    }

    func testOptionsExpandedCaseAndRegexOn() {
        let model = FindReplaceModel()
        model.isOptionsExpanded = true
        model.options.caseSensitive = true
        model.options.useRegularExpression = true
        let view = overlay(model: model, isReadOnly: false)
        assertSnapshot(of: host(view), as: .image, named: "options-expanded-case-regex-on")
    }

    func testInvalidRegex() {
        let model = FindReplaceModel()
        model.findText = "[invalid"
        model.options.useRegularExpression = true
        model.applyMockError(.invalidRegex)
        let view = overlay(model: model, isReadOnly: false)
        assertSnapshot(of: host(view), as: .image, named: "invalid-regex")
    }

    func testReadOnlyConfig() {
        let model = FindReplaceModel()
        model.findText = "search"
        model.applyMockCounts(match: 3, position: 1)
        let view = overlay(model: model, isReadOnly: true)
        assertSnapshot(of: host(view), as: .image, named: "read-only")
    }

    // MARK: - Helpers

    private func overlay(model: FindReplaceModel, isReadOnly: Bool) -> FindReplaceOverlay {
        FindReplaceOverlay(
            model: model,
            controller: EditorController(),
            isReadOnly: isReadOnly
        )
    }

    private func host<V: View>(_ view: V) -> NSView {
        let hosting = NSHostingView(
            rootView: view
                .frame(width: 540)
                .padding()
                .background(Color.white)
                .foregroundColor(.black)
                .environment(\.colorScheme, .light)
        )
        hosting.frame = CGRect(x: 0, y: 0, width: 560, height: 140)
        return hosting
    }
}
#endif
