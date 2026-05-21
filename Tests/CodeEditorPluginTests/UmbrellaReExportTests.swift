// Single-import surface smoke test for the CodeEditorPlugin umbrella.
//
// `CodeEditorPlugin.swift`'s Quick Start docstring promises that
// `import CodeEditorPlugin` alone is enough to reach `CodeEditor`,
// `CodeEditorView`, `EditorConfiguration`, `Language`, the theme tokens, and
// `CodeEditorError`. Those types live in sibling targets — without
// `@_exported import` of each, the docstring would be lying. This file
// deliberately imports ONLY `CodeEditorPlugin` so the compiler enforces the
// promise: every reference below references a type from a sibling target.
//
// If a future refactor reverts an `@_exported import`, this file stops
// compiling.

import CodeEditorPlugin
import XCTest

final class UmbrellaReExportTests: XCTestCase {
    func testQuickStartTypesAreReachableFromUmbrellaAlone() {
        // CodeEditorConfiguration via @_exported.
        let config = EditorConfiguration()
        XCTAssertNotNil(config)

        // CodeEditorLanguages via @_exported.
        let language: Language = .swift
        XCTAssertEqual(language, .swift)

        // CodeEditorCommon via @_exported.
        let error: CodeEditorError = .invalidConfiguration("smoke")
        XCTAssertNotNil(error.errorDescription)

        // CodeEditorTheming via @_exported — naming a public type from
        // that module proves the symbol resolves through the umbrella.
        _ = SyntaxStyle.self
    }

    @MainActor
    func testEditorViewTypesAreReachableFromUmbrellaAlone() {
        // CodeEditorView via @_exported. Instantiation lives behind
        // @MainActor; just naming the metatype proves the symbol resolves.
        _ = CodeEditorView.self

        // CodeEditorSwiftUI via @_exported — the SwiftUI `CodeEditor` view
        // referenced in the Quick Start docstring.
        _ = CodeEditor.self
    }
}
