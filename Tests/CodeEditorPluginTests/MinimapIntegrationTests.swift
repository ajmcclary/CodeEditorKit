@testable import CodeEditorPlugin
import XCTest
#if canImport(SwiftUI)
import SwiftUI
#endif

final class MinimapIntegrationTests: XCTestCase {
    // MARK: - Basic Minimap Tests
    
    @MainActor
    func testMinimapViewCreation() {
        let minimap = MinimapView(frame: CGRect(x: 0, y: 0, width: 50, height: 300))
        
        XCTAssertNotNil(minimap, "Minimap should be created")
        XCTAssertEqual(minimap.frame.width, 50, "Minimap width should be set")
        XCTAssertNil(minimap.data, "Initial data should be nil")
    }
    
    @MainActor
    func testMinimapDataProvider() {
        let textView = CodeEditorView()
        textView.text = "Line 1\nLine 2\nLine 3"
        
        let provider = MinimapDataProvider(textView: textView)
        let data = provider.generateData()
        
        XCTAssertNotNil(data, "Should generate minimap data")
        XCTAssertEqual(data?.totalLines, 3, "Should have 3 lines")
        XCTAssertEqual(data?.displayLines.count, 3, "Should display all 3 lines")
    }
    
    @MainActor
    func testMinimapConfiguration() {
        let minimap = MinimapView(frame: CGRect(x: 0, y: 0, width: 60, height: 400))
        
        // Test default configuration
        XCTAssertEqual(minimap.configuration.width, 120, "Default width should be 120")
        XCTAssertEqual(minimap.configuration.fontSize, 2.0, "Default font size should be 2.0")
        
        // Test configuration changes
        minimap.configuration.fontSize = 3.0
        minimap.configuration.maxLines = 5_000
        
        XCTAssertEqual(minimap.configuration.fontSize, 3.0, "Font size should be updated")
        XCTAssertEqual(minimap.configuration.maxLines, 5_000, "Max lines should be updated")
    }
    
    // MARK: - Minimap Data Tests
    
    @MainActor
    func testMinimapDataWithLargeFile() {
        let textView = CodeEditorView()
        let largeText = (0..<1_000).map { "Line \($0)" }.joined(separator: "\n")
        textView.text = largeText
        
        let config = MinimapConfiguration()
        let provider = MinimapDataProvider(textView: textView, configuration: config)
        let data = provider.generateData()
        
        XCTAssertNotNil(data, "Should generate data for large file")
        XCTAssertEqual(data?.totalLines, 1_000, "Should have 1000 total lines")
        XCTAssertLessThanOrEqual(data?.displayLines.count ?? 0, config.maxLines, "Should limit display lines")
    }
    
    @MainActor
    func testMinimapDataUpdate() {
        let minimap = MinimapView(frame: CGRect(x: 0, y: 0, width: 60, height: 400))
        
        let data = MinimapData(
            totalLines: 100,
            visibleLineRange: 10..<20,
            displayLines: ["Line 1", "Line 2"],
            displayStartLine: 0,
            characterWidth: 7.0,
            lineHeight: 14.0
        )
        
        minimap.updateData(data)
        
        XCTAssertNotNil(minimap.data, "Data should be set")
        XCTAssertEqual(minimap.data?.totalLines, 100, "Total lines should match")
        XCTAssertEqual(minimap.data?.visibleLineRange, 10..<20, "Visible range should match")
    }
    
    // MARK: - Minimap Interaction Tests
    
    @MainActor
    func testMinimapLineNumberCalculation() {
        let minimap = MinimapView(frame: CGRect(x: 0, y: 0, width: 60, height: 400))
        
        let data = MinimapData(
            totalLines: 100,
            visibleLineRange: 10..<20,
            displayLines: [],
            displayStartLine: 0,
            characterWidth: 7.0,
            lineHeight: 4.0 // 400 height / 100 lines = 4.0 per line
        )
        
        minimap.updateData(data)
        
        // Test line number at different points
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS has flipped coordinates
        let topLine = minimap.lineNumber(at: NSPoint(x: 30, y: 396))
        let middleLine = minimap.lineNumber(at: NSPoint(x: 30, y: 200))
        let bottomLine = minimap.lineNumber(at: NSPoint(x: 30, y: 4))
        
        XCTAssertEqual(topLine, 1, "Top should be line 1 on macOS")
        XCTAssertEqual(middleLine, 50, "Middle should be around line 50")
        XCTAssertEqual(bottomLine, 99, "Bottom should be line 99")
        #else
        let topLine = minimap.lineNumber(at: CGPoint(x: 30, y: 0))
        let middleLine = minimap.lineNumber(at: CGPoint(x: 30, y: 200))
        let bottomLine = minimap.lineNumber(at: CGPoint(x: 30, y: 396))
        
        XCTAssertEqual(topLine, 0, "Top should be line 0")
        XCTAssertEqual(middleLine, 50, "Middle should be around line 50")
        XCTAssertEqual(bottomLine, 99, "Bottom should be line 99")
        #endif
    }
    
    @MainActor
    func testMinimapNavigationCallback() {
        let minimap = MinimapView(frame: CGRect(x: 0, y: 0, width: 60, height: 400))
        var navigatedToLine: Int?
        
        minimap.onNavigate = { line in
            navigatedToLine = line
        }
        
        let data = MinimapData(
            totalLines: 100,
            visibleLineRange: 10..<20,
            displayLines: [],
            displayStartLine: 0,
            characterWidth: 7.0,
            lineHeight: 4.0
        )
        
        minimap.updateData(data)
        
        // Simulate navigation
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let event = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 30, y: 200),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        
        if let event {
            minimap.mouseDown(with: event)
            XCTAssertNotNil(navigatedToLine, "Should have navigated")
            XCTAssertEqual(navigatedToLine, 50, "Should navigate to middle line")
        }
        #else
        // For iOS, we would need to trigger the tap gesture
        // This is harder to test directly without UI testing
        #endif
    }
    
    // MARK: - Configuration Tests
    
    @MainActor
    func testMinimapVisibilityConfiguration() {
        let textView = CodeEditorView()
        var config = EditorConfiguration()
        
        // Test showing minimap
        config.display.showMinimap = true
        config.apply(to: textView)
        XCTAssertTrue(textView.configuration.display.showMinimap, "Minimap should be visible")
        
        // Test hiding minimap
        config.display.showMinimap = false
        config.apply(to: textView)
        XCTAssertFalse(textView.configuration.display.showMinimap, "Minimap should be hidden")
    }
    
    // MARK: - SwiftUI Integration Tests
    
    #if canImport(SwiftUI)
    @available(iOS 16.0, macOS 13.0, *)
    @MainActor
    func testMinimapSwiftUIModifier() {
        let codeText = "let x = 42"
        
        // Test that the modifier compiles and can be used
        let view = CodeEditor(text: .constant(codeText))
            .showMinimap(true)
            .frame(width: 600, height: 400)
        
        // This is a compile-time test to ensure the modifier exists
        XCTAssertNotNil(view, "View should be created with minimap modifier")
    }
    
    @available(iOS 16.0, macOS 13.0, *)
    @MainActor
    func testMinimapConfigurationBuilder() {
        let config = EditorConfigurationBuilder()
            .showMinimap(true)
            .build()
        
        XCTAssertTrue(config.display.showMinimap, "Minimap should be enabled via builder")
        
        let disabledConfig = EditorConfigurationBuilder()
            .showMinimap(false)
            .build()
        
        XCTAssertFalse(disabledConfig.display.showMinimap, "Minimap should be disabled via builder")
    }
    #endif
    
    // MARK: - Performance Tests
    
    @MainActor
    func testMinimapDataGenerationPerformance() {
        let textView = CodeEditorView()
        let largeText = (0..<10_000).map { "Line \($0) with some content" }.joined(separator: "\n")
        textView.text = largeText
        
        let provider = MinimapDataProvider(textView: textView)
        
        measure {
            _ = provider.generateData()
        }
    }
    
    // MARK: - Edge Case Tests
    
    @MainActor
    func testMinimapWithEmptyText() {
        let textView = CodeEditorView()
        textView.text = ""
        
        let provider = MinimapDataProvider(textView: textView)
        let data = provider.generateData()
        
        XCTAssertNotNil(data, "Should handle empty text")
        XCTAssertEqual(data?.totalLines, 1, "Empty text should have 1 line")
        XCTAssertEqual(data?.displayLines.count, 1, "Should display 1 empty line")
    }
    
    @MainActor
    func testMinimapRendererCalculations() {
        let font = PlatformFont.monospacedSystemFont(ofSize: 2.0, weight: .regular)
        let metrics = MinimapRenderer.calculateCharacterMetrics(font: font)
        
        XCTAssertGreaterThan(metrics.width, 0, "Character width should be positive")
        XCTAssertGreaterThan(metrics.height, 0, "Character height should be positive")
        
        let contentHeight = MinimapRenderer.calculateContentHeight(lineCount: 100, lineHeight: 4.0)
        XCTAssertEqual(contentHeight, 400.0, "Content height should be lines * line height")
    }
}
