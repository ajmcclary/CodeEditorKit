import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

final class ConfigurationCodeFormatterTests: XCTestCase {
    func testRendersRangeBasedHighlightingFlag() {
        var configuration = EditorConfiguration()
        configuration.performance.usesRangeBasedHighlighting = true

        let rendered = ConfigurationCodeFormatter.render(configuration)

        XCTAssertTrue(rendered.contains("config.performance.usesRangeBasedHighlighting = true"))
    }

    func testRendersTreeSitterHighlightingFlag() {
        var configuration = EditorConfiguration()
        configuration.behavior.useTreeSitterHighlighting = true

        let rendered = ConfigurationCodeFormatter.render(configuration)

        XCTAssertTrue(rendered.contains("config.behavior.useTreeSitterHighlighting = true"))
    }
}
