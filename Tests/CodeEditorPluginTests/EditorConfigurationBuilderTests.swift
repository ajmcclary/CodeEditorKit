#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorPlugin
import XCTest

final class EditorConfigurationBuilderTests: XCTestCase {
    deinit {}

    // MARK: - Basic Builder Tests

    func testDefaultBuilder() {
        let config = EditorConfigurationBuilder().build()
        XCTAssertEqual(config, EditorConfiguration())
    }

    func testBuilderFromBase() {
        let base = EditorConfiguration.minimal
        let config = EditorConfigurationBuilder(base: base).build()
        XCTAssertEqual(config, base)
    }

    // MARK: - Display Settings Tests

    func testFontSize() {
        let config = EditorConfigurationBuilder()
            .fontSize(16)
            .build()
        XCTAssertEqual(config.display.fontSize, 16)
    }

    func testShowLineNumbers() {
        let config = EditorConfigurationBuilder()
            .isLineNumbersEnabled(false)
            .build()
        XCTAssertFalse(config.display.isLineNumbersEnabled)
    }

    func testEnableSyntaxHighlighting() {
        let config = EditorConfigurationBuilder()
            .enableSyntaxHighlighting(false)
            .build()
        XCTAssertFalse(config.display.enableSyntaxHighlighting)
    }

    func testHighlightSelectedLine() {
        let config = EditorConfigurationBuilder()
            .highlightSelectedLine(false)
            .build()
        XCTAssertFalse(config.display.highlightSelectedLine)
    }

    func testSelectedLineHighlightColor() {
        let color = PlatformColors.systemRed
        let config = EditorConfigurationBuilder()
            .selectedLineHighlightColor(color)
            .build()
        XCTAssertEqual(config.display.selectedLineHighlightColor, color)
    }

    func testEnableAnnotations() {
        let config = EditorConfigurationBuilder()
            .enableAnnotations(false)
            .build()
        XCTAssertFalse(config.display.enableAnnotations)
    }

    func testShowInvisibleCharacters() {
        let config = EditorConfigurationBuilder()
            .showInvisibleCharacters(true)
            .build()
        XCTAssertTrue(config.display.showInvisibleCharacters)
    }

    // MARK: - Layout Settings Tests

    func testTabWidth() {
        let config = EditorConfigurationBuilder()
            .tabWidth(2)
            .build()
        XCTAssertEqual(config.layout.tabWidth, 2)
    }

    func testInsertSpacesForTabs() {
        let config = EditorConfigurationBuilder()
            .insertSpacesForTabs(false)
            .build()
        XCTAssertFalse(config.layout.insertSpacesForTabs)
    }

    func testWrapLines() {
        let config = EditorConfigurationBuilder()
            .wrapLines(true)
            .build()
        XCTAssertTrue(config.layout.wrapLines)
    }

    func testLineSpacing() {
        let config = EditorConfigurationBuilder()
            .lineSpacing(1.5)
            .build()
        XCTAssertEqual(config.layout.lineHeightMultiple, 1.5)
    }

    // MARK: - Behavior Settings Tests

    func testIsEditable() {
        let config = EditorConfigurationBuilder()
            .isEditable(false)
            .build()
        XCTAssertFalse(config.behavior.isEditable)
    }

    func testAutoIndent() {
        let config = EditorConfigurationBuilder()
            .autoIndent(false)
            .build()
        XCTAssertFalse(config.behavior.autoIndent)
    }

    func testEnableCodeCompletion() {
        let config = EditorConfigurationBuilder()
            .enableCodeCompletion(false)
            .build()
        XCTAssertFalse(config.behavior.enableCodeCompletion)
    }

    func testEnableSpellCheck() {
        let config = EditorConfigurationBuilder()
            .enableSpellCheck(true)
            .build()
        XCTAssertTrue(config.behavior.isContinuousSpellCheckingEnabled)
    }

    // MARK: - Performance Settings Tests

    func testUseHardwareAcceleration() {
        let config = EditorConfigurationBuilder()
            .useHardwareAcceleration(false)
            .build()
        XCTAssertFalse(config.performance.useHardwareAcceleration)
    }

    func testMaxHighlightingLength() {
        let config = EditorConfigurationBuilder()
            .maxHighlightingLength(100_000)
            .build()
        XCTAssertEqual(config.performance.maxSyntaxHighlightingLength, 100_000)
    }

    // MARK: - Convenience Methods Tests

    func testLanguageSwift() {
        let config = EditorConfigurationBuilder()
            .language(.swift)
            .build()
        XCTAssertTrue(config.display.enableSyntaxHighlighting)
        XCTAssertTrue(config.behavior.enableCodeCompletion)
        XCTAssertTrue(config.behavior.autoIndent)
        XCTAssertEqual(config.layout.tabWidth, 4)
        XCTAssertTrue(config.layout.insertSpacesForTabs)
    }

    func testLanguagePython() {
        let config = EditorConfigurationBuilder()
            .language(.python)
            .build()
        XCTAssertTrue(config.display.enableSyntaxHighlighting)
        XCTAssertTrue(config.behavior.enableCodeCompletion)
        XCTAssertTrue(config.behavior.autoIndent)
        XCTAssertEqual(config.layout.tabWidth, 4)
        XCTAssertTrue(config.layout.insertSpacesForTabs)
    }

    func testLanguageJavaScript() {
        let config = EditorConfigurationBuilder()
            .language(.javascript)
            .build()
        XCTAssertTrue(config.display.enableSyntaxHighlighting)
        XCTAssertTrue(config.behavior.enableCodeCompletion)
        XCTAssertTrue(config.behavior.autoIndent)
        XCTAssertEqual(config.layout.tabWidth, 2)
        XCTAssertTrue(config.layout.insertSpacesForTabs)
    }

    func testLanguageMarkdown() {
        let config = EditorConfigurationBuilder()
            .language(.markdown)
            .build()
        XCTAssertTrue(config.display.enableSyntaxHighlighting)
        XCTAssertFalse(config.behavior.enableCodeCompletion)
        XCTAssertFalse(config.behavior.autoIndent)
        XCTAssertTrue(config.layout.wrapLines)
        XCTAssertTrue(config.behavior.isContinuousSpellCheckingEnabled)
    }

    func testLanguagePlainText() {
        let config = EditorConfigurationBuilder()
            .language(.plainText)
            .build()
        XCTAssertFalse(config.display.enableSyntaxHighlighting)
        XCTAssertFalse(config.behavior.enableCodeCompletion)
        XCTAssertFalse(config.behavior.autoIndent)
        XCTAssertTrue(config.layout.wrapLines)
        XCTAssertTrue(config.behavior.isContinuousSpellCheckingEnabled)
    }

    func testPresentationMode() {
        let config = EditorConfigurationBuilder()
            .presentationMode()
            .build()
        XCTAssertEqual(config.display.fontSize, 18)
        XCTAssertFalse(config.display.isLineNumbersEnabled)
        XCTAssertFalse(config.display.enableAnnotations)
        XCTAssertFalse(config.display.highlightSelectedLine)
        XCTAssertTrue(config.layout.wrapLines)
    }

    func testCodeReviewMode() {
        let config = EditorConfigurationBuilder()
            .codeReviewMode()
            .build()
        XCTAssertFalse(config.behavior.isEditable)
        XCTAssertTrue(config.display.isLineNumbersEnabled)
        XCTAssertTrue(config.display.enableAnnotations)
        XCTAssertTrue(config.display.highlightSelectedLine)
        XCTAssertTrue(config.display.enableSyntaxHighlighting)
    }

    // MARK: - Chaining Tests

    func testMethodChaining() {
        let config = EditorConfigurationBuilder()
            .fontSize(14)
            .isLineNumbersEnabled(true)
            .tabWidth(4)
            .wrapLines(false)
            .enableSyntaxHighlighting(true)
            .enableCodeCompletion(true)
            .build()

        XCTAssertEqual(config.display.fontSize, 14)
        XCTAssertTrue(config.display.isLineNumbersEnabled)
        XCTAssertEqual(config.layout.tabWidth, 4)
        XCTAssertFalse(config.layout.wrapLines)
        XCTAssertTrue(config.display.enableSyntaxHighlighting)
        XCTAssertTrue(config.behavior.enableCodeCompletion)
    }

    func testComplexConfiguration() {
        let config = EditorConfigurationBuilder()
            .fontSize(16)
            .isLineNumbersEnabled(true)
            .highlightSelectedLine(true)
            .selectedLineHighlightColor(PlatformColors.systemYellow)
            .enableAnnotations(true)
            .showInvisibleCharacters(false)
            .tabWidth(2)
            .insertSpacesForTabs(true)
            .wrapLines(false)
            .lineSpacing(1.3)
            .isEditable(true)
            .autoIndent(true)
            .enableCodeCompletion(true)
            .enableSpellCheck(false)
            .useHardwareAcceleration(true)
            .maxHighlightingLength(200_000)
            .build()

        // Display assertions
        XCTAssertEqual(config.display.fontSize, 16)
        XCTAssertTrue(config.display.isLineNumbersEnabled)
        XCTAssertTrue(config.display.highlightSelectedLine)
        XCTAssertEqual(config.display.selectedLineHighlightColor, PlatformColors.systemYellow)
        XCTAssertTrue(config.display.enableAnnotations)
        XCTAssertFalse(config.display.showInvisibleCharacters)

        // Layout assertions
        XCTAssertEqual(config.layout.tabWidth, 2)
        XCTAssertTrue(config.layout.insertSpacesForTabs)
        XCTAssertFalse(config.layout.wrapLines)
        XCTAssertEqual(config.layout.lineHeightMultiple, 1.3)

        // Behavior assertions
        XCTAssertTrue(config.behavior.isEditable)
        XCTAssertTrue(config.behavior.autoIndent)
        XCTAssertTrue(config.behavior.enableCodeCompletion)
        XCTAssertFalse(config.behavior.isContinuousSpellCheckingEnabled)

        // Performance assertions
        XCTAssertTrue(config.performance.useHardwareAcceleration)
        XCTAssertEqual(config.performance.maxSyntaxHighlightingLength, 200_000)
    }

    // MARK: - Extension Tests

    func testStaticBuilder() {
        let builder = EditorConfiguration.builder()
        XCTAssertNotNil(builder)
        let config = builder.build()
        XCTAssertEqual(config, EditorConfiguration())
    }

    func testInstanceBuilder() {
        let base = EditorConfiguration.minimal
        let builder = base.builder()
        XCTAssertNotNil(builder)
        let config = builder.build()
        XCTAssertEqual(config, base)
    }

    // MARK: - Quick Configuration Tests

    func testQuickSwiftConfiguration() {
        let config = EditorConfigurationBuilder.swift()
        XCTAssertTrue(config.display.enableSyntaxHighlighting)
        XCTAssertTrue(config.behavior.enableCodeCompletion)
        XCTAssertEqual(config.display.fontSize, 14)
        XCTAssertEqual(config.layout.tabWidth, 4)
    }

    func testQuickWebConfiguration() {
        let config = EditorConfigurationBuilder.web()
        XCTAssertTrue(config.display.enableSyntaxHighlighting)
        XCTAssertTrue(config.behavior.enableCodeCompletion)
        XCTAssertEqual(config.display.fontSize, 14)
        XCTAssertEqual(config.layout.tabWidth, 2)
    }

    func testQuickPythonConfiguration() {
        let config = EditorConfigurationBuilder.python()
        XCTAssertTrue(config.display.enableSyntaxHighlighting)
        XCTAssertTrue(config.behavior.enableCodeCompletion)
        XCTAssertEqual(config.display.fontSize, 14)
        XCTAssertEqual(config.layout.tabWidth, 4)
    }

    func testQuickDocumentationConfiguration() {
        let config = EditorConfigurationBuilder.documentation()
        XCTAssertTrue(config.display.enableSyntaxHighlighting)
        XCTAssertEqual(config.display.fontSize, 16)
        XCTAssertTrue(config.layout.wrapLines)
        XCTAssertTrue(config.behavior.isContinuousSpellCheckingEnabled)
    }

    func testQuickReadOnlyConfiguration() {
        let config = EditorConfigurationBuilder.readOnly()
        XCTAssertFalse(config.behavior.isEditable)
        XCTAssertTrue(config.display.isLineNumbersEnabled)
        XCTAssertTrue(config.display.enableAnnotations)
        XCTAssertTrue(config.display.highlightSelectedLine)
        XCTAssertTrue(config.display.enableSyntaxHighlighting)
        XCTAssertEqual(config.display.fontSize, 14)
    }

    // MARK: - Validation Tests

    func testBuildWithValidation_ValidConfiguration() {
        let result = EditorConfigurationBuilder()
            .fontSize(14)
            .isLineNumbersEnabled(true)
            .buildWithValidation()

        switch result {
        case .success(let config):
            XCTAssertEqual(config.display.fontSize, 14)
            XCTAssertTrue(config.display.isLineNumbersEnabled)

        case .failure(let error):
            XCTFail("Expected success but got validation error: \(error.localizedDescription)")
        }
    }

    func testBuildWithValidation_InvalidFontSize() {
        let result = EditorConfigurationBuilder()
            .fontSize(0) // Invalid: too small
            .buildWithValidation()

        // The validator should auto-fix this, so we expect success
        switch result {
        case .success(let config):
            // The original config is returned, not the auto-fixed one
            XCTAssertEqual(config.display.fontSize, 0)

        case .failure:
            XCTFail("Expected success with auto-fixable issues")
        }
    }

    func testBuildWithReport_ValidConfiguration() {
        let (config, report) = EditorConfigurationBuilder()
            .fontSize(14)
            .isLineNumbersEnabled(true)
            .buildWithReport()

        XCTAssertEqual(config.display.fontSize, 14)
        XCTAssertTrue(config.display.isLineNumbersEnabled)
        XCTAssertFalse(report.hasIssues)
        XCTAssertTrue(report.summary.contains("✅"))
    }

    func testBuildWithReport_WithAutoFixes() {
        let (config, report) = EditorConfigurationBuilder()
            .fontSize(0) // Invalid: will be auto-fixed
            .tabWidth(0) // Invalid: will be auto-fixed
            .buildWithReport()

        // Check that fixes were applied
        XCTAssertGreaterThan(config.display.fontSize, 0)
        XCTAssertGreaterThan(config.layout.tabWidth, 0)

        // Check report
        XCTAssertTrue(report.hasIssues)
        XCTAssertFalse(report.appliedFixes.isEmpty)
        XCTAssertTrue(report.summary.contains("🔧"))
    }

    func testBuildWithValidation_ComparisonWithBuild() {
        let builder = EditorConfigurationBuilder()
            .fontSize(0) // Invalid
            .tabWidth(0) // Invalid

        // Test build() - should auto-fix
        let buildConfig = builder.build()
        XCTAssertGreaterThan(buildConfig.display.fontSize, 0)
        XCTAssertGreaterThan(buildConfig.layout.tabWidth, 0)

        // Test buildWithValidation() - should not auto-fix
        let validationResult = builder.buildWithValidation()
        switch validationResult {
        case .success(let config):
            XCTAssertEqual(config.display.fontSize, 0)
            XCTAssertEqual(config.layout.tabWidth, 0)

        case .failure:
            XCTFail("Expected success with auto-fixable issues")
        }

        // Test buildWithReport() - should auto-fix and report
        let (reportConfig, report) = builder.buildWithReport()
        XCTAssertGreaterThan(reportConfig.display.fontSize, 0)
        XCTAssertGreaterThan(reportConfig.layout.tabWidth, 0)
        XCTAssertTrue(report.hasIssues)
        XCTAssertFalse(report.appliedFixes.isEmpty)
    }
}
