import CodeEditorCompletion
import CodeEditorLanguages
import CodeEditorPlatform
#if canImport(AppKit) || canImport(UIKit)
import Foundation
import XCTest

@testable import CodeEditorPlugin

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Asserts that `CodeEditorView.completionViewController(_:complete:movement:)`
/// auto-records the selection into the attached `CompletionManager`.
///
/// Spec: docs/superpowers/specs/2026-05-14-completion-ranking-unification-design.md.
@available(macOS 13.0, iOS 16.0, *)
@MainActor
final class CompletionViewWiringTests: XCTestCase {
    struct StubProvider: CompletionProvider {
        let id = "wiring.stub"
        let supportedLanguages: [Language] = []
        let triggerCharacters: [String] = []
        let supportsSnippets = false
        let labels: [String]

        @MainActor
        func completions(for context: CompletionContextModel) async throws -> CompletionResult {
            let items = labels.map { label in
                CompletionItemModel(label: label, insertText: label, kind: .text)
            }
            return CompletionResult(items: items, context: context)
        }
    }

    /// Stand-in `CompletionViewControllerRepresentable` passed as the first
    /// argument to the delegate method. Never displayed; only needs to
    /// satisfy the protocol so the delegate-method call typechecks.
    ///
    /// `CompletionViewControllerRepresentable` refines `PlatformViewController`
    /// (`NSViewController` on macOS, `UIViewController` on iOS) and exposes
    /// `items` (mutable) + `delegate` (weak).
    final class DummyController: PlatformViewController, CompletionViewControllerRepresentable {
        var items: [any CompletionItemView] = []
        weak var delegate: CompletionViewControllerDelegate?
    }

    func testAcceptingItemRecordsSelectionOnManager() async throws {
        let view = CodeEditorView(frame: .zero)
        let manager = view.completionManager
        manager.registerProvider(StubProvider(labels: ["alpha", "beta"]))

        let ctx = CompletionContextModel(text: "", cursorPosition: 0, language: .swift)

        // First request seeds lastContext and proves the baseline order.
        let first = try await manager.requestCompletions(for: ctx)
        XCTAssertEqual(first.items.map(\.label), ["alpha", "beta"])

        // Drive the delegate twice with "beta" — same call path the
        // completion popup uses when the user presses return.
        let item = CompletionItemModel(label: "beta", insertText: "beta", kind: .text)
        let adapter = CompletionItemAdapter(item)
        let stub = DummyController()
        view.completionViewController(stub, complete: adapter, movement: .return)
        view.completionViewController(stub, complete: adapter, movement: .return)

        // Re-request with the cache cleared (otherwise the second call hits
        // the cache hit for the unchanged context and skips ranking entirely).
        // Production hosts hit fresh ranking either when the cache expires or
        // when the context changes (cursor moves, etc.); clearing here keeps
        // the assertion focused on the wiring under test.
        manager.clearCache()

        let second = try await manager.requestCompletions(for: ctx)
        XCTAssertEqual(second.items.map(\.label), ["beta", "alpha"])
    }
}
#endif
