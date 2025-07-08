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
            XCTAssertGreaterThan(red + green + blue, 0.1, "Color should be visible")
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
}

#endif
