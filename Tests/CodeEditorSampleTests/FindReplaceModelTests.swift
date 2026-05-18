#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import XCTest

@MainActor
final class FindReplaceModelTests: XCTestCase {
    func testSearchRequestEqualsWhenIdenticalInputs() {
        let model = FindReplaceModel()
        model.findText = "alpha"
        let documentID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        let lhs = model.searchRequest(activeDocumentID: documentID)
        let rhs = model.searchRequest(activeDocumentID: documentID)
        XCTAssertEqual(lhs, rhs)
    }

    func testSearchRequestDiffersWhenOptionsChange() {
        let model = FindReplaceModel()
        model.findText = "alpha"
        let first = model.searchRequest(activeDocumentID: nil)
        model.options.caseSensitive = true
        let second = model.searchRequest(activeDocumentID: nil)
        XCTAssertNotEqual(first, second)
    }

    func testSearchRequestDiffersWhenDocumentRevisionChanges() {
        let model = FindReplaceModel()
        model.findText = "alpha"
        let first = model.searchRequest(activeDocumentID: nil)
        model.markDocumentEdited()
        let second = model.searchRequest(activeDocumentID: nil)
        XCTAssertNotEqual(first, second)
    }

    func testEmptyPatternCallsClearSearch() async {
        let stub = FindReplaceControllerStub()
        let model = FindReplaceModel()
        model.findText = ""

        await model.runSearch(controller: stub)

        XCTAssertEqual(stub.clearSearchCalls, 1)
        XCTAssertEqual(stub.findCalls.count, 0)
    }

    func testRegexValidationFailureStoresLastError() async {
        let stub = FindReplaceControllerStub()
        let model = FindReplaceModel()
        model.findText = "[invalid"
        model.options.useRegularExpression = true

        await model.runSearch(controller: stub)

        XCTAssertEqual(model.lastError, .invalidRegex)
        XCTAssertEqual(stub.findCalls.count, 0)
    }

    func testRunSearchClearsLastErrorOnSuccess() async {
        let stub = FindReplaceControllerStub(matchCount: 2, currentMatchIndex: 0)
        let model = FindReplaceModel()
        model.findText = "[invalid"
        model.options.useRegularExpression = true
        await model.runSearch(controller: stub)
        XCTAssertEqual(model.lastError, .invalidRegex)

        model.findText = "alpha"
        model.options.useRegularExpression = false
        await model.runSearch(controller: stub)

        XCTAssertNil(model.lastError)
        XCTAssertEqual(stub.findCalls.last, "alpha")
    }

    func testCloseClearsControllerAndHidesOverlay() {
        let stub = FindReplaceControllerStub()
        let model = FindReplaceModel()
        model.isOverlayVisible = true

        model.close(controller: stub)

        XCTAssertFalse(model.isOverlayVisible)
        XCTAssertEqual(stub.clearSearchCalls, 1)
    }

    func testCanReplaceMatrix() {
        let model = FindReplaceModel()
        XCTAssertFalse(model.canReplace(matchCount: 0, isReadOnly: false))
        XCTAssertFalse(model.canReplace(matchCount: 3, isReadOnly: true))
        XCTAssertTrue(model.canReplace(matchCount: 3, isReadOnly: false))
    }
}

@MainActor
final class FindReplaceControllerStub: FindReplaceControlling {
    var matchCount: Int
    var currentMatchIndex: Int
    private(set) var findCalls: [String] = []
    private(set) var clearSearchCalls: Int = 0
    private(set) var replaceCurrentCalls: [String] = []
    private(set) var replaceAllCalls: [(String, String)] = []

    init(matchCount: Int = 0, currentMatchIndex: Int = -1) {
        self.matchCount = matchCount
        self.currentMatchIndex = currentMatchIndex
    }

    func find(_ pattern: String, options _: SearchOptions?) async -> [SearchResult] {
        findCalls.append(pattern)
        return []
    }

    @discardableResult func findNext() -> SearchResult? { nil }
    @discardableResult func findPrevious() -> SearchResult? { nil }

    @discardableResult
    func replaceCurrent(with replacement: String) -> Bool {
        replaceCurrentCalls.append(replacement)
        return true
    }

    @discardableResult
    func replaceAll(_ pattern: String, with replacement: String, options _: SearchOptions?) async -> Int {
        replaceAllCalls.append((pattern, replacement))
        return 0
    }

    func clearSearch() {
        clearSearchCalls += 1
        matchCount = 0
        currentMatchIndex = -1
    }
}
#endif
