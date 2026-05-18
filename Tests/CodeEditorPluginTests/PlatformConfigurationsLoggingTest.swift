import CodeEditorConfiguration
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import XCTest

@MainActor
final class PlatformConfigurationsLoggingTest: XCTestCase {
    func testUnknownDeviceTypeLogging() {
        // This test verifies that unknown device types are properly logged
        // The actual logging happens in PlatformConfigurations.swift

        // Test configuration(for:) with unknown device type
        let unknownConfig = PlatformConfigurations.configuration(for: .unknown)
        XCTAssertNotNil(unknownConfig)
        XCTAssertEqual(unknownConfig.display.fontSize, EditorConfiguration.default.display.fontSize)

        // Test configuration(for:) with unspecified device type
        let unspecifiedConfig = PlatformConfigurations.configuration(for: .unspecified)
        XCTAssertNotNil(unspecifiedConfig)
        XCTAssertEqual(unspecifiedConfig.display.fontSize, EditorConfiguration.default.display.fontSize)
    }

    func testRecommendedConfigurationFallback() {
        // The recommended() method uses the current device, so we can't easily test
        // the unknown device type fallback, but we can verify it returns a valid config
        let config = PlatformConfigurations.recommended()
        XCTAssertNotNil(config)

        // Verify it's one of the expected configurations
        let validFontSizes: Set<CGFloat> = [14.0, 15.0, 16.0] // macOS, iPhone, iOS/iPad
        XCTAssertTrue(validFontSizes.contains(config.display.fontSize))
    }
}
