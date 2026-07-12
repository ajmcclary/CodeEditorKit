#if canImport(AppKit)
import AppKit
@testable import CodeEditorSwiftUI
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorView
import XCTest

final class ContextMenuTests: XCTestCase {
    // MARK: - Properties

    private var builder = ContextMenuBuilder()

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        builder = ContextMenuBuilder()
    }

    override func tearDown() {
        builder = ContextMenuBuilder()
        super.tearDown()
    }

    deinit {
        // Cleanup
    }

    // MARK: - Basic Menu Building Tests

    @MainActor
    func testEmptyMenu() async {
        let menu = builder.build()

        #if canImport(AppKit)
        XCTAssertEqual(menu.items.count, 0)
        #else
        XCTAssertEqual(menu.children.count, 0)
        #endif
    }

    @MainActor
    func testAddSingleAction() async {
        let action = ContextMenuAction(title: "Cut") {
            // Action handler
        }
        builder.addAction(action)
        let menu = builder.build()

        #if canImport(AppKit)
        XCTAssertEqual(menu.items.count, 1)
        XCTAssertEqual(menu.items[0].title, "Cut")
        #else
        XCTAssertEqual(menu.children.count, 1)
        if let uiAction = menu.children.first as? UIAction {
            XCTAssertEqual(uiAction.title, "Cut")
        }
        #endif
    }

    @MainActor
    func testAddMultipleActions() async {
        builder.addAction(ContextMenuAction(title: "Cut") {})
        builder.addAction(ContextMenuAction(title: "Copy") {})
        builder.addAction(ContextMenuAction(title: "Paste") {})

        let menu = builder.build()

        #if canImport(AppKit)
        XCTAssertEqual(menu.items.count, 3)
        XCTAssertEqual(menu.items[0].title, "Cut")
        XCTAssertEqual(menu.items[1].title, "Copy")
        XCTAssertEqual(menu.items[2].title, "Paste")
        #else
        XCTAssertEqual(menu.children.count, 3)
        #endif
    }

    // MARK: - Separator Tests

    @MainActor
    func testAddSeparator() async {
        builder.addAction(ContextMenuAction(title: "Cut") {})
        builder.addSeparator()
        builder.addAction(ContextMenuAction(title: "Copy") {})

        let menu = builder.build()

        #if canImport(AppKit)
        XCTAssertEqual(menu.items.count, 3)
        XCTAssertEqual(menu.items[0].title, "Cut")
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        XCTAssertEqual(menu.items[2].title, "Copy")
        #else
        XCTAssertEqual(menu.children.count, 3)
        // On iOS, separators are inline menus
        if let separator = menu.children[1] as? UIMenu {
            XCTAssertTrue(separator.options.contains(.displayInline))
            XCTAssertEqual(separator.children.count, 0)
        }
        #endif
    }

    @MainActor
    func testMultipleSeparators() async {
        builder.addAction(ContextMenuAction(title: "Item 1") {})
        builder.addSeparator()
        builder.addAction(ContextMenuAction(title: "Item 2") {})
        builder.addSeparator()
        builder.addAction(ContextMenuAction(title: "Item 3") {})

        let menu = builder.build()

        #if canImport(AppKit)
        XCTAssertEqual(menu.items.count, 5)
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        XCTAssertTrue(menu.items[3].isSeparatorItem)
        #else
        XCTAssertEqual(menu.children.count, 5)
        #endif
    }

    // MARK: - Keyboard Shortcut Tests

    @MainActor
    func testActionWithKeyboardShortcut() async {
        let action = ContextMenuAction(
            title: "Copy",
            keyEquivalent: "c",
            modifiers: [.command]
        ) {}

        builder.addAction(action)
        let menu = builder.build()

        #if canImport(AppKit)
        XCTAssertEqual(menu.items.count, 1)
        XCTAssertEqual(menu.items[0].keyEquivalent, "c")
        XCTAssertTrue(menu.items[0].keyEquivalentModifierMask.contains(.command))
        #else
        XCTAssertEqual(menu.children.count, 1)
        #endif
    }

    // MARK: - State Management Tests

    @MainActor
    func testEnabledState() async {
        builder.addAction(ContextMenuAction(title: "Cut", isEnabled: false) {})
        builder.addAction(ContextMenuAction(title: "Copy", isEnabled: true) {})

        let menu = builder.build()

        #if canImport(AppKit)
        XCTAssertEqual(menu.items.count, 2)
        XCTAssertFalse(menu.items[0].isEnabled)
        XCTAssertTrue(menu.items[1].isEnabled)
        #else
        XCTAssertEqual(menu.children.count, 2)
        if let cutAction = menu.children[0] as? UIAction {
            XCTAssertTrue(cutAction.attributes.contains(.disabled))
        }
        if let copyAction = menu.children[1] as? UIAction {
            XCTAssertFalse(copyAction.attributes.contains(.disabled))
        }
        #endif
    }

    // MARK: - Builder Tests

    @MainActor
    func testBuilderActions() async {
        // Test that actions are preserved across builds
        builder.addAction(ContextMenuAction(title: "Item 1") {})

        let menu1 = builder.build()

        builder.addAction(ContextMenuAction(title: "Item 2") {})
        let menu2 = builder.build()

        #if canImport(AppKit)
        XCTAssertEqual(menu1.items.count, 1)
        XCTAssertEqual(menu2.items.count, 2)
        #else
        XCTAssertEqual(menu1.children.count, 1)
        XCTAssertEqual(menu2.children.count, 2)
        #endif
    }

    // MARK: - Custom Actions Tests

    @MainActor
    func testCustomActionHandler() async {
        let customAction = ContextMenuAction(title: "Custom Action") {
            // Action handler - execution testing is platform-specific
            // and would require more complex setup
        }

        builder.addAction(customAction)
        let menu = builder.build()

        #if canImport(AppKit)
        XCTAssertEqual(menu.items.count, 1)
        XCTAssertEqual(menu.items[0].title, "Custom Action")

        // Verify that a target is set for the action
        XCTAssertNotNil(menu.items[0].target)
        XCTAssertNotNil(menu.items[0].action)
        #else
        XCTAssertEqual(menu.children.count, 1)
        if let uiAction = menu.children.first as? UIAction {
            XCTAssertEqual(uiAction.title, "Custom Action")
        }
        #endif
    }

    // MARK: - Platform-Specific Tests

    #if canImport(UIKit)
    @MainActor
    func testUIMenuProperties() async {
        builder.addAction(ContextMenuAction(title: "Test Item") {})
        let menu = builder.build()

        // menu is already typed as UIMenu through PlatformContextMenu
        XCTAssertEqual(menu.children.count, 1)
    }
    #endif

    #if canImport(AppKit)
    @MainActor
    func testNSMenuProperties() async {
        builder.addAction(ContextMenuAction(title: "Test Item") {})

        let menu = builder.build()

        XCTAssertFalse(menu.autoenablesItems)
        XCTAssertEqual(menu.items.count, 1)
    }
    #endif
}
