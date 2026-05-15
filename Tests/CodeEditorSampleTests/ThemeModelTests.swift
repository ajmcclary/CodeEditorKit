@testable import CodeEditorSample
import XCTest

@MainActor
final class ThemeModelTests: XCTestCase {
    func testInitialDefaultMatchesCatalog() {
        let model = ThemeModel()
        XCTAssertEqual(model.current.id, ThemeCatalog.default.id)
    }

    func testCurrentRoundTripsAssignment() {
        let model = ThemeModel()
        let alternate = ThemeCatalog.all.first { $0.id != model.current.id }
        guard let alternate else {
            XCTFail("ThemeCatalog.all should expose more than one theme")
            return
        }
        model.current = alternate
        XCTAssertEqual(model.current.id, alternate.id)
    }
}
