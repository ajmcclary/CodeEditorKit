import XCTest
@testable import CodeEditorPlugin
@testable import CodeEditorSample

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
        XCTAssertTrue(config.showLineNumbers)
        XCTAssertTrue(config.isEditable)
        XCTAssertEqual(config.fontSize, 14)
        XCTAssertEqual(config.tabWidth, 4)
    }

    func testConfigurationPresets() {
        // Test all presets
        for preset in ConfigurationPreset.allCases {
            let config = preset.configuration

            switch preset {
            case .fullFeatured:
                XCTAssertTrue(config.showLineNumbers)
                XCTAssertTrue(config.isEditable)

            case .minimal:
                XCTAssertFalse(config.showLineNumbers)
                XCTAssertTrue(config.isEditable)

            case .readOnly:
                XCTAssertFalse(config.isEditable)

            case .markdown:
                XCTAssertTrue(config.wrapLines)

            case .presentation:
                XCTAssertGreaterThan(config.fontSize, 16)
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
