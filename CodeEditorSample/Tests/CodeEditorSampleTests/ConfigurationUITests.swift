@testable import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

final class ConfigurationUITests: XCTestCase {
    
    // MARK: - Configuration Application Tests
    
    func testFullConfigurationApplication() {
        // Create a comprehensive configuration
        var config = EditorConfiguration()
        config.showLineNumbers = true
        config.showInvisibleCharacters = true
        config.highlightSelectedLine = true
        config.wrapLines = false
        config.isEditable = true
        config.autoIndent = true
        config.tabWidth = 8
        config.insertSpacesForTabs = false
        config.fontSize = 18
        config.lineSpacing = 2.0
        config.theme = .vsDark
        config.textContainerInset = NSSize(width: 10, height: 10)
        config.lineFragmentPadding = 8.0
        config.enableAnnotations = true
        config.enableCustomPlugin = false
        config.useHardwareAcceleration = true
        config.smoothScrolling = true
        
        // Verify all properties are set correctly
        XCTAssertTrue(config.showLineNumbers)
        XCTAssertTrue(config.showInvisibleCharacters)
        XCTAssertTrue(config.highlightSelectedLine)
        XCTAssertFalse(config.wrapLines)
        XCTAssertTrue(config.isEditable)
        XCTAssertTrue(config.autoIndent)
        XCTAssertEqual(config.tabWidth, 8)
        XCTAssertFalse(config.insertSpacesForTabs)
        XCTAssertEqual(config.fontSize, 18)
        XCTAssertEqual(config.lineSpacing, 2.0)
        XCTAssertEqual(config.theme, .vsDark)
        XCTAssertEqual(config.textContainerInset, NSSize(width: 10, height: 10))
        XCTAssertEqual(config.lineFragmentPadding, 8.0)
        XCTAssertTrue(config.enableAnnotations)
        XCTAssertFalse(config.enableCustomPlugin)
        XCTAssertTrue(config.useHardwareAcceleration)
        XCTAssertTrue(config.smoothScrolling)
    }
    
    func testConfigurationPresetFullFeatured() {
        let config = ConfigurationPreset.fullFeatured.configuration
        
        XCTAssertTrue(config.showLineNumbers)
        XCTAssertFalse(config.showInvisibleCharacters)
        XCTAssertTrue(config.highlightSelectedLine)
        XCTAssertFalse(config.wrapLines)
        XCTAssertTrue(config.isEditable)
        XCTAssertTrue(config.autoIndent)
        XCTAssertEqual(config.tabWidth, 4)
        XCTAssertTrue(config.insertSpacesForTabs)
        XCTAssertEqual(config.fontSize, 14)
        XCTAssertEqual(config.lineSpacing, 1.2)
        XCTAssertEqual(config.theme, .xcode)
        XCTAssertTrue(config.enableAnnotations)
        XCTAssertTrue(config.enableCustomPlugin)
        XCTAssertTrue(config.useHardwareAcceleration)
        XCTAssertTrue(config.smoothScrolling)
    }
    
    func testConfigurationPresetMinimal() {
        let config = ConfigurationPreset.minimal.configuration
        
        XCTAssertFalse(config.showLineNumbers)
        XCTAssertFalse(config.showInvisibleCharacters)
        XCTAssertFalse(config.highlightSelectedLine)
        XCTAssertTrue(config.wrapLines)
        XCTAssertTrue(config.isEditable)
        XCTAssertFalse(config.autoIndent)
        XCTAssertEqual(config.tabWidth, 4)
        XCTAssertTrue(config.insertSpacesForTabs)
        XCTAssertEqual(config.fontSize, 14)
        XCTAssertEqual(config.lineSpacing, 1.5)
        XCTAssertEqual(config.theme, .minimal)
        XCTAssertFalse(config.enableAnnotations)
        XCTAssertFalse(config.enableCustomPlugin)
    }
    
    func testConfigurationPresetReadOnly() {
        let config = ConfigurationPreset.readOnly.configuration
        
        XCTAssertTrue(config.showLineNumbers)
        XCTAssertFalse(config.showInvisibleCharacters)
        XCTAssertFalse(config.highlightSelectedLine)
        XCTAssertFalse(config.wrapLines)
        XCTAssertFalse(config.isEditable)
        XCTAssertFalse(config.autoIndent)
        XCTAssertEqual(config.fontSize, 13)
        XCTAssertEqual(config.theme, .vsDark)
        XCTAssertTrue(config.enableAnnotations)
    }
    
    func testConfigurationPresetMarkdown() {
        let config = ConfigurationPreset.markdown.configuration
        
        XCTAssertFalse(config.showLineNumbers)
        XCTAssertTrue(config.highlightSelectedLine)
        XCTAssertTrue(config.wrapLines)
        XCTAssertTrue(config.isEditable)
        XCTAssertTrue(config.autoIndent)
        XCTAssertEqual(config.tabWidth, 2)
        XCTAssertEqual(config.fontSize, 16)
        XCTAssertEqual(config.lineSpacing, 1.6)
        XCTAssertEqual(config.theme, .github)
        XCTAssertTrue(config.isContinuousSpellCheckingEnabled) // Special for markdown
    }
    
    func testConfigurationPresetPresentation() {
        let config = ConfigurationPreset.presentation.configuration
        
        XCTAssertTrue(config.showLineNumbers)
        XCTAssertTrue(config.highlightSelectedLine)
        XCTAssertFalse(config.wrapLines)
        XCTAssertFalse(config.isEditable)
        XCTAssertEqual(config.fontSize, 20)
        XCTAssertEqual(config.lineSpacing, 1.4)
        XCTAssertEqual(config.theme, .presentation)
    }
    
    func testThemeApplication() {
        var config = EditorConfiguration()
        
        // Test each theme
        for theme in ColorTheme.allCases {
            config.theme = theme
            XCTAssertEqual(config.theme, theme)
            
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
        config.enableAnnotations = false
        XCTAssertFalse(config.enableAnnotations)
        
        config.enableAnnotations = true
        XCTAssertTrue(config.enableAnnotations)
        
        // Test custom plugin placeholder
        config.enableCustomPlugin = false
        XCTAssertFalse(config.enableCustomPlugin)
        
        config.enableCustomPlugin = true
        XCTAssertTrue(config.enableCustomPlugin)
    }
    
    func testTextProcessingConfiguration() {
        var config = EditorConfiguration()
        
        // Test all text processing options
        config.isContinuousSpellCheckingEnabled = true
        XCTAssertTrue(config.isContinuousSpellCheckingEnabled)
        
        config.isGrammarCheckingEnabled = true
        XCTAssertTrue(config.isGrammarCheckingEnabled)
        
        config.isAutomaticQuoteSubstitutionEnabled = true
        XCTAssertTrue(config.isAutomaticQuoteSubstitutionEnabled)
        
        config.isAutomaticDashSubstitutionEnabled = true
        XCTAssertTrue(config.isAutomaticDashSubstitutionEnabled)
        
        config.isAutomaticTextReplacementEnabled = true
        XCTAssertTrue(config.isAutomaticTextReplacementEnabled)
        
        config.isAutomaticSpellingCorrectionEnabled = true
        XCTAssertTrue(config.isAutomaticSpellingCorrectionEnabled)
        
        config.isAutomaticTextCompletionEnabled = true
        XCTAssertTrue(config.isAutomaticTextCompletionEnabled)
        
        config.isIncrementalSearchingEnabled = false
        XCTAssertFalse(config.isIncrementalSearchingEnabled)
    }
    
    func testAdvancedSettingsConfiguration() {
        var config = EditorConfiguration()
        
        // Test all advanced settings
        config.allowsDocumentBackgroundColorChange = true
        XCTAssertTrue(config.allowsDocumentBackgroundColorChange)
        
        config.allowsImageEditing = true
        XCTAssertTrue(config.allowsImageEditing)
        
        config.allowsCharacterPickerTouchBarItem = true
        XCTAssertTrue(config.allowsCharacterPickerTouchBarItem)
        
        config.isRichText = true
        XCTAssertTrue(config.isRichText)
        
        config.importsGraphics = true
        XCTAssertTrue(config.importsGraphics)
        
        config.usesInspectorBar = true
        XCTAssertTrue(config.usesInspectorBar)
        
        config.usesFindBar = false
        XCTAssertFalse(config.usesFindBar)
        
        config.allowsNonContiguousLayout = false
        XCTAssertFalse(config.allowsNonContiguousLayout)
        
        config.displaysLinkToolTips = false
        XCTAssertFalse(config.displaysLinkToolTips)
    }
    
    func testTabConfiguration() {
        var config = EditorConfiguration()
        
        // Test tab width variations
        config.tabWidth = 2
        XCTAssertEqual(config.tabWidth, 2)
        
        config.tabWidth = 4
        XCTAssertEqual(config.tabWidth, 4)
        
        config.tabWidth = 8
        XCTAssertEqual(config.tabWidth, 8)
        
        // Test spaces vs tabs
        config.insertSpacesForTabs = true
        XCTAssertTrue(config.insertSpacesForTabs)
        
        config.insertSpacesForTabs = false
        XCTAssertFalse(config.insertSpacesForTabs)
    }
    
    func testConfigurationExportImport() {
        // Create a custom configuration
        var config = EditorConfiguration()
        config.showLineNumbers = true
        config.fontSize = 16
        config.theme = .github
        config.tabWidth = 8
        config.enableAnnotations = true
        
        // Test encoding
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(config)
            XCTAssertNotNil(data)
            
            // Test decoding
            let decoder = JSONDecoder()
            let decodedConfig = try decoder.decode(EditorConfiguration.self, from: data)
            
            // Verify configuration was preserved
            XCTAssertEqual(decodedConfig.showLineNumbers, config.showLineNumbers)
            XCTAssertEqual(decodedConfig.fontSize, config.fontSize)
            XCTAssertEqual(decodedConfig.theme, config.theme)
            XCTAssertEqual(decodedConfig.tabWidth, config.tabWidth)
            XCTAssertEqual(decodedConfig.enableAnnotations, config.enableAnnotations)
        } catch {
            XCTFail("Configuration encoding/decoding failed: \(error)")
        }
    }
}
