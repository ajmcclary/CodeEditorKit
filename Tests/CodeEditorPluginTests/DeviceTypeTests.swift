import CodeEditorConfiguration
import CodeEditorPlatform
@testable import CodeEditorPlugin
@testable import CodeEditorView
import XCTest

#if canImport(UIKit)
import UIKit
#endif

/// Tests for DeviceType enum
final class DeviceTypeTests: XCTestCase {
    // MARK: - Basic Enum Tests

    func testAllCases() {
        let expectedCases: Set<DeviceType> = [
            .iPhone, .iPad, .mac, .appleTV, .carPlay,
            .appleWatch, .visionPro, .unspecified, .unknown
        ]

        let actualCases = Set(DeviceType.allCases)

        XCTAssertEqual(actualCases, expectedCases, "All device types should be present")
    }

    func testRawValues() {
        XCTAssertEqual(DeviceType.iPhone.rawValue, "iPhone")
        XCTAssertEqual(DeviceType.iPad.rawValue, "iPad")
        XCTAssertEqual(DeviceType.mac.rawValue, "Mac")
        XCTAssertEqual(DeviceType.appleTV.rawValue, "Apple TV")
        XCTAssertEqual(DeviceType.carPlay.rawValue, "CarPlay")
        XCTAssertEqual(DeviceType.appleWatch.rawValue, "Apple Watch")
        XCTAssertEqual(DeviceType.visionPro.rawValue, "Vision Pro")
        XCTAssertEqual(DeviceType.unspecified.rawValue, "Unspecified")
        XCTAssertEqual(DeviceType.unknown.rawValue, "Unknown")
    }

    func testDisplayNames() {
        // Display names should match raw values
        for deviceType in DeviceType.allCases {
            XCTAssertEqual(
                deviceType.displayName,
                deviceType.rawValue,
                "Display name should match raw value for \(deviceType)"
            )
        }
    }

    // MARK: - Current Device Tests

    @MainActor
    func testCurrentDevice() {
        let current = DeviceType.current

        #if canImport(AppKit)
        XCTAssertEqual(current, .mac, "On macOS, current device should be Mac")
        #elseif canImport(UIKit)
        // Can't test specific device type in unit tests, but ensure it's valid
        XCTAssertTrue(DeviceType.allCases.contains(current),
                     "Current device type should be a valid case")
        #else
        XCTAssertEqual(current, .unknown, "On unknown platform, device should be unknown")
        #endif
    }

    #if canImport(UIKit)
    func testUIKitInterfaceIdiomMapping() {
        XCTAssertEqual(DeviceType(from: .phone), .iPhone)
        XCTAssertEqual(DeviceType(from: .pad), .iPad)
        XCTAssertEqual(DeviceType(from: .tv), .appleTV)
        XCTAssertEqual(DeviceType(from: .carPlay), .carPlay)
        XCTAssertEqual(DeviceType(from: .mac), .mac)
        XCTAssertEqual(DeviceType(from: .unspecified), .unspecified)
    }
    #endif

    // MARK: - Device Capability Tests

    @MainActor
    func testSupportsHover() {
        XCTAssertTrue(DeviceType.mac.supportsHover)
        XCTAssertTrue(DeviceType.visionPro.supportsHover)

        XCTAssertFalse(DeviceType.iPhone.supportsHover)
        XCTAssertFalse(DeviceType.appleWatch.supportsHover)
        XCTAssertFalse(DeviceType.carPlay.supportsHover)
        XCTAssertFalse(DeviceType.appleTV.supportsHover)

        // iPad support depends on iOS version, so we just check it doesn't crash
        _ = DeviceType.iPad.supportsHover
    }

    func testIsTouchPrimary() {
        XCTAssertTrue(DeviceType.iPhone.isTouchPrimary)
        XCTAssertTrue(DeviceType.iPad.isTouchPrimary)
        XCTAssertTrue(DeviceType.appleWatch.isTouchPrimary)
        XCTAssertTrue(DeviceType.carPlay.isTouchPrimary)
        XCTAssertTrue(DeviceType.visionPro.isTouchPrimary)

        #if true
        XCTAssertFalse(DeviceType.mac.isTouchPrimary)
        #endif

        XCTAssertFalse(DeviceType.appleTV.isTouchPrimary)
        XCTAssertFalse(DeviceType.unknown.isTouchPrimary)
    }

    func testHasLimitedScreenSpace() {
        XCTAssertTrue(DeviceType.iPhone.hasLimitedScreenSpace)
        XCTAssertTrue(DeviceType.appleWatch.hasLimitedScreenSpace)
        XCTAssertTrue(DeviceType.carPlay.hasLimitedScreenSpace)

        XCTAssertFalse(DeviceType.iPad.hasLimitedScreenSpace)
        XCTAssertFalse(DeviceType.mac.hasLimitedScreenSpace)
        XCTAssertFalse(DeviceType.appleTV.hasLimitedScreenSpace)
        XCTAssertFalse(DeviceType.visionPro.hasLimitedScreenSpace)
    }

    @MainActor
    func testHasNotch() {
        // Most devices don't have a notch
        XCTAssertFalse(DeviceType.iPad.hasNotch)
        XCTAssertFalse(DeviceType.mac.hasNotch)
        XCTAssertFalse(DeviceType.appleTV.hasNotch)
        XCTAssertFalse(DeviceType.carPlay.hasNotch)
        XCTAssertFalse(DeviceType.appleWatch.hasNotch)
        XCTAssertFalse(DeviceType.visionPro.hasNotch)

        // iPhone notch detection depends on runtime environment
        _ = DeviceType.iPhone.hasNotch
    }

    // MARK: - Configuration Recommendation Tests

    func testRecommendedConfigurations() {
        // iPhone should use minimal config
        let iPhoneConfig = DeviceType.iPhone.recommendedConfiguration()
        XCTAssertEqual(iPhoneConfig, EditorConfiguration.minimal)

        // Mac should use default config
        let macConfig = DeviceType.mac.recommendedConfiguration()
        XCTAssertEqual(macConfig, EditorConfiguration.default)

        // Apple TV should use presentation config with modifications
        let tvConfig = DeviceType.appleTV.recommendedConfiguration()
        XCTAssertEqual(tvConfig.display.fontSize, 24)
        XCTAssertFalse(tvConfig.display.isLineNumbersEnabled)

        // CarPlay should use read-only config
        let carConfig = DeviceType.carPlay.recommendedConfiguration()
        XCTAssertEqual(carConfig, EditorConfiguration.readOnly)

        // iPad should have custom config
        let iPadConfig = DeviceType.iPad.recommendedConfiguration()
        XCTAssertTrue(iPadConfig.display.isLineNumbersEnabled)
        XCTAssertFalse(iPadConfig.display.isMinimapVisible)
        XCTAssertEqual(iPadConfig.display.fontSize, 14)

        // Vision Pro should have comfort-optimized config
        let visionConfig = DeviceType.visionPro.recommendedConfiguration()
        XCTAssertEqual(visionConfig.display.fontSize, 16)
        XCTAssertEqual(visionConfig.layout.lineHeightMultiple, 1.3)
    }

    // MARK: - Comparable Tests

    func testComparable() {
        let devices = [DeviceType.iPhone, DeviceType.iPad, DeviceType.mac]
        let sorted = devices.sorted()

        // Should be sorted alphabetically by raw value
        XCTAssertEqual(sorted[0], .mac) // "Mac"
        XCTAssertEqual(sorted[1], .iPad) // "iPad"
        XCTAssertEqual(sorted[2], .iPhone) // "iPhone"
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for deviceType in DeviceType.allCases {
            let encoded = try encoder.encode(deviceType)
            let decoded = try decoder.decode(DeviceType.self, from: encoded)

            XCTAssertEqual(
                decoded,
                deviceType,
                "Device type \(deviceType) should encode/decode correctly"
            )
        }
    }

    func testDecodeInvalidValue() throws {
        let decoder = JSONDecoder()
        let invalidJSON = Data("\"InvalidDeviceType\"".utf8)

        let decoded = try decoder.decode(DeviceType.self, from: invalidJSON)
        XCTAssertEqual(decoded, .unknown, "Invalid device types should decode to .unknown")
    }

    // MARK: - Integration Tests

    @MainActor
    func testPlatformCapabilitiesIntegration() {
        let capabilities = CodeEditorDependencies.makePlatformCapabilities()
        let deviceType = capabilities.deviceType

        XCTAssertTrue(DeviceType.allCases.contains(deviceType),
                     "PlatformCapabilities should return a valid device type")

        // Verify that we're using the new enum-based API
        XCTAssertNotNil(deviceType.displayName, "Device type should have a display name")
        XCTAssertNotNil(deviceType.recommendedConfiguration(), "Device type should provide recommended configuration")
    }
}
