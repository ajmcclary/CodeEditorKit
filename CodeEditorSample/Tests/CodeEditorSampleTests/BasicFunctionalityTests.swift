@testable import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

/// Test without MainActor to see if basic functionality works
final class BasicFunctionalityTests: XCTestCase {
    func testSampleCodeProvider() {
        // Test that sample code is provided for all languages
        for sample in SampleCode.allCases {
            let code = SampleCodeProvider.getCode(for: sample)
            XCTAssertFalse(code.isEmpty, "\(sample) should provide sample code")
            XCTAssertGreaterThan(code.count, 10, "\(sample) should provide substantial code")
        }
    }

    func testEditorConfiguration() {
        // Test configuration creation
        let config = EditorConfiguration()
        XCTAssertTrue(config.display.showLineNumbers)
        XCTAssertTrue(config.behavior.isEditable)
        XCTAssertEqual(config.display.fontSize, 14)
        XCTAssertEqual(config.layout.tabWidth, 4)
    }

    func testConfigurationPresets() {
        // Test all presets
        for preset in ConfigurationPreset.allCases {
            let config = preset.configuration

            switch preset {
            case .fullFeatured:
                XCTAssertTrue(config.display.showLineNumbers)
                XCTAssertTrue(config.behavior.isEditable)

            case .minimal:
                XCTAssertFalse(config.display.showLineNumbers)
                XCTAssertTrue(config.behavior.isEditable)

            case .readOnly:
                XCTAssertFalse(config.behavior.isEditable)

            case .markdown:
                XCTAssertTrue(config.layout.wrapLines)

            case .presentation:
                XCTAssertGreaterThan(config.display.fontSize, 16)
            }
        }
    }

    func testColorThemes() {
        // Test all color themes
        for theme in ColorTheme.allCases {
            XCTAssertNotNil(theme.backgroundColor)
            XCTAssertNotNil(theme.textColor)
            XCTAssertNotNil(theme.selectedLineColor)

            // Test theme has all required colors
            _ = theme.keywordColor
            _ = theme.stringColor
            _ = theme.commentColor
            _ = theme.numberColor
        }
    }
}
