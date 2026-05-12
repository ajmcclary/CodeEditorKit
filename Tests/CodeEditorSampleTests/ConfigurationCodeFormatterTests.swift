import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

final class ConfigurationCodeFormatterTests: XCTestCase {
    func testRendersDisplayRangeStorePrimaryFlag() {
        var configuration = EditorConfiguration()
        configuration.display.useRangeStoreHighlighting = true

        let rendered = ConfigurationCodeFormatter.render(configuration)

        XCTAssertTrue(rendered.contains("config.display.useRangeStoreHighlighting = true"))
    }

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

    func testRendersTextContainerInset() {
        var configuration = EditorConfiguration()
        configuration.layout.textContainerInset = FrameworkEdgeInsets(
            top: 12,
            left: 3.5,
            bottom: 4,
            right: 8
        )

        let rendered = ConfigurationCodeFormatter.render(configuration)

        XCTAssertTrue(rendered.contains(
            "config.layout.textContainerInset = FrameworkEdgeInsets(top: 12, left: 3.50, bottom: 4, right: 8)"
        ))
    }

    func testEscapesWorkspaceRootPath() {
        var configuration = EditorConfiguration()
        configuration.workspaceRoot = URL(fileURLWithPath: "/tmp/Project \"A\" \\ Beta")

        let rendered = ConfigurationCodeFormatter.render(configuration)

        XCTAssertTrue(rendered.contains(
            #"config.workspaceRoot = URL(fileURLWithPath: "/tmp/Project \"A\" \\ Beta")"#
        ))
    }
}
