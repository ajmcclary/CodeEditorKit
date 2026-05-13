#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
import XCTest

final class TemporaryAttributesStoreTests: XCTestCase {
    private func makeStorage(_ text: String) -> NSTextStorage {
        NSTextStorage(string: text, attributes: [:])
    }

    func testApplyAddsAttributesInRange() {
        let storage = makeStorage("hello world")
        let store = TemporaryAttributesStore(textStorage: storage)
        let range = NSRange(location: 0, length: 5)

        store.apply([.underlineColor: NSColor.red], to: range)

        var effectiveRange = NSRange()
        let color = storage.attribute(.underlineColor, at: 0, effectiveRange: &effectiveRange) as? NSColor
        XCTAssertEqual(color, .red)
        XCTAssertEqual(effectiveRange, range)
    }

    func testClearInRangeRemovesAttributes() {
        let storage = makeStorage("hello world")
        let store = TemporaryAttributesStore(textStorage: storage)
        store.apply([.underlineColor: NSColor.red], to: NSRange(location: 0, length: 5))

        store.clear(in: NSRange(location: 0, length: 5))

        let color = storage.attribute(.underlineColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertNil(color)
    }

    func testClearAllRemovesEverythingWeApplied() {
        let storage = makeStorage("hello world")
        let store = TemporaryAttributesStore(textStorage: storage)
        store.apply([.underlineColor: NSColor.red], to: NSRange(location: 0, length: 5))
        store.apply([.underlineColor: NSColor.blue], to: NSRange(location: 6, length: 5))

        store.clearAll()

        let firstColor = storage.attribute(.underlineColor, at: 0, effectiveRange: nil) as? NSColor
        let secondColor = storage.attribute(.underlineColor, at: 6, effectiveRange: nil) as? NSColor
        XCTAssertNil(firstColor)
        XCTAssertNil(secondColor)
    }

    func testClearAllToleratesStaleRanges() {
        let storage = makeStorage("hello world")
        let store = TemporaryAttributesStore(textStorage: storage)
        store.apply([.underlineColor: NSColor.red], to: NSRange(location: 0, length: 5))

        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: "")

        store.clearAll()
        XCTAssertEqual(storage.length, 0)
    }
}
#endif
