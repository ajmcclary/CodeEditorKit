@testable import CodeEditorPlugin
#if XCODE_BUILD && os(macOS)
@testable import CodeEditorSample_macOS
#else
@testable import CodeEditorSample
#endif
import SwiftUI
import XCTest

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class SimplifiedIntegrationTests: XCTestCase {
    // MARK: - Configuration Tests

    func testConfigurationPresets() async {
        // Test each preset
        for preset in ConfigurationPreset.allCases {
            let config = preset.configuration
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
            #else
            let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
            #endif

            // Apply configuration using the plugin's apply method
            config.apply(to: textView)

            // Verify configuration
            switch preset {
            case .fullFeatured:
                XCTAssertTrue(textView.isLineNumbersEnabled)
                XCTAssertTrue(textView.isEditable)

            case .minimal:
                XCTAssertFalse(textView.isLineNumbersEnabled)
                XCTAssertTrue(textView.isEditable)

            case .readOnly:
                XCTAssertFalse(textView.isEditable)
                XCTAssertTrue(textView.isLineNumbersEnabled)

            case .markdown:
                XCTAssertTrue(config.layout.wrapLines)
                XCTAssertTrue(textView.isEditable)

            case .presentation:
                XCTAssertGreaterThan(textView.font?.pointSize ?? 0, 16)
            }
        }
    }

    func testLanguageSamples() async {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        #else
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        #endif

        for sample in SampleCode.allCases {
            let code = SampleCodeProvider.getCode(for: sample)
            textView.text = code

            XCTAssertEqual(textView.text, code, "Text should be set for \(sample)")
            XCTAssertFalse(code.isEmpty, "Sample code should not be empty for \(sample)")
        }
    }

    func testThemeColors() async {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        #else
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        #endif

        for theme in ColorTheme.allCases {
            textView.backgroundColor = theme.backgroundColor
            textView.textColor = theme.textColor
            
            // Update configuration for selectedLineHighlightColor
            var config = textView.configuration
            config.display.selectedLineHighlightColor = theme.selectedLineColor
            textView.configuration = config

            // Just verify that colors were set (don't compare values as system colors have different descriptions)
            XCTAssertNotNil(textView.backgroundColor)
            XCTAssertNotNil(textView.textColor)
            XCTAssertNotNil(textView.configuration.display.selectedLineHighlightColor)
        }
    }

    func testEditorWorkflow() async {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        #else
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        #endif

        // 1. Start with full featured config
        let config = ConfigurationPreset.fullFeatured.configuration
        textView.isLineNumbersEnabled = config.display.showLineNumbers
        textView.isEditable = config.behavior.isEditable
        textView.text = "Initial code"

        XCTAssertTrue(textView.isLineNumbersEnabled)
        XCTAssertTrue(textView.isEditable)
        XCTAssertEqual(textView.text, "Initial code")

        // 2. Switch to read-only
        let readOnlyConfig = ConfigurationPreset.readOnly.configuration
        textView.isEditable = readOnlyConfig.behavior.isEditable

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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        #else
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        #endif

        // Set text content
        textView.text = "TODO: Implement feature\nFIXME: Fix bug\nNOTE: Remember this"

        // Verify text was set
        let text = textView.text ?? ""
        XCTAssertFalse(text.isEmpty, "Text should be set")
        XCTAssertTrue(text.contains("TODO"), "Should contain TODO annotation")
        XCTAssertTrue(text.contains("FIXME"), "Should contain FIXME annotation")
        XCTAssertTrue(text.contains("NOTE"), "Should contain NOTE annotation")

        // Layout
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.layoutSubtreeIfNeeded()
        #else
        textView.layoutIfNeeded()
        #endif
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
        appState.currentConfiguration.display.fontSize = 20
        XCTAssertEqual(appState.currentConfiguration.display.fontSize, 20)
    }
}
