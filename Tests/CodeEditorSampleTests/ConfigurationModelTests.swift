import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

@MainActor
final class ConfigurationModelTests: XCTestCase {
    func testInitialDefaultMatchesPreset() {
        let model = ConfigurationModel()
        XCTAssertEqual(
            model.current.display.isLineNumbersEnabled,
            PresetCatalog.default.configuration.display.isLineNumbersEnabled
        )
    }

    func testCurrentRoundTripsAssignment() {
        let model = ConfigurationModel()
        model.current = EditorConfiguration.minimal
        XCTAssertEqual(
            model.current.display.isLineNumbersEnabled,
            EditorConfiguration.minimal.display.isLineNumbersEnabled
        )
    }
}
