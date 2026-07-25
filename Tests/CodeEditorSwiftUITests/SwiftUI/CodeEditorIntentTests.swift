//
//  CodeEditorIntentTests.swift
//  CodeEditorKitTests
//
//  Env-propagation unit tests for CodeEditorIntent. See
//  docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md.
//

import CodeEditorCommon
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import SwiftUI
import XCTest

@available(macOS 13.0, iOS 16.0, *)
final class CodeEditorIntentTests: XCTestCase {
    @MainActor
    func testDefaultIntentHasAllFieldsNil() {
        let intent = CodeEditorIntent()
        XCTAssertNil(intent.onTextChange)
        XCTAssertNil(intent.onSelectionChange)
        XCTAssertNil(intent.completionProvider)
        XCTAssertNil(intent.editorController)
        XCTAssertNil(intent.interactionState)
    }

    @MainActor
    func testIntentFieldsRoundtrip() {
        var intent = CodeEditorIntent()
        intent.onTextChange = { _ in }
        intent.onSelectionChange = { _ in }
        intent.completionProvider = { _ in [] }
        intent.interactionState = .constant(EditorInteractionState())
        XCTAssertNotNil(intent.onTextChange)
        XCTAssertNotNil(intent.onSelectionChange)
        XCTAssertNotNil(intent.completionProvider)
        XCTAssertNotNil(intent.interactionState)
    }

    @MainActor
    func testDefaultEnvironmentValueIsEmptyIntent() {
        let env = EnvironmentValues()
        XCTAssertNil(env.codeEditorIntent.onTextChange)
        XCTAssertNil(env.codeEditorIntent.onSelectionChange)
        XCTAssertNil(env.codeEditorIntent.completionProvider)
        XCTAssertNil(env.codeEditorIntent.editorController)
        XCTAssertNil(env.codeEditorIntent.interactionState)
    }
}
