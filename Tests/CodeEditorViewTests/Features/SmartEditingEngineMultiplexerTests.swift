import CodeEditorSmartEditing
import CodeEditorTextModel
@testable import CodeEditorView
import XCTest
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
final class SmartEditingEngineMultiplexerTests: XCTestCase {
    /// A host CodeEditorViewDelegate whose shouldChangeTextIn returns
    /// false. Stands in for "read-only region" / "validation rejected"
    /// scenarios.
    @MainActor
    private final class VetoingHostDelegate: NSObject, CodeEditorViewDelegate {
        var shouldChangeCalls = 0

        func textView(
            _: CodeEditorView,
            shouldChangeTextIn _: NSTextRange,
            replacementString _: String?
        ) -> Bool {
            shouldChangeCalls += 1
            return false
        }
    }

    @MainActor
    private final class AllowingHostDelegate: NSObject, CodeEditorViewDelegate {
        var shouldChangeCalls = 0

        func textView(
            _: CodeEditorView,
            shouldChangeTextIn _: NSTextRange,
            replacementString _: String?
        ) -> Bool {
            shouldChangeCalls += 1
            return true
        }
    }

    @MainActor
    private final class WillEditObserver: WillEditEventObserving {
        private(set) var willEditCount = 0

        func textStorageWillApplyEdit(_: WillEditEvent) {
            willEditCount += 1
        }
    }

    // MARK: - Tests

    func testHostVetoBlocksAutoIndent() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let hostDelegate = VetoingHostDelegate()
        codeEditorView.textDelegate = hostDelegate

        let observer = WillEditObserver()
        codeEditorView.textEditEventHub.addWillEditObserver(observer)

        let engine = SmartEditingEngine()
        engine.configuration.isAutoIndentEnabled = true
        engine.attach(to: codeEditorView)

        // Drive the multiplexer's shouldChangeTextIn directly with a
        // newline keystroke (which would normally trigger auto-indent).
        let range = NSRange(location: 0, length: 0)
        let allowed = invokeShouldChange(
            codeEditorView: codeEditorView,
            range: range,
            replacement: "\n"
        )

        XCTAssertFalse(allowed, "Host veto must block the edit")
        XCTAssertEqual(hostDelegate.shouldChangeCalls, 1, "Host gating must be consulted")
        XCTAssertEqual(observer.willEditCount, 0, "WillEditEvent must not fire on a vetoed edit")
        // The auto-indent side-effect would have written to textStorage
        // via textKitBridge.replaceCharacters; verify nothing changed.
        XCTAssertEqual(codeEditorView.textKitBridge.documentLength, 0, "textStorage must be unchanged after veto")
    }

    func testAutoBracketStillWorksWhenHostAllows() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let hostDelegate = AllowingHostDelegate()
        codeEditorView.textDelegate = hostDelegate

        let observer = WillEditObserver()
        codeEditorView.textEditEventHub.addWillEditObserver(observer)

        let engine = SmartEditingEngine()
        engine.attach(to: codeEditorView)

        let range = NSRange(location: 0, length: 0)
        let allowed = invokeShouldChange(
            codeEditorView: codeEditorView,
            range: range,
            replacement: "("
        )

        // Auto-bracket intercepts the keystroke: engine writes "()" via
        // textKitBridge.replaceCharacters and returns false to tell
        // AppKit/UIKit not to perform the default "(" insert.
        XCTAssertFalse(allowed, "Auto-bracket interception must return false")
        XCTAssertEqual(codeEditorView.textKitBridge.documentString, "()", "Auto-bracket must have written the pair")
        // The bridge write bypasses the delegate path entirely, so no
        // WillEditEvent fires from the auto-bracket interception. This is
        // a known limitation that the spec calls out — fixing it would
        // require routing bridge writes back through the multiplexer's
        // intrinsic step. Out of scope for this regression test; just
        // pinning current semantics here.
        XCTAssertEqual(observer.willEditCount, 0, "Auto-bracket path bypasses WillEditEvent today")
    }

    func testNoReplacingDelegateWarningLog() throws {
        // The "Replacing existing text view delegate" warning is gone
        // entirely from SmartEditingEngine after the migration. This
        // test is structural: it asserts the engine's source no longer
        // references that string.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // strip filename
            .deletingLastPathComponent() // Features
            .deletingLastPathComponent() // CodeEditorKitTests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/CodeEditorSmartEditing/SmartEditingEngine.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(
            source.contains("Replacing existing text view delegate"),
            "The warning log line should be deleted; its presence signals the SmartEditingEngine.attach delegate-stomping bug has regressed."
        )
    }

    // MARK: - Test helper

    private func invokeShouldChange(
        codeEditorView: CodeEditorView,
        range: NSRange,
        replacement: String
    ) -> Bool {
        #if canImport(AppKit)
        return codeEditorView.delegateMultiplexer.textView(
            codeEditorView,
            shouldChangeTextIn: range,
            replacementString: replacement
        )
        #else
        return codeEditorView.delegateMultiplexer.textView(
            codeEditorView,
            shouldChangeTextIn: range,
            replacementText: replacement
        )
        #endif
    }
}
