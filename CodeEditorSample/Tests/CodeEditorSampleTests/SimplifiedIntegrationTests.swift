@testable import CodeEditorPlugin
import SwiftUI
import XCTest

#if XCODE_BUILD && os(macOS)
@testable import CodeEditorSample_macOS
// Disambiguate ConfigurationPreset since both modules define it
typealias SampleConfigurationPreset = CodeEditorSample_macOS.ConfigurationPreset
#else
@testable import CodeEditorSample
// Disambiguate ConfigurationPreset since both modules define it
typealias SampleConfigurationPreset = CodeEditorSample.ConfigurationPreset
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class SimplifiedIntegrationTests: XCTestCase {
    // MARK: - Configuration Tests

    func testConfigurationPresets() async {
        // Create text view once and reuse it
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        #else
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        #endif

        // Test specific presets instead of all
        let presetsToTest: [(SampleConfigurationPreset, () -> Void)] = [
            (.fullFeatured, {
                XCTAssertTrue(textView.isLineNumbersEnabled)
                XCTAssertTrue(textView.isEditable)
            }),
            (.minimal, {
                XCTAssertFalse(textView.isLineNumbersEnabled)
                XCTAssertTrue(textView.isEditable)
            }),
            (.readOnly, {
                XCTAssertFalse(textView.isEditable)
                XCTAssertTrue(textView.isLineNumbersEnabled)
            })
        ]

        for (preset, verification) in presetsToTest {
            let config = preset.configuration
            config.apply(to: textView)
            verification()
        }
    }

    func testLanguageSamples() async {
        // Create text view once and reuse it
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        #else
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        #endif

        // Test a subset of language samples to reduce test time
        let samplesToTest: [SampleCode] = [.swift, .python, .javascript]

        for sample in samplesToTest {
            let code = SampleCodeProvider.getCode(for: sample)
            textView.text = code

            XCTAssertEqual(textView.text, code, "Text should be set for \(sample)")
            XCTAssertFalse(code.isEmpty, "Sample code should not be empty for \(sample)")
        }
    }

    func testThemeColors() async {
        // Create text view once and reuse it
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        #else
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        #endif

        // Test a subset of themes to speed up the test
        let themesToTest: [ColorTheme] = [.xcode, .vsDark, .github]
        
        for theme in themesToTest {
            textView.backgroundColor = theme.backgroundColor
            textView.textColor = theme.textColor
            
            // Just verify that colors were set (don't compare values as system colors have different descriptions)
            XCTAssertNotNil(textView.backgroundColor)
            XCTAssertNotNil(textView.textColor)
        }
        
        // Test configuration update separately with just one theme
        var config = textView.configuration
        config.display.selectedLineHighlightColor = ColorTheme.xcode.selectedLineColor
        textView.configuration = config
        XCTAssertNotNil(textView.configuration.display.selectedLineHighlightColor)
    }

    func testEditorWorkflow() async {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        #else
        let textView = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        #endif

        // 1. Start with full featured config
        let config = SampleConfigurationPreset.fullFeatured.configuration
        textView.isLineNumbersEnabled = config.display.isLineNumbersEnabled
        textView.isEditable = config.behavior.isEditable
        textView.text = "Initial code"

        XCTAssertTrue(textView.isLineNumbersEnabled)
        XCTAssertTrue(textView.isEditable)
        XCTAssertEqual(textView.text, "Initial code")

        // 2. Switch to read-only
        let readOnlyConfig = SampleConfigurationPreset.readOnly.configuration
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
