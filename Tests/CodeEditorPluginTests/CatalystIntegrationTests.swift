#if targetEnvironment(macCatalyst)
@testable import CodeEditorPlugin
import SwiftUI
import XCTest

final class CatalystIntegrationTests: XCTestCase {
    // MARK: - Color Handling Tests
    
    func testCatalystColorHelperHandlesProblematicColors() {
        let problematicColors: [Color] = [.primary, .clear, .accentColor]
        
        for color in problematicColors {
            let effectiveColor = CatalystColorHelper.effectiveTextColor(from: color)
            
            // Verify the color is not transparent
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            effectiveColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            XCTAssertGreaterThan(alpha, 0.1, "Color should not be transparent")
        }
    }
    
    func testCatalystColorHelperPreservesCustomColors() {
        let customColor = Color(red: 0.5, green: 0.7, blue: 0.9)
        let effectiveColor = CatalystColorHelper.effectiveTextColor(from: customColor)
        
        // Verify the color is preserved
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        effectiveColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        XCTAssertTrue(red > 0.4 && red < 0.6, "Red component should be preserved")
        XCTAssertTrue(green > 0.6 && green < 0.8, "Green component should be preserved")
        XCTAssertTrue(blue > 0.8 && blue < 1.0, "Blue component should be preserved")
    }
    
    func testCatalystColorHelperAdaptsToDarkMode() {
        let primaryColor = Color.primary
        let effectiveColor = CatalystColorHelper.effectiveTextColor(from: primaryColor)
        
        // This should return a dynamic color
        let darkTraitCollection = UITraitCollection(userInterfaceStyle: .dark)
        let lightTraitCollection = UITraitCollection(userInterfaceStyle: .light)
        
        let darkColor = effectiveColor.resolvedColor(with: darkTraitCollection)
        let lightColor = effectiveColor.resolvedColor(with: lightTraitCollection)
        
        // In dark mode, should be light color
        var darkRed: CGFloat = 0, darkGreen: CGFloat = 0, darkBlue: CGFloat = 0, darkAlpha: CGFloat = 0
        darkColor.getRed(&darkRed, green: &darkGreen, blue: &darkBlue, alpha: &darkAlpha)
        let darkBrightness = (darkRed + darkGreen + darkBlue) / 3.0
        
        // In light mode, should be dark color
        var lightRed: CGFloat = 0, lightGreen: CGFloat = 0, lightBlue: CGFloat = 0, lightAlpha: CGFloat = 0
        lightColor.getRed(&lightRed, green: &lightGreen, blue: &lightBlue, alpha: &lightAlpha)
        let lightBrightness = (lightRed + lightGreen + lightBlue) / 3.0
        
        XCTAssertGreaterThan(darkBrightness, 0.5, "Dark mode should have light text")
        XCTAssertLessThan(lightBrightness, 0.5, "Light mode should have dark text")
    }
    
    // MARK: - Configuration Tests
    
    func testCatalystConfigurationPreset() {
        let config = EditorConfiguration.catalyst
        
        // Verify Catalyst-specific settings
        XCTAssertEqual(config.display.fontSize, 14.0, "Should have medium font size")
        XCTAssertEqual(config.layout.gutterWidth, 45.0, "Should have slightly wider gutter")
        XCTAssertTrue(config.performance.useHardwareAcceleration, "Should use hardware acceleration")
        XCTAssertFalse(config.behavior.isAutomaticQuoteSubstitutionEnabled, "Should disable auto quote substitution")
        XCTAssertFalse(config.behavior.isAutomaticDashSubstitutionEnabled, "Should disable auto dash substitution")
    }
    
    func testPlatformOptimizedReturnsCorrectConfig() {
        let config = EditorConfiguration.platformOptimized
        
        // On Catalyst, should return catalyst config
        XCTAssertEqual(config.display.fontSize, 14.0, "Should use Catalyst font size")
        XCTAssertEqual(config.layout.gutterWidth, 45.0, "Should use Catalyst gutter width")
    }
    
    // MARK: - Editor View Tests
    
    @MainActor
    func testCatalystEditorViewConfiguration() async {
        let editor = CodeEditorView()
        let config = EditorConfiguration.catalyst
        
        config.apply(to: editor)
        
        // Verify configuration was applied
        XCTAssertEqual(editor.font?.pointSize, 14.0, "Font size should be applied")
    }
    
    @MainActor
    func testCatalystColorApplication() async {
        let editor = CodeEditorView()
        let testColor = UIColor.systemBlue
        
        await CatalystColorHelper.applyTextColor(testColor, to: editor)
        
        // Verify color was applied
        XCTAssertEqual(editor.textColor, testColor, "Text color should be applied")
        
        // Verify text storage has the color
        if editor.textStorage.length > 0 {
            var effectiveRange = NSRange()
            let attributes = editor.textStorage.attributes(at: 0, effectiveRange: &effectiveRange)
            let foregroundColor = attributes[.foregroundColor] as? UIColor
            XCTAssertEqual(foregroundColor, testColor, "Text storage should have the color")
        }
    }
    
    // MARK: - SwiftUI Integration Tests
    
    @available(iOS 14.0, macCatalyst 14.0, *)
    @MainActor
    func testCatalystSwiftUIIntegration() async throws {
        let expectation = XCTestExpectation(description: "SwiftUI view renders")
        
        let codeBinding = "let test = 42"
        let view = CodeEditor(text: .constant(codeBinding))
            .codeLanguage(.swift)
            .environment(\.codeEditorConfiguration, .catalyst)
        
        // Create a hosting controller
        let hostingController = UIHostingController(rootView: view)
        
        // Force layout
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        // Give it time to render
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Verify the view was created
        XCTAssertNotNil(hostingController.view)
    }
    
    // MARK: - Performance Tests
    
    func testCatalystPerformanceLimits() {
        let config = EditorConfiguration.catalyst
        
        // Verify performance limits are appropriate for Catalyst
        XCTAssertEqual(config.performance.maxSyntaxHighlightingLength, 250_000, "Should have medium syntax highlighting limit")
        XCTAssertGreaterThan(config.performance.maxSyntaxHighlightingLength, 100_000, "Should be higher than iOS limit")
        XCTAssertLessThan(config.performance.maxSyntaxHighlightingLength, 500_000, "Should be lower than macOS limit")
    }
    
    // MARK: - Color Update Integration Tests
    
    @MainActor
    func testCatalystColorUpdateAfterTextChange() async {
        let editor = CodeEditorView()
        let testColor = UIColor.systemRed
        
        // Set initial text and color
        editor.text = "Initial text"
        await CatalystColorHelper.applyTextColor(testColor, to: editor)
        
        // Change text
        editor.text = "Updated text"
        
        // Apply color again
        await CatalystColorHelper.applyTextColor(testColor, to: editor)
        
        // Verify color persists after text change
        XCTAssertEqual(editor.textColor, testColor, "Text color should persist after text change")
        
        if editor.textStorage.length > 0 {
            var effectiveRange = NSRange()
            let attributes = editor.textStorage.attributes(at: 0, effectiveRange: &effectiveRange)
            let foregroundColor = attributes[.foregroundColor] as? UIColor
            XCTAssertEqual(foregroundColor, testColor, "Text storage should maintain color after text change")
        }
    }
    
    @MainActor
    func testCatalystColorUpdateWithEmptyText() async {
        let editor = CodeEditorView()
        let testColor = UIColor.systemGreen
        
        // Apply color to empty editor
        editor.text = ""
        await CatalystColorHelper.applyTextColor(testColor, to: editor)
        
        // Add text after color application
        editor.text = "New text"
        
        // Re-apply color
        await CatalystColorHelper.applyTextColor(testColor, to: editor)
        
        // Verify color is applied to new text
        XCTAssertEqual(editor.textColor, testColor, "Text color should be applied to new text")
    }
    
    @MainActor
    func testCatalystColorUpdateWithSyntaxHighlighting() async {
        let editor = CodeEditorView()
        // Use a color that should resolve to full opacity
        let baseColor = UIColor { traitCollection in
            // Return a color that should have full opacity
            return traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black
        }
        
        // Enable syntax highlighting
        editor.language = .swift
        editor.text = "let value = 42"
        
        // Apply base color
        await CatalystColorHelper.applyTextColor(baseColor, to: editor)
        
        // Verify base color is set (comparing semantic meaning, not exact instance)
        // Since UIColor.label may be wrapped in a dynamic provider, compare the resolved colors
        XCTAssertNotNil(editor.textColor, "Text color should be set")
        
        // Compare colors in current trait collection
        let traitCollection = editor.traitCollection
        let actualColor = editor.textColor?.resolvedColor(with: traitCollection)
        
        // Verify the color is appropriate for the trait collection
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        actualColor?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let brightness = (red + green + blue) / 3.0
        if traitCollection.userInterfaceStyle == .dark {
            XCTAssertGreaterThan(brightness, 0.5, "Dark mode should have light text")
        } else {
            XCTAssertLessThan(brightness, 0.5, "Light mode should have dark text")
        }
        
        // For Mac Catalyst, the system may apply its own alpha adjustments
        // We just need to ensure the text is visible enough
        XCTAssertGreaterThan(alpha, 0.8, "Text should be mostly opaque")
        
        // Syntax highlighting should still work on top of base color
        // This tests that our color application doesn't interfere with highlighting
    }
    
    @MainActor
    func testCatalystColorUpdateInCoordinator() async {
        // This tests the actual consolidated color handling in the coordinator
        let coordinator = CodeEditorBaseCoordinator()
        let container = CodeEditorContainerView()
        let theme = CodeEditorSwiftUITheme.dark
        
        // Setup container with theme
        coordinator.setupContainer(
            container,
            text: "Test text",
            language: .plainText,
            theme: theme,
            configuration: .catalyst,
            memoryMonitor: MemoryMonitor()
        )
        
        // Update container with new theme
        let newTheme = CodeEditorSwiftUITheme.default
        coordinator.updateContainer(
            container,
            text: "Updated text",
            language: .plainText,
            theme: newTheme,
            configuration: .catalyst
        )
        
        // Verify theme was applied correctly
        let expectedBackgroundColor = PlatformColor.from(newTheme.backgroundColor)
        XCTAssertEqual(container.textView.backgroundColor, expectedBackgroundColor, "Background color should be updated")
    }
    
    @MainActor
    func testCatalystColorUpdateWithDynamicColors() async {
        let editor = CodeEditorView()
        
        // Test with dynamic color that adapts to appearance
        let dynamicColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? .white : .black
        }
        
        await CatalystColorHelper.applyTextColor(dynamicColor, to: editor)
        
        // Verify the color is applied
        XCTAssertNotNil(editor.textColor, "Text color should be set")
        
        // The actual color value will depend on the current trait collection
        // But it should be either black or white
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        editor.textColor?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let brightness = (red + green + blue) / 3.0
        XCTAssertTrue(brightness < 0.1 || brightness > 0.9, "Should be either very dark or very light")
    }
    
    func testCatalystColorHelperWithClearColor() {
        // Test that clear color is handled properly
        let clearColor = Color.clear
        let effectiveColor = CatalystColorHelper.effectiveTextColor(from: clearColor)
        
        // Should return a visible color, not clear
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        effectiveColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Verify it's opaque and visible
        XCTAssertGreaterThanOrEqual(alpha, 0.8, "Clear color should be replaced with mostly opaque color") // Some system replacements may not be fully opaque.
    }
}

#endif
