@testable import CodeEditorPlugin
#if XCODE_BUILD && os(macOS)
@testable import CodeEditorSample_macOS
#else
@testable import CodeEditorSample
#endif
import XCTest

final class ConfigurationUITests: XCTestCase {
    
    // MARK: - Configuration Application Tests
    
    func testFullConfigurationApplication() {
        // Create a comprehensive configuration
        var config = EditorConfiguration()
        config.display.showLineNumbers = true
        config.display.showInvisibleCharacters = true
        config.display.highlightSelectedLine = true
        config.layout.wrapLines = false
        config.behavior.isEditable = true
        config.behavior.autoIndent = true
        config.layout.tabWidth = 8
        config.layout.insertSpacesForTabs = false
        config.display.fontSize = 18
        config.layout.lineSpacing = 2.0
        // Theme is handled by the color system separately
        // config.textContainerInset and config.lineFragmentPadding are TextKit properties handled in apply method
        config.display.enableAnnotations = true
        // enableCustomPlugin is no longer part of the configuration structure
        config.performance.useHardwareAcceleration = true
        config.performance.smoothScrolling = true
        
        // Verify all properties are set correctly
        XCTAssertTrue(config.display.showLineNumbers)
        XCTAssertTrue(config.display.showInvisibleCharacters)
        XCTAssertTrue(config.display.highlightSelectedLine)
        XCTAssertFalse(config.layout.wrapLines)
        XCTAssertTrue(config.behavior.isEditable)
        XCTAssertTrue(config.behavior.autoIndent)
        XCTAssertEqual(config.layout.tabWidth, 8)
        XCTAssertFalse(config.layout.insertSpacesForTabs)
        XCTAssertEqual(config.display.fontSize, 18)
        XCTAssertEqual(config.layout.lineSpacing, 2.0)
        // Theme, textContainerInset, lineFragmentPadding are handled separately
        XCTAssertTrue(config.display.enableAnnotations)
        // enableCustomPlugin is no longer part of the configuration structure
        XCTAssertTrue(config.performance.useHardwareAcceleration)
        XCTAssertTrue(config.performance.smoothScrolling)
    }
    
    func testConfigurationPresetFullFeatured() {
        let config = ConfigurationPreset.fullFeatured.configuration
        
        XCTAssertTrue(config.display.showLineNumbers)
        XCTAssertFalse(config.display.showInvisibleCharacters)
        XCTAssertTrue(config.display.highlightSelectedLine)
        XCTAssertFalse(config.layout.wrapLines)
        XCTAssertTrue(config.behavior.isEditable)
        XCTAssertTrue(config.behavior.autoIndent)
        XCTAssertEqual(config.layout.tabWidth, 4)
        XCTAssertTrue(config.layout.insertSpacesForTabs)
        XCTAssertEqual(config.display.fontSize, 14)
        XCTAssertEqual(config.layout.lineSpacing, 1.2)
        // theme is handled separately in the color system
        XCTAssertTrue(config.display.enableAnnotations)
        // enableCustomPlugin is no longer in configuration structure
        XCTAssertTrue(config.performance.useHardwareAcceleration)
        XCTAssertTrue(config.performance.smoothScrolling)
    }
    
    func testConfigurationPresetMinimal() {
        let config = ConfigurationPreset.minimal.configuration
        
        XCTAssertFalse(config.display.showLineNumbers)
        XCTAssertFalse(config.display.showInvisibleCharacters)
        XCTAssertFalse(config.display.highlightSelectedLine)
        XCTAssertTrue(config.layout.wrapLines)
        XCTAssertTrue(config.behavior.isEditable)
        XCTAssertTrue(config.behavior.autoIndent)
        XCTAssertEqual(config.layout.tabWidth, 4)
        XCTAssertTrue(config.layout.insertSpacesForTabs)
        XCTAssertEqual(config.display.fontSize, 14)
        XCTAssertEqual(config.layout.lineSpacing, 1.5)
        // theme is handled separately in the color system
        XCTAssertFalse(config.display.enableAnnotations)
        // enableCustomPlugin is no longer in configuration structure
    }
    
    func testConfigurationPresetReadOnly() {
        let config = ConfigurationPreset.readOnly.configuration
        
        XCTAssertTrue(config.display.showLineNumbers)
        XCTAssertFalse(config.display.showInvisibleCharacters)
        XCTAssertTrue(config.display.highlightSelectedLine)  // Default value, not modified by readOnly preset
        XCTAssertFalse(config.layout.wrapLines)
        XCTAssertFalse(config.behavior.isEditable)
        XCTAssertTrue(config.behavior.autoIndent)  // Default value, not modified by readOnly preset
        XCTAssertEqual(config.display.fontSize, 13)
        // theme is handled separately in the color system
        XCTAssertTrue(config.display.enableAnnotations)
    }
    
    func testConfigurationPresetMarkdown() {
        let config = ConfigurationPreset.markdown.configuration
        
        XCTAssertFalse(config.display.showLineNumbers)
        XCTAssertTrue(config.display.highlightSelectedLine)
        XCTAssertTrue(config.layout.wrapLines)
        XCTAssertTrue(config.behavior.isEditable)
        XCTAssertTrue(config.behavior.autoIndent)
        XCTAssertEqual(config.layout.tabWidth, 2)
        XCTAssertEqual(config.display.fontSize, 16)
        XCTAssertEqual(config.layout.lineSpacing, 1.6)
        // theme is handled separately in the color system
        XCTAssertTrue(config.behavior.isContinuousSpellCheckingEnabled) // Special for markdown
    }
    
    func testConfigurationPresetPresentation() {
        let config = ConfigurationPreset.presentation.configuration
        
        XCTAssertTrue(config.display.showLineNumbers)
        XCTAssertTrue(config.display.highlightSelectedLine)
        XCTAssertFalse(config.layout.wrapLines)
        XCTAssertFalse(config.behavior.isEditable)
        XCTAssertEqual(config.display.fontSize, 20)
        XCTAssertEqual(config.layout.lineSpacing, 1.4)
        // theme is handled separately in the color system
    }
    
    func testThemeApplication() {
        // Test each theme directly
        for theme in ColorTheme.allCases {
            // Theme is now handled separately from configuration
            // The configuration structure focuses on editor behavior, not visual themes
            
            // Verify theme has all required colors
            XCTAssertNotNil(theme.backgroundColor)
            XCTAssertNotNil(theme.textColor)
            XCTAssertNotNil(theme.selectedLineColor)
            XCTAssertNotNil(theme.keywordColor)
            XCTAssertNotNil(theme.stringColor)
            XCTAssertNotNil(theme.numberColor)
            XCTAssertNotNil(theme.commentColor)
        }
    }
    
    func testPluginConfiguration() {
        var config = EditorConfiguration()
        
        // Test annotation plugin
        config.display.enableAnnotations = false
        XCTAssertFalse(config.display.enableAnnotations)
        
        config.display.enableAnnotations = true
        XCTAssertTrue(config.display.enableAnnotations)
        
        // Custom plugin is no longer part of the configuration structure
        // Plugin management is handled separately
    }
    
    func testTextProcessingConfiguration() {
        var config = EditorConfiguration()
        
        // Test all text processing options
        config.behavior.isContinuousSpellCheckingEnabled = true
        XCTAssertTrue(config.behavior.isContinuousSpellCheckingEnabled)
        
        config.behavior.isGrammarCheckingEnabled = true
        XCTAssertTrue(config.behavior.isGrammarCheckingEnabled)
        
        config.behavior.isAutomaticQuoteSubstitutionEnabled = true
        XCTAssertTrue(config.behavior.isAutomaticQuoteSubstitutionEnabled)
        
        config.behavior.isAutomaticDashSubstitutionEnabled = true
        XCTAssertTrue(config.behavior.isAutomaticDashSubstitutionEnabled)
        
        config.behavior.isAutomaticTextReplacementEnabled = true
        XCTAssertTrue(config.behavior.isAutomaticTextReplacementEnabled)
        
        config.behavior.isAutomaticSpellingCorrectionEnabled = true
        XCTAssertTrue(config.behavior.isAutomaticSpellingCorrectionEnabled)
        
        config.behavior.isAutomaticTextCompletionEnabled = true
        XCTAssertTrue(config.behavior.isAutomaticTextCompletionEnabled)
        
        // isIncrementalSearchingEnabled is not part of the new configuration structure
    }
    
    func testAdvancedSettingsConfiguration() {
        // Advanced NSTextView settings are not part of the new configuration structure
        // These are handled directly by the text view when needed
        // The new configuration structure focuses on code editor specific settings
        
        // This test verifies that the configuration structure is focused on code editing
        let config = EditorConfiguration()
        XCTAssertNotNil(config.display, "Configuration should have display settings")
        XCTAssertNotNil(config.behavior, "Configuration should have behavior settings")
        XCTAssertNotNil(config.layout, "Configuration should have layout settings")
        XCTAssertNotNil(config.performance, "Configuration should have performance settings")
    }
    
    func testTabConfiguration() {
        var config = EditorConfiguration()
        
        // Test tab width variations
        config.layout.tabWidth = 2
        XCTAssertEqual(config.layout.tabWidth, 2)
        
        config.layout.tabWidth = 4
        XCTAssertEqual(config.layout.tabWidth, 4)
        
        config.layout.tabWidth = 8
        XCTAssertEqual(config.layout.tabWidth, 8)
        
        // Test spaces vs tabs
        config.layout.insertSpacesForTabs = true
        XCTAssertTrue(config.layout.insertSpacesForTabs)
        
        config.layout.insertSpacesForTabs = false
        XCTAssertFalse(config.layout.insertSpacesForTabs)
    }
    
    func testConfigurationExportImport() {
        // Create a custom configuration
        var config = EditorConfiguration()
        config.display.showLineNumbers = true
        config.display.fontSize = 16
        // theme is handled separately in the color system
        config.layout.tabWidth = 8
        config.display.enableAnnotations = true
        
        // Test encoding
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(config)
            XCTAssertNotNil(data)
            
            // Test decoding
            let decoder = JSONDecoder()
            let decodedConfig = try decoder.decode(EditorConfiguration.self, from: data)
            
            // Verify configuration was preserved
            XCTAssertEqual(decodedConfig.display.showLineNumbers, config.display.showLineNumbers)
            XCTAssertEqual(decodedConfig.display.fontSize, config.display.fontSize)
            // theme verification handled separately
            XCTAssertEqual(decodedConfig.layout.tabWidth, config.layout.tabWidth)
            XCTAssertEqual(decodedConfig.display.enableAnnotations, config.display.enableAnnotations)
        } catch {
            XCTFail("Configuration encoding/decoding failed: \(error)")
        }
    }
}
