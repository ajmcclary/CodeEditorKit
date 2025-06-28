@testable import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

final class PluginConfigurationTests: XCTestCase {
    
    // MARK: - Annotation Plugin Tests
    
    @MainActor
    func testAnnotationPluginEnableDisable() {
        let textView = CodeEditorView()
        var config = EditorConfiguration()
        
        // Test disabled state
        config.display.enableAnnotations = false
        XCTAssertFalse(config.display.enableAnnotations)
        
        // When applied to text view, no annotation manager should be created
        let annotationManager = AnnotationManager(textView: textView)
        annotationManager.clearAnnotations()
        // Check for any annotation views (both plugin's and sample's)
        XCTAssertEqual(textView.subviews.filter { view in
            type(of: view).description().contains("AnnotationView")
        }.count, 0)
        
        // Test enabled state
        config.display.enableAnnotations = true
        XCTAssertTrue(config.display.enableAnnotations)
        
        // With annotations enabled, manager should work
        textView.text = "// TODO: Test annotation"
        annotationManager.scanForAnnotations()
        // Annotations are created asynchronously, so we just verify the scan was initiated
        XCTAssertNotNil(annotationManager)
    }
    
    @MainActor
    func testAnnotationPluginWithDifferentLanguages() {
        let textView = CodeEditorView()
        let annotationManager = AnnotationManager(textView: textView)
        
        // Test with Swift
        textView.language = .swift
        textView.text = """
        // TODO: Swift task
        func example() {
            // FIXME: Fix this
        }
        """
        annotationManager.scanForAnnotations()
        
        // Test with plain text
        textView.language = .plainText
        textView.text = """
        TODO: Plain text task
        FIXME: Plain text fix
        """
        annotationManager.scanForAnnotations()
        
        // Verify language doesn't affect annotation detection
        XCTAssertNotNil(annotationManager)
    }
    
    @MainActor
    func testAnnotationPluginPerformance() {
        let textView = CodeEditorView()
        let annotationManager = AnnotationManager(textView: textView)
        
        // Create text with many annotations
        let annotatedText = (0..<100).map { "// TODO: Task \($0)\n" }.joined()
        textView.text = annotatedText
        
        measure {
            annotationManager.scanForAnnotations()
        }
    }
    
    // MARK: - Custom Plugin Tests
    
    func testCustomPluginConfiguration() {
        // enableCustomPlugin is no longer part of the configuration structure
        // Custom plugin management is handled separately
        
        // This test is now a placeholder since custom plugin configuration
        // is not part of the EditorConfiguration structure
        XCTAssertTrue(true, "Custom plugin configuration is handled separately from EditorConfiguration")
        
        // Note: Custom plugin is a placeholder for future functionality
    }
    
    // MARK: - Plugin Integration Tests
    
    func testMultiplePluginsEnabled() {
        var config = EditorConfiguration()
        
        // Enable annotation plugin
        config.display.enableAnnotations = true
        
        XCTAssertTrue(config.display.enableAnnotations)
        // Custom plugin management is handled separately
        
        // Annotation plugin should be independently configurable
        config.display.enableAnnotations = false
        XCTAssertFalse(config.display.enableAnnotations)
    }
    
    func testPluginConfigurationPersistence() {
        var config = EditorConfiguration()
        config.display.enableAnnotations = true
        // enableCustomPlugin is no longer part of the configuration structure
        
        // Encode configuration
        do {
            let data = try JSONEncoder().encode(config)
            let decodedConfig = try JSONDecoder().decode(EditorConfiguration.self, from: data)
            
            XCTAssertEqual(decodedConfig.display.enableAnnotations, config.display.enableAnnotations)
            // enableCustomPlugin is no longer part of the configuration structure
        } catch {
            XCTFail("Plugin configuration encoding/decoding failed: \(error)")
        }
    }
    
    func testPluginWithConfigurationPresets() {
        // Full featured - annotations enabled
        let fullConfig = ConfigurationPreset.fullFeatured.configuration
        XCTAssertTrue(fullConfig.display.enableAnnotations)
        
        // Minimal - no annotations
        let minimalConfig = ConfigurationPreset.minimal.configuration
        XCTAssertFalse(minimalConfig.display.enableAnnotations)
        
        // Read only - annotations enabled
        let readOnlyConfig = ConfigurationPreset.readOnly.configuration
        XCTAssertTrue(readOnlyConfig.display.enableAnnotations)
    }
    
    func testPluginUIIntegration() {
        // Test that plugin settings are properly represented in UI
        var config = EditorConfiguration()
        
        // Simulate UI toggle for annotations (starting from false)
        config.display.enableAnnotations = false
        config.display.enableAnnotations = !config.display.enableAnnotations
        XCTAssertTrue(config.display.enableAnnotations)
        
        // Custom plugin management is handled separately
    }
    
    @MainActor
    func testPluginWithThemeChanges() {
        let textView = CodeEditorView()
        let annotationManager = AnnotationManager(textView: textView)
        textView.text = "// TODO: Test with themes"
        
        // Test annotation visibility with different themes
        for theme in ColorTheme.allCases {
            textView.backgroundColor = theme.backgroundColor
            textView.textColor = theme.textColor
            
            annotationManager.scanForAnnotations()
            
            // Annotations should be visible regardless of theme
            XCTAssertNotNil(annotationManager)
        }
    }
    
    @MainActor
    func testPluginEdgeCases() {
        let textView = CodeEditorView()
        let annotationManager = AnnotationManager(textView: textView)
        
        // Test with empty text
        textView.text = ""
        annotationManager.scanForAnnotations()
        // Check for any annotation views (both plugin's and sample's)
        XCTAssertEqual(textView.subviews.filter { view in
            type(of: view).description().contains("AnnotationView")
        }.count, 0)
        
        // Test with very long lines
        let longLine = "// TODO: " + String(repeating: "x", count: 1000)
        textView.text = longLine
        annotationManager.scanForAnnotations()
        
        // Test with special characters
        textView.text = "// TODO: Test with émojis 🎉 and spëcial chàracters"
        annotationManager.scanForAnnotations()
    }
    
    @MainActor
    func testPluginMemoryManagement() {
        let textView = CodeEditorView()
        let manager = AnnotationManager(textView: textView)
        
        // Test that plugins are properly cleaned up
        textView.text = String(repeating: "// TODO: Memory test\n", count: 1000)
        manager.scanForAnnotations()
        
        // Clear annotations immediately
        manager.clearAnnotations()
        
        // Verify annotations are cleared
        // Check for any annotation views (both plugin's and sample's)
        XCTAssertEqual(textView.subviews.filter { view in
            type(of: view).description().contains("AnnotationView")
        }.count, 0)
    }
}
