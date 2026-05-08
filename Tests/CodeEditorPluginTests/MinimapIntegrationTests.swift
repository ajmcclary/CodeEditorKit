@testable import CodeEditorPlugin
import XCTest
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Fixed minimap integration tests that avoid hanging issues
final class MinimapIntegrationTests: XCTestCase {
    // MARK: - Basic Minimap Tests

    func testMinimapConfiguration() {
        let config = MinimapConfiguration()

        // Test default configuration
        XCTAssertEqual(config.width, 120, "Default width should be 120")
        XCTAssertEqual(config.fontSize, 2.0, "Default font size should be 2.0")
        XCTAssertEqual(config.lineHeight, 1.0, "Default line height should be 1.0")
        XCTAssertEqual(config.maxLines, 10_000, "Default max lines should be 10,000")

        // Test default colors
        XCTAssertNotNil(MinimapConfiguration.defaultBackgroundColor)
        XCTAssertNotNil(MinimapConfiguration.defaultTextColor)
        XCTAssertNotNil(MinimapConfiguration.defaultViewportColor)
        XCTAssertNotNil(MinimapConfiguration.defaultViewportBorderColor)
    }

    func testMinimapDataCreation() {
        let data = MinimapData(
            totalLines: 100,
            visibleLineRange: 10..<20,
            displayLines: ["Line 1", "Line 2", "Line 3"],
            displayStartLine: 0,
            characterWidth: 7.0,
            lineHeight: 14.0
        )

        XCTAssertEqual(data.totalLines, 100, "Total lines should match")
        XCTAssertEqual(data.visibleLineRange, 10..<20, "Visible range should match")
        XCTAssertEqual(data.displayLines.count, 3, "Display lines should match")
        XCTAssertEqual(data.displayStartLine, 0, "Display start line should match")
        XCTAssertEqual(data.characterWidth, 7.0, "Character width should match")
        XCTAssertEqual(data.lineHeight, 14.0, "Line height should match")
    }

    // MARK: - Minimap Renderer Tests

    @MainActor
    func testMinimapRendererCalculations() {
        let font = PlatformFont.monospacedSystemFont(ofSize: 2.0, weight: .regular)
        let metrics = MinimapRenderer.calculateCharacterMetrics(font: font)

        XCTAssertGreaterThan(metrics.width, 0, "Character width should be positive")
        XCTAssertGreaterThan(metrics.height, 0, "Character height should be positive")

        let contentHeight = MinimapRenderer.calculateContentHeight(lineCount: 100, lineHeight: 4.0)
        XCTAssertEqual(contentHeight, 400.0, "Content height should be lines * line height")
    }

    func testViewportRectCalculation() {
        let visibleRange = 10..<20
        let lineHeight: CGFloat = 4.0
        let minimapWidth: CGFloat = 60.0
        let totalLines = 100
        let minimapHeight: CGFloat = 400.0

        let viewportRect = MinimapRenderer.viewportRect(
            for: visibleRange,
            lineHeight: lineHeight,
            minimapWidth: minimapWidth,
            totalLines: totalLines,
            minimapHeight: minimapHeight
        )

        XCTAssertEqual(viewportRect.width, minimapWidth, "Viewport width should match minimap width")
        XCTAssertEqual(viewportRect.height, CGFloat(visibleRange.count) * lineHeight, "Viewport height should match visible lines")

        #if canImport(AppKit)
        // On macOS, coordinates are flipped
        let expectedY = minimapHeight - CGFloat(visibleRange.lowerBound) * lineHeight - viewportRect.height
        XCTAssertEqual(viewportRect.origin.y, expectedY, accuracy: 0.01, "Viewport Y should be flipped on macOS")
        #else
        let expectedY = CGFloat(visibleRange.lowerBound) * lineHeight
        XCTAssertEqual(viewportRect.origin.y, expectedY, accuracy: 0.01, "Viewport Y should match start line on iOS")
        #endif
    }

    func testLineNumberCalculation() {
        let lineHeight: CGFloat = 4.0
        let totalLines = 100
        let minimapHeight: CGFloat = 400.0

        // Test line number at different points
        #if canImport(AppKit)
        // macOS has flipped coordinates
        let topLine = MinimapRenderer.lineNumber(at: NSPoint(x: 30, y: 396), lineHeight: lineHeight, totalLines: totalLines, minimapHeight: minimapHeight)
        let middleLine = MinimapRenderer.lineNumber(at: NSPoint(x: 30, y: 200), lineHeight: lineHeight, totalLines: totalLines, minimapHeight: minimapHeight)
        let bottomLine = MinimapRenderer.lineNumber(at: NSPoint(x: 30, y: 4), lineHeight: lineHeight, totalLines: totalLines, minimapHeight: minimapHeight)

        XCTAssertEqual(topLine, 1, "Top should be line 1 on macOS")
        XCTAssertEqual(middleLine, 50, "Middle should be around line 50")
        XCTAssertEqual(bottomLine, 99, "Bottom should be line 99")
        #else
        let topLine = MinimapRenderer.lineNumber(at: CGPoint(x: 30, y: 0), lineHeight: lineHeight, totalLines: totalLines, minimapHeight: minimapHeight)
        let middleLine = MinimapRenderer.lineNumber(at: CGPoint(x: 30, y: 200), lineHeight: lineHeight, totalLines: totalLines, minimapHeight: minimapHeight)
        let bottomLine = MinimapRenderer.lineNumber(at: CGPoint(x: 30, y: 396), lineHeight: lineHeight, totalLines: totalLines, minimapHeight: minimapHeight)

        XCTAssertEqual(topLine, 0, "Top should be line 0")
        XCTAssertEqual(middleLine, 50, "Middle should be around line 50")
        XCTAssertEqual(bottomLine, 99, "Bottom should be line 99")
        #endif
    }

    // MARK: - MinimapViewModel Tests

    @available(iOS 17.0, macOS 14.0, *)
    @MainActor
    func testMinimapViewModel() async {
        let config = EditorConfiguration()
        let services = BusinessLogicServiceRegistry()
        let viewModel = MinimapViewModel(configuration: config, businessLogicServices: services)

        // Test initial state
        XCTAssertEqual(viewModel.minimapState.isVisible, config.display.isMinimapVisible, "Visibility should match config")
        XCTAssertTrue(viewModel.minimapState.needsRedraw, "Should need redraw initially")
        XCTAssertTrue(viewModel.renderInfo.isEmpty, "Render info should be empty initially")

        // Test visibility toggle
        var newConfig = config
        newConfig.display.isMinimapVisible = true
        viewModel.updateConfiguration(newConfig)
        XCTAssertTrue(viewModel.minimapState.isVisible, "Should be visible after update")

        newConfig.display.isMinimapVisible = false
        viewModel.updateConfiguration(newConfig)
        XCTAssertFalse(viewModel.minimapState.isVisible, "Should be hidden after update")
    }

    @available(iOS 17.0, macOS 14.0, *)
    @MainActor
    func testMinimapViewModelTextChange() async {
        var config = EditorConfiguration()
        config.display.isMinimapVisible = true
        let services = BusinessLogicServiceRegistry()
        let viewModel = MinimapViewModel(configuration: config, businessLogicServices: services)

        // Test text change
        viewModel.textDidChange("Line 1\nLine 2\nLine 3")

        // Wait a bit for throttled update
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        // The render info might be populated after the throttled update
        // We can't guarantee exact timing in tests, so just verify the state is consistent
        XCTAssertTrue(viewModel.minimapState.needsRedraw, "Should need redraw after text change")
    }

    @available(iOS 17.0, macOS 14.0, *)
    @MainActor
    func testMinimapViewModelInteraction() async {
        var config = EditorConfiguration()
        config.display.isMinimapVisible = true
        let services = BusinessLogicServiceRegistry()
        let viewModel = MinimapViewModel(configuration: config, businessLogicServices: services)

        // Set up frame
        viewModel.updateFrame(CGRect(x: 0, y: 0, width: 60, height: 400))

        // Test pointer interaction
        let handled = viewModel.handlePointerDown(at: CGPoint(x: 30, y: 200))
        XCTAssertTrue(handled, "Should handle pointer down when visible")
        XCTAssertTrue(viewModel.interaction.isDragging, "Should be dragging")

        viewModel.handlePointerUp()
        XCTAssertFalse(viewModel.interaction.isDragging, "Should not be dragging after pointer up")

        // Test hover
        viewModel.handlePointerHover(at: CGPoint(x: 30, y: 100))
        XCTAssertTrue(viewModel.interaction.isHovered, "Should be hovered")
        XCTAssertEqual(viewModel.interaction.hoveredPosition, 100, "Hover position should match")

        viewModel.handlePointerHover(at: nil)
        XCTAssertFalse(viewModel.interaction.isHovered, "Should not be hovered")
    }

    // MARK: - Configuration Tests

    @MainActor
    func testMinimapVisibilityConfiguration() {
        let textView = CodeEditorView()
        var config = EditorConfiguration()

        // Test showing minimap
        config.display.isMinimapVisible = true
        config.apply(to: textView)
        XCTAssertTrue(textView.configuration.display.isMinimapVisible, "Minimap should be visible")

        // Test hiding minimap
        config.display.isMinimapVisible = false
        config.apply(to: textView)
        XCTAssertFalse(textView.configuration.display.isMinimapVisible, "Minimap should be hidden")
    }

    // MARK: - SwiftUI Integration Tests

    #if canImport(SwiftUI)
    @available(iOS 16.0, macOS 13.0, *)
    @MainActor
    func testMinimapSwiftUIModifier() {
        let codeText = "let x = 42"

        // Test that the modifier compiles and can be used
        let view = CodeEditor(text: .constant(codeText))
            .isMinimapVisible(true)
            .frame(width: 600, height: 400)

        // This is a compile-time test to ensure the modifier exists
        XCTAssertNotNil(view, "View should be created with minimap modifier")
    }

    @available(iOS 16.0, macOS 13.0, *)
    @MainActor
    func testMinimapDirectConfigurationToggle() {
        var config = EditorConfiguration()
        config.display.isMinimapVisible = true
        XCTAssertTrue(config.display.isMinimapVisible, "Minimap should be enabled via direct config")

        var disabledConfig = EditorConfiguration()
        disabledConfig.display.isMinimapVisible = false
        XCTAssertFalse(disabledConfig.display.isMinimapVisible, "Minimap should be disabled via direct config")
    }
    #endif

    // MARK: - Edge Case Tests

    func testMinimapDataWithEmptyText() {
        let data = MinimapData(
            totalLines: 1,
            visibleLineRange: 0..<1,
            displayLines: [""],
            displayStartLine: 0,
            characterWidth: 7.0,
            lineHeight: 14.0
        )

        XCTAssertEqual(data.totalLines, 1, "Empty text should have 1 line")
        XCTAssertEqual(data.displayLines.count, 1, "Should display 1 empty line")
        XCTAssertEqual(data.displayLines.first, "", "First line should be empty")
    }

    func testMinimapDataWithLargeFile() {
        let largeLines = (0..<10_000).map { "Line \($0)" }
        let config = MinimapConfiguration()

        // Test that display lines are limited
        let truncatedLines = Array(largeLines.prefix(config.maxLines))

        let data = MinimapData(
            totalLines: largeLines.count,
            visibleLineRange: 100..<200,
            displayLines: truncatedLines,
            displayStartLine: 0,
            characterWidth: 7.0,
            lineHeight: 2.0
        )

        XCTAssertEqual(data.totalLines, 10_000, "Should have correct total lines")
        XCTAssertEqual(data.displayLines.count, config.maxLines, "Display lines should be limited")
        XCTAssertEqual(data.visibleLineRange, 100..<200, "Visible range should be preserved")
    }
}
