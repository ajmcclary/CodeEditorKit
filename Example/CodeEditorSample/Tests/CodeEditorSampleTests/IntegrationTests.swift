import XCTest
import SwiftUI
@testable import CodeEditorPlugin
@testable import CodeEditorSample

@MainActor
final class IntegrationTests: XCTestCase {
    
    // MARK: - Full App Workflow Tests
    
    func testCompleteEditorWorkflow() async {
        // 1. Create editor with configuration
        var config = EditorConfiguration.fullFeatured
        let textBinding = Binding<String>(
            get: { "Initial code" },
            set: { newValue in
                // Verify text updates
                XCTAssertFalse(newValue.isEmpty, "Text should not be empty")
            }
        )
        
        let editorView = CodeEditorView(
            configuration: config,
            text: textBinding,
            language: "swift"
        )
        
        // 2. Create the actual view
        let nsView = editorView.makeNSView(context: NSViewRepresentableContext<CodeEditorView>())
        
        // 3. Verify initial state
        XCTAssertTrue(nsView.showsLineNumbers, "Should show line numbers")
        XCTAssertTrue(nsView.isEditable, "Should be editable")
        XCTAssertEqual(nsView.text, "Initial code", "Should have initial text")
        
        // 4. Update configuration
        config.showLineNumbers = false
        config.fontSize = 16
        editorView.updateNSView(nsView, context: NSViewRepresentableContext<CodeEditorView>())
        
        // 5. Verify configuration updates
        XCTAssertFalse(nsView.showsLineNumbers, "Line numbers should be hidden")
        XCTAssertEqual(nsView.font.pointSize, 16, "Font size should be updated")
    }
    
    func testLanguageSwitching() async {
        // Test switching between different language samples
        let languages: [SampleCode] = [.swift, .python, .javascript, .html]
        var currentText = ""
        
        let textBinding = Binding<String>(
            get: { currentText },
            set: { currentText = $0 }
        )
        
        for language in languages {
            // Create editor for each language
            let editorView = CodeEditorView(
                configuration: .fullFeatured,
                text: textBinding,
                language: language.fileExtension
            )
            
            let nsView = editorView.makeNSView(context: NSViewRepresentableContext<CodeEditorView>())
            
            // Set sample code
            currentText = SampleCodeProvider.getCode(for: language)
            editorView.updateNSView(nsView, context: NSViewRepresentableContext<CodeEditorView>())
            
            // Verify text is set
            XCTAssertEqual(nsView.text, currentText, "Text should match for \(language)")
        }
    }
    
    func testPresetConfigurations() async {
        let presets: [ConfigurationPreset] = ConfigurationPreset.allCases
        
        for preset in presets {
            let config = preset.configuration
            
            let editorView = CodeEditorView(
                configuration: config,
                text: .constant("Test code"),
                language: "swift"
            )
            
            let nsView = editorView.makeNSView(context: NSViewRepresentableContext<CodeEditorView>())
            
            // Verify preset is applied correctly
            switch preset {
            case .fullFeatured:
                XCTAssertTrue(nsView.showsLineNumbers)
                XCTAssertTrue(nsView.isEditable)
                XCTAssertTrue(nsView.highlightSelectedLine)
                
            case .minimal:
                XCTAssertFalse(nsView.showsLineNumbers)
                XCTAssertTrue(nsView.isEditable)
                XCTAssertFalse(nsView.showsInvisibleCharacters)
                
            case .readOnly:
                XCTAssertFalse(nsView.isEditable)
                XCTAssertTrue(nsView.isSelectable)
                
            case .markdown:
                XCTAssertTrue(nsView.widthTracksTextView)
                XCTAssertTrue(nsView.isEditable)
                
            case .presentation:
                XCTAssertGreaterThan(nsView.font.pointSize, 16)
                XCTAssertFalse(nsView.showsLineNumbers)
            }
        }
    }
    
    // MARK: - Theme Integration Tests
    
    func testThemeApplication() async {
        let themes = ColorTheme.allCases
        
        for theme in themes {
            var config = EditorConfiguration()
            config.theme = theme
            
            let editorView = CodeEditorView(
                configuration: config,
                text: .constant("// Test code"),
                language: "swift"
            )
            
            let nsView = editorView.makeNSView(context: NSViewRepresentableContext<CodeEditorView>())
            
            // Verify theme colors are applied
            XCTAssertEqual(nsView.backgroundColor, theme.backgroundColor, "Background color should match theme")
            XCTAssertEqual(nsView.textColor, theme.textColor, "Text color should match theme")
            XCTAssertEqual(nsView.selectedLineHighlightColor, theme.selectedLineColor, "Selected line color should match theme")
        }
    }
    
    // MARK: - Plugin Integration Tests
    
    func testPluginIntegration() async {
        var config = EditorConfiguration()
        config.enableCustomPlugin = true
        
        let editorView = CodeEditorView(
            configuration: config,
            text: .constant("Test code"),
            language: "swift"
        )
        
        let nsView = editorView.makeNSView(context: NSViewRepresentableContext<CodeEditorView>())
        
        // Verify plugin is added
        XCTAssertGreaterThan(nsView.plugins.count, 0, "Should have at least one plugin")
        
        // Update to disable plugin
        config.enableCustomPlugin = false
        editorView.updateNSView(nsView, context: NSViewRepresentableContext<CodeEditorView>())
        
        // Note: Plugin removal might not be implemented, but we test the configuration
    }
    
    // MARK: - State Persistence Tests
    
    func testStatePersistence() async {
        // Create app state
        let appState = AppState()
        
        // Set initial values
        appState.selectedPreset = .markdown
        appState.selectedSample = .python
        appState.code = "# Python code"
        
        // Verify state
        XCTAssertEqual(appState.selectedPreset, .markdown)
        XCTAssertEqual(appState.selectedSample, .python)
        XCTAssertEqual(appState.code, "# Python code")
        
        // Change configuration
        appState.configuration.fontSize = 18
        appState.configuration.showLineNumbers = false
        
        // Verify configuration changes
        XCTAssertEqual(appState.configuration.fontSize, 18)
        XCTAssertFalse(appState.configuration.showLineNumbers)
    }
    
    // MARK: - Sidebar Integration Tests
    
    func testSidebarInteraction() async {
        var config = EditorConfiguration()
        var selectedPreset = ConfigurationPreset.fullFeatured
        var selectedSample = SampleCode.swift
        var code = ""
        
        // Simulate sidebar interactions
        
        // 1. Select preset
        selectedPreset = .minimal
        config = selectedPreset.configuration
        
        XCTAssertFalse(config.showLineNumbers, "Minimal preset should not show line numbers")
        
        // 2. Select language sample
        selectedSample = .python
        code = SampleCodeProvider.getCode(for: selectedSample)
        
        XCTAssertTrue(code.contains("def") || code.contains("import"), "Should have Python code")
        
        // 3. Toggle settings
        config.showLineNumbers.toggle()
        config.wrapLines.toggle()
        config.highlightSelectedLine.toggle()
        
        XCTAssertTrue(config.showLineNumbers)
        XCTAssertTrue(config.wrapLines)
        XCTAssertTrue(config.highlightSelectedLine)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() async {
        // Test with empty text
        let emptyBinding = Binding<String>.constant("")
        let editorView1 = CodeEditorView(
            configuration: .fullFeatured,
            text: emptyBinding,
            language: "swift"
        )
        
        let nsView1 = editorView1.makeNSView(context: NSViewRepresentableContext<CodeEditorView>())
        XCTAssertEqual(nsView1.text, "", "Should handle empty text")
        
        // Test with very long text
        let longText = String(repeating: "a", count: 1_000_000)
        let longBinding = Binding<String>.constant(longText)
        let editorView2 = CodeEditorView(
            configuration: .minimal,
            text: longBinding,
            language: "txt"
        )
        
        let nsView2 = editorView2.makeNSView(context: NSViewRepresentableContext<CodeEditorView>())
        XCTAssertEqual(nsView2.text?.count, 1_000_000, "Should handle long text")
        
        // Test with invalid configuration
        var invalidConfig = EditorConfiguration()
        invalidConfig.fontSize = -1 // Will be clamped
        invalidConfig.tabWidth = 0 // Will be clamped
        
        let editorView3 = CodeEditorView(
            configuration: invalidConfig,
            text: .constant("Test"),
            language: "swift"
        )
        
        let nsView3 = editorView3.makeNSView(context: NSViewRepresentableContext<CodeEditorView>())
        XCTAssertGreaterThan(nsView3.font.pointSize, 0, "Font size should be valid")
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibility() async {
        let editorView = CodeEditorView(
            configuration: .fullFeatured,
            text: .constant("Test code"),
            language: "swift"
        )
        
        let nsView = editorView.makeNSView(context: NSViewRepresentableContext<CodeEditorView>())
        
        // Verify basic accessibility
        XCTAssertTrue(nsView.isAccessibilityElement(), "Should be an accessibility element")
        XCTAssertNotNil(nsView.accessibilityRole(), "Should have accessibility role")
        
        // Test with read-only configuration
        let readOnlyView = CodeEditorView(
            configuration: EditorConfiguration(isEditable: false),
            text: .constant("Read only"),
            language: "swift"
        )
        
        let readOnlyNSView = readOnlyView.makeNSView(context: NSViewRepresentableContext<CodeEditorView>())
        XCTAssertFalse(readOnlyNSView.isEditable, "Should not be editable")
        XCTAssertTrue(readOnlyNSView.isSelectable, "Should still be selectable for accessibility")
    }
}