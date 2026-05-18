//
//  IntentCoordinatorWiringTests.swift
//  CodeEditorPluginTests
//
//  Functional tests for CodeEditor.makeRepresentableCallbacks(from:textBinding:).
//  Spec: docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md.
//

@testable import CodeEditorPlugin
@testable import CodeEditorView
import SwiftUI
import XCTest

/// Reference-type capture so @Sendable closures can record observations
/// across the storage boundary without tripping strict concurrency.
private final class CallbackProbe<Value>: @unchecked Sendable {
    var value: Value?
    var didFire = false
}

@available(macOS 13.0, iOS 16.0, *)
final class IntentCoordinatorWiringTests: XCTestCase {
    @MainActor
    func testNilIntentProducesNilCallbacks() {
        let binding = Binding<String>.constant("abc")
        let (textCallback, selectionCallback) = CodeEditor.makeRepresentableCallbacks(
            from: CodeEditorIntent(),
            textBinding: binding
        )
        XCTAssertNil(textCallback)
        XCTAssertNil(selectionCallback)
    }

    @MainActor
    func testOnTextChangeForwardsThroughWrapper() {
        let probe = CallbackProbe<String>()
        var intent = CodeEditorIntent()
        intent.onTextChange = { probe.value = $0 }

        let binding = Binding<String>.constant("abc")
        let (textCallback, _) = CodeEditor.makeRepresentableCallbacks(
            from: intent,
            textBinding: binding
        )

        XCTAssertNotNil(textCallback)
        textCallback?("hello")
        XCTAssertEqual(probe.value, "hello")
    }

    @MainActor
    func testOnSelectionChangeConvertsNSRangeToStringIndexRange() {
        let probe = CallbackProbe<Range<String.Index>>()
        var intent = CodeEditorIntent()
        intent.onSelectionChange = { probe.value = $0 }

        let binding = Binding<String>.constant("hello world")
        let (_, selectionCallback) = CodeEditor.makeRepresentableCallbacks(
            from: intent,
            textBinding: binding
        )

        XCTAssertNotNil(selectionCallback)
        // "hello" — UTF-16 location 0, length 5
        selectionCallback?(NSRange(location: 0, length: 5))

        let expectedStart = binding.wrappedValue.startIndex
        let expectedEnd = binding.wrappedValue.index(expectedStart, offsetBy: 5)
        XCTAssertEqual(probe.value, expectedStart..<expectedEnd)
    }

    @MainActor
    func testOnSelectionChangeSilentlyDropsInvalidRanges() {
        let probe = CallbackProbe<Range<String.Index>>()
        var intent = CodeEditorIntent()
        intent.onSelectionChange = { _ in probe.didFire = true }

        let binding = Binding<String>.constant("abc")
        let (_, selectionCallback) = CodeEditor.makeRepresentableCallbacks(
            from: intent,
            textBinding: binding
        )

        // Past-end range — Range(_:in:) returns nil; today's
        // handleSelectionChange returns silently; preserve that.
        selectionCallback?(NSRange(location: 100, length: 5))
        XCTAssertFalse(probe.didFire)
    }
}
