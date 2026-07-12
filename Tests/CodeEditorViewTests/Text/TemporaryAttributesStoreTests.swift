#if canImport(AppKit)
import AppKit
import CodeEditorTextModel
@testable import CodeEditorView
import XCTest

final class TemporaryAttributesStoreTests: XCTestCase {
    private func makeContentStorage(_ text: String) -> NSTextContentStorage {
        let contentStorage = NSTextContentStorage()
        contentStorage.textStorage?.setAttributedString(NSAttributedString(string: text))
        return contentStorage
    }

    func testApplyAddsAttributesInRange() throws {
        let contentStorage = makeContentStorage("hello world")
        let storage = try XCTUnwrap(contentStorage.textStorage)
        let store = TemporaryAttributesStore(contentStorage: contentStorage)
        let range = NSRange(location: 0, length: 5)

        store.apply([.underlineColor: NSColor.red], to: range)

        var effectiveRange = NSRange()
        let color = storage.attribute(.underlineColor, at: 0, effectiveRange: &effectiveRange) as? NSColor
        XCTAssertEqual(color, .red)
        XCTAssertEqual(effectiveRange, range)
    }

    func testClearInRangeRemovesAttributes() throws {
        let contentStorage = makeContentStorage("hello world")
        let storage = try XCTUnwrap(contentStorage.textStorage)
        let store = TemporaryAttributesStore(contentStorage: contentStorage)
        store.apply([.underlineColor: NSColor.red], to: NSRange(location: 0, length: 5))

        store.clear(in: NSRange(location: 0, length: 5))

        let color = storage.attribute(.underlineColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertNil(color)
    }

    func testClearAllRemovesEverythingWeApplied() throws {
        let contentStorage = makeContentStorage("hello world")
        let storage = try XCTUnwrap(contentStorage.textStorage)
        let store = TemporaryAttributesStore(contentStorage: contentStorage)
        store.apply([.underlineColor: NSColor.red], to: NSRange(location: 0, length: 5))
        store.apply([.underlineColor: NSColor.blue], to: NSRange(location: 6, length: 5))

        store.clearAll()

        let firstColor = storage.attribute(.underlineColor, at: 0, effectiveRange: nil) as? NSColor
        let secondColor = storage.attribute(.underlineColor, at: 6, effectiveRange: nil) as? NSColor
        XCTAssertNil(firstColor)
        XCTAssertNil(secondColor)
    }

    func testClearAllToleratesStaleRanges() throws {
        let contentStorage = makeContentStorage("hello world")
        let storage = try XCTUnwrap(contentStorage.textStorage)
        let store = TemporaryAttributesStore(contentStorage: contentStorage)
        store.apply([.underlineColor: NSColor.red], to: NSRange(location: 0, length: 5))

        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: "")

        store.clearAll()
        XCTAssertEqual(storage.length, 0)
    }
}
#endif
