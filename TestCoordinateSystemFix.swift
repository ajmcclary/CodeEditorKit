#!/usr/bin/env swift

// Test to verify that the coordinate system fix is working properly
// This file tests that all NSView subclasses have isFlipped implemented

import Foundation
import AppKit
import CodeEditorPlugin

// Test helper to check if a view is flipped
func testViewIsFlipped<T: NSView>(_ viewType: T.Type, _ viewName: String) {
    let view = viewType.init(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
    let isFlipped = view.isFlipped
    print("\(viewName): isFlipped = \(isFlipped) \(isFlipped ? "✅" : "❌")")
}

print("Testing coordinate system for STTextView-related views on macOS...")
print("==========================================================")

// Test all the views that should have flipped coordinate systems
testViewIsFlipped(STContentView.self, "STContentView")
testViewIsFlipped(STTextLayoutFragmentView.self, "STTextLayoutFragmentView")
testViewIsFlipped(STLineHighlightView.self, "STLineHighlightView")
testViewIsFlipped(STGutterView.self, "STGutterView")
testViewIsFlipped(STInsertionPointView.self, "STInsertionPointView")
testViewIsFlipped(STAnnotationsContentView.self, "STAnnotationsContentView")

print("\nTesting STTextView integration...")
let textView = STTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
textView.text = "Testing coordinate system\nLine 2\nLine 3"

// Check if the content view is properly flipped
if let contentView = textView.textContentView {
    print("STTextView.textContentView: isFlipped = \(contentView.isFlipped) \(contentView.isFlipped ? "✅" : "❌")")
}

print("\nAll text-related views should have isFlipped = true for proper text rendering.")