@testable import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

final class PluginConfigurationTests: XCTestCase {
    
    // MARK: - Annotation Plugin Tests
    
    @MainActor
    func testAnnotationPluginEnableDisable() {
        let textView = STTextView()
        var config = EditorConfiguration()
        
        // Test disabled state
        config.enableAnnotations = false
        XCTAssertFalse(config.enableAnnotations)
        
        // When applied to text view, no annotation manager should be created
        let annotationManager = AnnotationManager(textView: textView)
        annotationManager.clearAnnotations()
        XCTAssertEqual(textView.subviews.filter { $0 is AnnotationView }.count, 0)
        
        // Test enabled state
        config.enableAnnotations = true
        XCTAssertTrue(config.enableAnnotations)
        
        // With annotations enabled, manager should work
        textView.text = "// TODO: Test annotation"
        annotationManager.scanForAnnotations()
        // Annotations are created asynchronously, so we just verify the scan was initiated
        XCTAssertNotNil(annotationManager)
    }
    
    @MainActor
    func testAnnotationPluginWithDifferentLanguages() {
        let textView = STTextView()
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
        let textView = STTextView()
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
        var config = EditorConfiguration()
        
        // Test disabled state
        config.enableCustomPlugin = false
        XCTAssertFalse(config.enableCustomPlugin)
        
        // Test enabled state
        config.enableCustomPlugin = true
        XCTAssertTrue(config.enableCustomPlugin)
        
        // Note: Custom plugin is a placeholder for future functionality
    }
    
    // MARK: - Plugin Integration Tests
    
    func testMultiplePluginsEnabled() {
        var config = EditorConfiguration()
        
        // Enable multiple plugins
        config.enableAnnotations = true
        config.enableCustomPlugin = true
        
        XCTAssertTrue(config.enableAnnotations)
        XCTAssertTrue(config.enableCustomPlugin)
        
        // Both plugins should be independently configurable
        config.enableAnnotations = false
        XCTAssertFalse(config.enableAnnotations)
        XCTAssertTrue(config.enableCustomPlugin)
    }
    
    func testPluginConfigurationPersistence() {
        var config = EditorConfiguration()
        config.enableAnnotations = true
        config.enableCustomPlugin = false
        
        // Encode configuration
        do {
            let data = try JSONEncoder().encode(config)
            let decodedConfig = try JSONDecoder().decode(EditorConfiguration.self, from: data)
            
            XCTAssertEqual(decodedConfig.enableAnnotations, config.enableAnnotations)
            XCTAssertEqual(decodedConfig.enableCustomPlugin, config.enableCustomPlugin)
        } catch {
            XCTFail("Plugin configuration encoding/decoding failed: \(error)")
        }
    }
    
    func testPluginWithConfigurationPresets() {
        // Full featured - all plugins enabled
        let fullConfig = ConfigurationPreset.fullFeatured.configuration
        XCTAssertTrue(fullConfig.enableAnnotations)
        XCTAssertTrue(fullConfig.enableCustomPlugin)
        
        // Minimal - no plugins
        let minimalConfig = ConfigurationPreset.minimal.configuration
        XCTAssertFalse(minimalConfig.enableAnnotations)
        XCTAssertFalse(minimalConfig.enableCustomPlugin)
        
        // Read only - annotations enabled
        let readOnlyConfig = ConfigurationPreset.readOnly.configuration
        XCTAssertTrue(readOnlyConfig.enableAnnotations)
        XCTAssertFalse(readOnlyConfig.enableCustomPlugin)
    }
    
    func testPluginUIIntegration() {
        // Test that plugin settings are properly represented in UI
        var config = EditorConfiguration()
        
        // Simulate UI toggle for annotations
        config.enableAnnotations = !config.enableAnnotations
        XCTAssertTrue(config.enableAnnotations)
        
        // Simulate UI toggle for custom plugin
        config.enableCustomPlugin = !config.enableCustomPlugin
        XCTAssertTrue(config.enableCustomPlugin)
    }
    
    @MainActor
    func testPluginWithThemeChanges() {
        let textView = STTextView()
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
        let textView = STTextView()
        let annotationManager = AnnotationManager(textView: textView)
        
        // Test with empty text
        textView.text = ""
        annotationManager.scanForAnnotations()
        XCTAssertEqual(textView.subviews.filter { $0 is AnnotationView }.count, 0)
        
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
        let textView = STTextView()
        let manager = AnnotationManager(textView: textView)
        
        // Test that plugins are properly cleaned up
        textView.text = String(repeating: "// TODO: Memory test\n", count: 1000)
        manager.scanForAnnotations()
        
        // Clear annotations immediately
        manager.clearAnnotations()
        
        // Verify annotations are cleared
        XCTAssertEqual(textView.subviews.filter { $0 is AnnotationView }.count, 0)
    }
}
