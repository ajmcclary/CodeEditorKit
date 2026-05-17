import CodeEditorLanguages
import CodeEditorPlugin
@testable import CodeEditorSample
import XCTest

final class SampleCodeCatalogTests: XCTestCase {
    func testPlainTextSampleReferencesCurrentLanguageCount() {
        let sample = SampleCodeCatalog.text(for: .plainText)
        let languageCount = Language.allCases.count

        XCTAssertTrue(sample.contains("Editor renders \(languageCount) languages"))
        XCTAssertFalse(sample.contains("20+ languages"))
    }
}
