//
//  ContextMenuTests.swift
//  CodeEditorPluginTests
//
//  Created on 2025-06-27.
//

@testable import CodeEditorPlugin
import XCTest
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
final class ContextMenuTests: XCTestCase {
    // MARK: - Setup
    
    private var coordinator: CrossPlatformCoordinator?
    private var textView: CodeEditorView?
    
    override func setUp() async throws {
        await MainActor.run {
            coordinator = CrossPlatformCoordinator.shared
            textView = CodeEditorView(frame: .zero)
            textView?.text = "Hello World\nThis is a test"
        }
    }
    
    override func tearDown() async throws {
        await MainActor.run {
            coordinator = nil
            textView = nil
        }
    }
    
    // MARK: - Action Creation Tests
    
    func testContextMenuActionCreation() {
        var actionExecuted = false
        let action = ContextMenuAction(
            title: "Test Action",
            keyEquivalent: "t",
            isEnabled: true
        ) {
            actionExecuted = true
        }
        
        XCTAssertEqual(action.title, "Test Action")
        XCTAssertEqual(action.keyEquivalent, "t")
        XCTAssertTrue(action.isEnabled)
        XCTAssertFalse(action.isSeparator)
        
        // Execute handler
        action.handler()
        XCTAssertTrue(actionExecuted)
    }
    
    func testSeparatorAction() {
        let separator = ContextMenuAction.separator
        XCTAssertTrue(separator.isSeparator)
        XCTAssertEqual(separator.title, "")
        XCTAssertNil(separator.keyEquivalent)
        XCTAssertFalse(separator.isEnabled)
    }
    
    // MARK: - Builder Tests
    
    func testContextMenuBuilder() {
        var builder = ContextMenuBuilder()
        
        builder.addAction(ContextMenuAction(
            title: "Cut",
            keyEquivalent: "x"
        ) {
            // Action handler
        })
        
        builder.addSeparator()
        
        builder.addAction(ContextMenuAction(
            title: "Copy",
            keyEquivalent: "c"
        ) {
            // Action handler
        })
        
        let menu = builder.build()
        
        #if canImport(AppKit)
        let nsMenu = menu
        XCTAssertEqual(nsMenu.items.count, 3)
        XCTAssertEqual(nsMenu.items[0].title, "Cut")
        XCTAssertEqual(nsMenu.items[1].title, "") // Separator
        XCTAssertEqual(nsMenu.items[2].title, "Copy")
        #else
        XCTAssertTrue(menu is UIMenu)
        guard let uiMenu = menu as? UIMenu else {
            XCTFail("Expected UIMenu")
            return
        }
        XCTAssertEqual(uiMenu.children.count, 3)
        #endif
    }
    
    // MARK: - Cross-Platform Menu Tests
    
    func testCreateContextMenuForSelection() {
        let range = NSRange(location: 0, length: 5) // "Hello"
        guard let coordinator, let textView else {
            XCTFail("Test setup failed")
            return
        }
        let menu = coordinator.createContextMenu(for: range, in: textView)
        
        #if canImport(AppKit)
        let nsMenu = menu
        
        // Check standard editing actions that should be available
        let menuTitles = nsMenu.items.map { $0.title }
        if textView.canCut {
            XCTAssertTrue(menuTitles.contains("Cut"))
            let cutItem = nsMenu.items.first { $0.title == "Cut" }
            XCTAssertEqual(cutItem?.keyEquivalent, "x")
        }
        
        if textView.canCopy {
            XCTAssertTrue(menuTitles.contains("Copy"))
        }
        
        if textView.canPaste {
            XCTAssertTrue(menuTitles.contains("Paste"))
        }
        
        // Select All should always be present
        XCTAssertTrue(menuTitles.contains("Select All"))
        #else
        XCTAssertTrue(menu is UIMenu)
        guard let uiMenu = menu as? UIMenu else {
            XCTFail("Expected UIMenu")
            return
        }
        
        // UIMenu children are actions
        XCTAssertTrue(!uiMenu.children.isEmpty)
        #endif
    }
    
    func testCreateContextMenuWithoutSelection() {
        let range = NSRange(location: 0, length: 0) // No selection
        guard let coordinator, let textView else {
            XCTFail("Test setup failed")
            return
        }
        
        // Put something in the pasteboard to test paste functionality
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Test paste content", forType: .string)
        #endif
        
        let menu = coordinator.createContextMenu(for: range, in: textView)
        
        #if canImport(AppKit)
        let nsMenu = menu
        
        // Cut should not be present without selection (canCut returns false)
        let cutItem = nsMenu.items.first { $0.title == "Cut" }
        XCTAssertNil(cutItem, "Cut should not be present without selection")
        
        // Copy should not be present without selection (canCopy returns false)
        let copyItem = nsMenu.items.first { $0.title == "Copy" }
        XCTAssertNil(copyItem, "Copy should not be present without selection")
        
        // Paste should be present if pasteboard has content and text view is editable
        if textView.canPaste {
            let pasteItem = nsMenu.items.first { $0.title == "Paste" }
            XCTAssertNotNil(pasteItem)
            XCTAssertTrue(pasteItem!.isEnabled)
        }
        
        // Select All should always be present
        let selectAllItem = nsMenu.items.first { $0.title == "Select All" }
        XCTAssertNotNil(selectAllItem)
        XCTAssertTrue(selectAllItem!.isEnabled)
        #endif
    }
    
    func testCreateContextMenuForReadOnlyTextView() {
        guard let coordinator, let textView else {
            XCTFail("Test setup failed")
            return
        }
        textView.isEditable = false
        let range = NSRange(location: 0, length: 5)
        
        // Set the selected range in the text view
        #if canImport(AppKit)
        textView.setSelectedRange(range)
        #else
        if let textRange = textView.textRange(from: textView.beginningOfDocument, offset: range.location, length: range.length) {
            textView.selectedTextRange = textRange
        }
        #endif
        
        let menu = coordinator.createContextMenu(for: range, in: textView)
        
        #if canImport(AppKit)
        let nsMenu = menu
        
        // Cut should not be present for read-only text view (canCut returns false)
        let cutItem = nsMenu.items.first { $0.title == "Cut" }
        XCTAssertNil(cutItem, "Cut action should not be present for read-only text view")
        
        // Copy should still be enabled and present
        let copyItem = nsMenu.items.first { $0.title == "Copy" }
        XCTAssertNotNil(copyItem)
        XCTAssertTrue(copyItem!.isEnabled)
        
        // Paste should not be present for read-only text view (canPaste returns false)
        let pasteItem = nsMenu.items.first { $0.title == "Paste" }
        XCTAssertNil(pasteItem, "Paste action should not be present for read-only text view")
        
        // Select All should still be present
        let selectAllItem = nsMenu.items.first { $0.title == "Select All" }
        XCTAssertNotNil(selectAllItem)
        XCTAssertTrue(selectAllItem!.isEnabled)
        #endif
    }
    
    // MARK: - Action Execution Tests
    
    func testContextMenuActionExecution() {
        var actionExecuted = false
        let expectation = self.expectation(description: "Action executed")
        
        let action = ContextMenuAction(
            title: "Test",
            keyEquivalent: nil
        ) {
            actionExecuted = true
            expectation.fulfill()
        }
        
        action.handler()
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(actionExecuted)
    }
    
    // MARK: - Platform-Specific Tests
    
    #if canImport(AppKit)
    func testNSMenuItemCreation() {
        let action = ContextMenuAction(
            title: "Test",
            keyEquivalent: "t"
        ) {}
        
        var builder = ContextMenuBuilder()
        builder.addAction(action)
        
        let menu = builder.build()
        let menuItem = menu.items.first!
        
        XCTAssertEqual(menuItem.title, "Test")
        XCTAssertEqual(menuItem.keyEquivalent, "t")
        XCTAssertNotNil(menuItem.target)
        XCTAssertNotNil(menuItem.action)
    }
    
    func testNSMenuSeparator() {
        var builder = ContextMenuBuilder()
        builder.addSeparator()
        
        let menu = builder.build()
        let menuItem = menu.items.first!
        
        XCTAssertTrue(menuItem.isSeparatorItem)
    }
    #endif
    
    #if canImport(UIKit)
    func testUIMenuCreation() {
        let action = ContextMenuAction(
            title: "Test",
            keyEquivalent: nil
        ) {}
        
        var builder = ContextMenuBuilder()
        builder.addAction(action)
        
        guard let menu = builder.build() as? UIMenu else {
            XCTFail("Expected UIMenu")
            return
        }
        XCTAssertEqual(menu.children.count, 1)
        
        if let uiAction = menu.children.first as? UIAction {
            XCTAssertEqual(uiAction.title, "Test")
        }
    }
    #endif
    
    // MARK: - Performance Tests
    
    func testContextMenuCreationPerformance() {
        let range = NSRange(location: 0, length: 10)
        
        measure {
            for _ in 0..<100 {
                _ = coordinator?.createContextMenu(for: range, in: textView ?? CodeEditorView(frame: .zero))
            }
        }
    }
    
    func testActionBuilderPerformance() {
        measure {
            for _ in 0..<1_000 {
                var builder = ContextMenuBuilder()
                for index in 0..<10 {
                    builder.addAction(ContextMenuAction(
                        title: "Action \(index)",
                        keyEquivalent: nil
                    ) {})
                }
                _ = builder.build()
            }
        }
    }
    
    deinit {
        // Cleanup
    }
}
