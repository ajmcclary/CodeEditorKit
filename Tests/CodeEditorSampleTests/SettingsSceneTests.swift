#if canImport(AppKit)
@testable import CodeEditorSample
@testable import CodeEditorView
import XCTest

final class SettingsSceneTests: XCTestCase {
    func testSettingsSceneIncludesAllKnobCategories() {
        XCTAssertEqual(
            SettingsScene.Category.allCases.map(\.rawValue),
            [
                "display",
                "layout",
                "behavior",
                "performance",
                "workspace",
                "annotations",
                "theme"
            ]
        )
    }
}
#endif
