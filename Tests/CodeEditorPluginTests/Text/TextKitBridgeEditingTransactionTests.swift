import CodeEditorPlatform
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import XCTest

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Regression: `TextKitBridge` previously called `storage.beginEditing()` /
/// `storage.endEditing()` directly on the underlying `NSTextStorage` without
/// wrapping in `NSTextContentManager.performEditingTransaction`. When a
/// viewport-layout pass or rendering-attribute enumeration was active at the
/// same time, that storage-only bracket fired
/// `NSTextContentStorageBreakOnEnumerateWhileEditing` (REVIEW.md
/// TextKit2/Critical). The fix routes every bridge mutation through
/// `withEditingTransaction(_:)`, which opens the content-manager bracket.
///
/// These tests exercise each mutation method (a) outside any outer
/// transaction and (b) nested inside an outer `performEditingTransaction`
/// to verify the bridge's transaction-counter nesting is safe.
final class TextKitBridgeEditingTransactionTests: XCTestCase {
    @MainActor
    func testReplaceCharactersWorksInsideOuterEditingTransaction() throws {
        let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        editor.text = "abcdef"
        let bridge = TextKitBridge(textView: editor)
        let contentStorage = try XCTUnwrap(bridge.textContentStorage)

        contentStorage.performEditingTransaction {
            bridge.replaceCharacters(in: NSRange(location: 1, length: 2), with: "XY")
        }

        let storage = try XCTUnwrap(contentStorage.textStorage)
        XCTAssertEqual(storage.string, "aXYdef")
    }

    @MainActor
    func testAddPersistentAttributesAppliesAndDoesNotThrowInsideNestedTransaction() throws {
        let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        editor.text = "hello world"
        let bridge = TextKitBridge(textView: editor)
        let contentStorage = try XCTUnwrap(bridge.textContentStorage)

        contentStorage.performEditingTransaction {
            bridge.addPersistentAttributes(
                [.foregroundColor: PlatformColor.red],
                range: NSRange(location: 0, length: 5)
            )
        }

        let storage = try XCTUnwrap(contentStorage.textStorage)
        let color = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? PlatformColor
        XCTAssertEqual(color, PlatformColor.red)
    }

    @MainActor
    func testRemovePersistentAttributeRoundtripUnderTransaction() throws {
        let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        editor.text = "hello world"
        let bridge = TextKitBridge(textView: editor)
        let contentStorage = try XCTUnwrap(bridge.textContentStorage)

        bridge.addPersistentAttributes(
            [.foregroundColor: PlatformColor.red, .backgroundColor: PlatformColor.blue],
            range: NSRange(location: 0, length: 5)
        )

        // Pre-condition: attributes were applied.
        let storage = try XCTUnwrap(contentStorage.textStorage)
        XCTAssertNotNil(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil))
        XCTAssertNotNil(storage.attribute(.backgroundColor, at: 0, effectiveRange: nil))

        // Removing one key inside an outer transaction must not throw and
        // must leave the other key untouched.
        contentStorage.performEditingTransaction {
            bridge.removePersistentAttribute(.foregroundColor, range: NSRange(location: 0, length: 5))
        }
        XCTAssertNil(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil))
        XCTAssertNotNil(storage.attribute(.backgroundColor, at: 0, effectiveRange: nil))

        // Bulk-remove: both keys, again under an outer transaction.
        bridge.addPersistentAttributes(
            [.foregroundColor: PlatformColor.red],
            range: NSRange(location: 0, length: 5)
        )
        contentStorage.performEditingTransaction {
            bridge.removePersistentAttributes(
                [.foregroundColor, .backgroundColor],
                range: NSRange(location: 0, length: 5)
            )
        }
        XCTAssertNil(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil))
        XCTAssertNil(storage.attribute(.backgroundColor, at: 0, effectiveRange: nil))
    }

    @MainActor
    func testAddMissingPersistentAttributesDoesNotOverwriteExistingKeys() throws {
        let editor = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        editor.text = "hello world"
        let bridge = TextKitBridge(textView: editor)
        let contentStorage = try XCTUnwrap(bridge.textContentStorage)

        // Seed a foreground color on the first 5 chars.
        bridge.addPersistentAttributes(
            [.foregroundColor: PlatformColor.red],
            range: NSRange(location: 0, length: 5)
        )

        // Apply a fallback that includes BOTH the already-set foreground key
        // and a new background key.
        contentStorage.performEditingTransaction {
            bridge.addMissingPersistentAttributes(
                [.foregroundColor: PlatformColor.green, .backgroundColor: PlatformColor.blue],
                range: NSRange(location: 0, length: 5)
            )
        }

        let storage = try XCTUnwrap(contentStorage.textStorage)
        // Foreground should still be RED (existing value preserved), and the
        // new backgroundColor should now be BLUE.
        let foreground = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? PlatformColor
        let background = storage.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? PlatformColor
        XCTAssertEqual(foreground, PlatformColor.red)
        XCTAssertEqual(background, PlatformColor.blue)
    }
}
