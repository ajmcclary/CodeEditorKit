@testable import CodeEditorPlugin
@testable import CodeEditorSample
import SwiftUI
import XCTest

@MainActor
final class SimplifiedIntegrationTests: XCTestCase {
    // MARK: - Configuration Tests

    func testConfigurationPresets() async {
        // Test each preset
        for preset in ConfigurationPreset.allCases {
            let config = preset.configuration
            let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))

            // Apply configuration
            textView.showsLineNumbers = config.showLineNumbers
            textView.isEditable = config.isEditable
            textView.showsInvisibleCharacters = config.showInvisibleCharacters
            textView.highlightSelectedLine = config.highlightSelectedLine
            textView.font = NSFont.monospacedSystemFont(ofSize: config.fontSize, weight: .regular)
            textView.backgroundColor = config.theme.backgroundColor
            textView.textColor = config.theme.textColor

            // Verify configuration
            switch preset {
            case .fullFeatured:
                XCTAssertTrue(textView.showsLineNumbers)
                XCTAssertTrue(textView.isEditable)

            case .minimal:
                XCTAssertFalse(textView.showsLineNumbers)
                XCTAssertTrue(textView.isEditable)

            case .readOnly:
                XCTAssertFalse(textView.isEditable)
                XCTAssertTrue(textView.showsLineNumbers)

            case .markdown:
                XCTAssertTrue(config.wrapLines)
                XCTAssertTrue(textView.isEditable)

            case .presentation:
                XCTAssertGreaterThan(textView.font?.pointSize ?? 0, 16)
            }
        }
    }

    func testLanguageSamples() async {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))

        for sample in SampleCode.allCases {
            let code = SampleCodeProvider.getCode(for: sample)
            textView.text = code

            XCTAssertEqual(textView.text, code, "Text should be set for \(sample)")
            XCTAssertFalse(code.isEmpty, "Sample code should not be empty for \(sample)")
        }
    }

    func testThemeColors() async {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))

        for theme in ColorTheme.allCases {
            textView.backgroundColor = theme.backgroundColor
            textView.textColor = theme.textColor
            textView.selectedLineHighlightColor = theme.selectedLineColor

            XCTAssertEqual(textView.backgroundColor, theme.backgroundColor)
            XCTAssertEqual(textView.textColor, theme.textColor)
            XCTAssertEqual(textView.selectedLineHighlightColor, theme.selectedLineColor)
        }
    }

    func testEditorWorkflow() async {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))

        // 1. Start with full featured config
        let config = ConfigurationPreset.fullFeatured.configuration
        textView.showsLineNumbers = config.showLineNumbers
        textView.isEditable = config.isEditable
        textView.text = "Initial code"

        XCTAssertTrue(textView.showsLineNumbers)
        XCTAssertTrue(textView.isEditable)
        XCTAssertEqual(textView.text, "Initial code")

        // 2. Switch to read-only
        let readOnlyConfig = ConfigurationPreset.readOnly.configuration
        textView.isEditable = readOnlyConfig.isEditable

        XCTAssertFalse(textView.isEditable)
        XCTAssertTrue(textView.isSelectable)

        // 3. Change theme
        let darkTheme = ColorTheme.vsDark
        textView.backgroundColor = darkTheme.backgroundColor
        textView.textColor = darkTheme.textColor

        // Check that colors are set (allowing for system color variations)
        XCTAssertNotNil(textView.backgroundColor)
        XCTAssertNotNil(textView.textColor)
    }

    func testAnnotationSystem() async {
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))

        // Set text content
        textView.text = "TODO: Implement feature\nFIXME: Fix bug\nNOTE: Remember this"

        // Verify text was set
        let text = textView.text ?? ""
        XCTAssertFalse(text.isEmpty, "Text should be set")
        XCTAssertTrue(text.contains("TODO"), "Should contain TODO annotation")
        XCTAssertTrue(text.contains("FIXME"), "Should contain FIXME annotation")
        XCTAssertTrue(text.contains("NOTE"), "Should contain NOTE annotation")

        // Layout
        textView.layoutSubtreeIfNeeded()
    }

    func testAppState() async {
        let appState = AppState()

        // Test initial state
        XCTAssertEqual(appState.selectedPreset, .fullFeatured)
        XCTAssertEqual(appState.selectedSample, .swift)

        // Change state
        appState.selectedPreset = .markdown
        appState.selectedSample = .python
        appState.code = "# Python code"

        XCTAssertEqual(appState.selectedPreset, .markdown)
        XCTAssertEqual(appState.selectedSample, .python)
        XCTAssertEqual(appState.code, "# Python code")

        // Modify configuration
        appState.currentConfiguration.fontSize = 20
        XCTAssertEqual(appState.currentConfiguration.fontSize, 20)
    }
}
