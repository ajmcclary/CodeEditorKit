#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import CodeEditorCommon
import CodeEditorConfiguration
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import Observation
import SwiftUI
import XCTest

/// Hosts the real `CodeEditor` in an `NSHostingView` the way an app does and
/// types into it with `insertText`, so AppKit's own notification order (the
/// selection notification arrives before the text notification) and SwiftUI's
/// `updateNSView` calls take part. Unit tests that hand-set `currentText`
/// cannot see the bugs these cover.
@MainActor
final class HostedCodeEditorTypingTests: XCTestCase {
    private var window: NSWindow?

    override func setUp() {
        super.setUp()
        window = nil
    }

    override func tearDown() {
        window?.orderOut(nil)
        window?.close()
        window = nil
        super.tearDown()
    }

    // MARK: - Interaction-state binding (caret and selection)

    func testTypingIntoAnEmptyDocumentKeepsCharactersInOrder() throws {
        let store = HostedEditorStore("")
        let textView = try host(store, mode: .appLike)

        type("hello", into: textView)

        XCTAssertEqual(textView.string, "hello")
        XCTAssertEqual(store.text, "hello")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 5, length: 0))
        XCTAssertEqual(
            store.interaction.state.cursorPositions,
            [EditorCursorPosition(line: 1, column: 6)]
        )
    }

    func testTypingAtTheEndOfALineStaysOnThatLine() throws {
        let store = HostedEditorStore("foo\nbar")
        let textView = try host(store, mode: .appLike)
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        spin(for: 0.05)

        type("abc", into: textView)

        XCTAssertEqual(textView.string, "fooabc\nbar")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 6, length: 0))
    }

    func testAnUnrelatedRerenderKeepsTheSelection() throws {
        let store = HostedEditorStore("hello world\nsecond line")
        let textView = try host(store, mode: .appLike)
        textView.setSelectedRange(NSRange(location: 0, length: 5))
        spin(for: 0.05)

        store.tick += 1
        spin(for: 0.2)

        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 5))
    }

    func testCaretInACRLFDocumentSurvivesARerender() throws {
        let store = HostedEditorStore("one\r\ntwo\r\nthree")
        let textView = try host(store, mode: .appLike)
        textView.setSelectedRange(NSRange(location: 6, length: 0))
        spin(for: 0.05)

        store.tick += 1
        spin(for: 0.2)

        XCTAssertEqual(textView.selectedRange(), NSRange(location: 6, length: 0))
        XCTAssertEqual(
            store.interaction.state.cursorPositions,
            [EditorCursorPosition(line: 2, column: 2)]
        )
    }

    func testAHostWrittenCursorStillMovesTheCaret() throws {
        let store = HostedEditorStore("one\ntwo\nthree")
        let textView = try host(store, mode: .appLike)
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        spin(for: 0.05)

        store.interaction.state.cursorPositions = [EditorCursorPosition(line: 3, column: 3)]
        store.tick += 1
        spin(for: 0.2)

        XCTAssertEqual(textView.selectedRange(), NSRange(location: 10, length: 0))
    }

    // MARK: - Replace through the normal change path

    func testReplaceAllReachesTheHostAndIsOneUndoStep() throws {
        let store = HostedEditorStore("foo one\nfoo two\nfoo three\n")
        let textView = try host(store, mode: .controller)

        let count = run { await store.controller.replaceAll("foo", with: "barbaz") }
        spin(for: 0.3)

        XCTAssertEqual(count, 3)
        XCTAssertEqual(textView.string, "barbaz one\nbarbaz two\nbarbaz three\n")
        XCTAssertEqual(store.text, textView.string)
        let undoManager = try XCTUnwrap(textView.undoManager)
        XCTAssertTrue(undoManager.canUndo)

        // An unrelated state change must not put the old text back.
        store.lineNumbers.toggle()
        spin(for: 0.3)
        XCTAssertEqual(textView.string, "barbaz one\nbarbaz two\nbarbaz three\n")

        undoManager.undo()
        spin(for: 0.3)
        XCTAssertEqual(textView.string, "foo one\nfoo two\nfoo three\n")
        XCTAssertEqual(store.text, textView.string)
    }

    func testReplaceCurrentReachesTheHostAndCanBeUndone() throws {
        let store = HostedEditorStore("foo one\nfoo two\n")
        let textView = try host(store, mode: .controller)

        _ = run { await store.controller.find("foo").count }
        XCTAssertTrue(store.controller.replaceCurrent(with: "Q"))
        spin(for: 0.3)

        XCTAssertEqual(textView.string, "Q one\nfoo two\n")
        XCTAssertEqual(store.text, textView.string)
        let undoManager = try XCTUnwrap(textView.undoManager)
        XCTAssertTrue(undoManager.canUndo)
        undoManager.undo()
        spin(for: 0.3)
        XCTAssertEqual(textView.string, "foo one\nfoo two\n")
    }

    func testUndoingTypingReachesTheHost() throws {
        let store = HostedEditorStore("abc")
        let textView = try host(store, mode: .controller)
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        type("XYZ", into: textView)
        XCTAssertEqual(store.text, "abcXYZ")

        try XCTUnwrap(textView.undoManager).undo()
        spin(for: 0.3)

        XCTAssertEqual(textView.string, "abc")
        XCTAssertEqual(store.text, "abc")
    }

    // MARK: - Host text that is behind the editor

    func testAConfigurationChangeInsideTheDebounceKeepsTheTypedText() throws {
        let store = HostedEditorStore("abc")
        let textView = try host(store, mode: .bindingOnly)
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        spin(for: 0.05)

        textView.insertText("X", replacementRange: NSRange(location: NSNotFound, length: 0))
        spin(for: 0.01)
        store.lineNumbers.toggle()
        spin(for: 0.5)

        XCTAssertEqual(textView.string, "abcX")
        XCTAssertEqual(store.text, "abcX")
    }

    func testRemovingTheEditorInsideTheDebounceDeliversTheLastKeystroke() throws {
        let store = HostedEditorStore("abc")
        let textView = try host(store, mode: .bindingOnly)
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        spin(for: 0.05)

        textView.insertText("X", replacementRange: NSRange(location: NSNotFound, length: 0))
        spin(for: 0.01)
        store.showsEditor = false
        spin(for: 0.3)

        XCTAssertEqual(store.text, "abcX")
    }

    // MARK: - Host text equal to an earlier editor value

    /// Host text equal to something the editor wrote earlier is a real
    /// replacement once the host has shown other text since: undoing a
    /// canvas edit, or a Reload back to the same disk contents.
    private func assertHostCanReturnToAnEarlierEditorValue(mode: HostedEditorMode) throws {
        let store = HostedEditorStore("abc")
        let textView = try host(store, mode: mode)
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        spin(for: 0.05)
        type("X", into: textView)
        spin(for: 0.3)
        XCTAssertEqual(store.text, "abcX")

        store.text = "Q"
        spin(for: 0.3)
        XCTAssertEqual(textView.string, "Q")

        store.text = "abcX"
        spin(for: 0.3)
        XCTAssertEqual(textView.string, "abcX", "the host's text was ignored")

        textView.setSelectedRange(NSRange(location: 4, length: 0))
        type("Z", into: textView)
        spin(for: 0.3)
        XCTAssertEqual(store.text, "abcXZ")
    }

    func testHostCanReturnToAnEarlierEditorValueWithOnTextChange() throws {
        try assertHostCanReturnToAnEarlierEditorValue(mode: .controller)
    }

    func testHostCanReturnToAnEarlierEditorValueWithABindingOnly() throws {
        try assertHostCanReturnToAnEarlierEditorValue(mode: .bindingOnly)
    }

    func testHostCanReturnToAnEarlierEditorValueWithAnIgnoredSetter() throws {
        try assertHostCanReturnToAnEarlierEditorValue(mode: .setterIgnored)
    }

    /// The binding write lands, the user types again before SwiftUI's update,
    /// then the update carries the written (now older) value: an echo, not a
    /// replacement.
    func testAnEchoOfTheEditorsOwnWriteDoesNotRevertNewerTyping() throws {
        let store = HostedEditorStore("abc")
        let textView = try host(store, mode: .bindingOnly)
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        spin(for: 0.05)
        textView.insertText("X", replacementRange: NSRange(location: NSNotFound, length: 0))
        spin(for: 0.2) // the debounced write delivers "abcX"
        XCTAssertEqual(store.text, "abcX")

        // Type before SwiftUI has rendered the written value.
        textView.insertText("Y", replacementRange: NSRange(location: NSNotFound, length: 0))
        store.tick += 1
        spin(for: 0.5)

        XCTAssertEqual(textView.string, "abcXY")
        XCTAssertEqual(store.text, "abcXY")
    }

    // MARK: - Host text replacement

    func testUndoAfterTheHostReplacesTheTextIsSafe() throws {
        let store = HostedEditorStore("line one\nline two\nline three\n")
        let textView = try host(store, mode: .controller)
        textView.setSelectedRange(NSRange(location: 27, length: 0))
        type("XYZ", into: textView)
        XCTAssertTrue(textView.undoManager?.canUndo ?? false)

        store.text = "Q"
        spin(for: 0.3)

        XCTAssertEqual(textView.string, "Q")
        XCTAssertFalse(textView.undoManager?.canUndo ?? false)
        textView.undoManager?.undo()
        spin(for: 0.1)
        XCTAssertEqual(textView.string, "Q")
        XCTAssertEqual(store.text, "Q")
    }

    func testAHostReplacementKeepsAValidCaret() throws {
        let store = HostedEditorStore("one\ntwo\nthree")
        let textView = try host(store, mode: .controller)
        textView.setSelectedRange(NSRange(location: 5, length: 0))
        spin(for: 0.05)

        store.text = "one\ntwo\nthree and more"
        spin(for: 0.3)

        XCTAssertEqual(textView.selectedRange(), NSRange(location: 5, length: 0))
    }

    // MARK: - Hosting

    func run<T>(_ operation: @escaping @MainActor () async -> T) -> T? {
        var result: T?
        Task { @MainActor in result = await operation() }
        let deadline = Date().addingTimeInterval(10)
        while result == nil, Date() < deadline {
            spin(for: 0.02)
        }
        return result
    }

    @discardableResult
    func host(_ store: HostedEditorStore, mode: HostedEditorMode) throws -> CodeEditorView {
        let hosting = NSHostingView(rootView: HostedEditor(store: store, mode: mode))
        hosting.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        self.window = window
        hosting.layoutSubtreeIfNeeded()
        let deadline = Date().addingTimeInterval(3)
        while Self.findContainer(in: hosting) == nil, Date() < deadline {
            spin(for: 0.02)
        }
        let container = try XCTUnwrap(Self.findContainer(in: hosting))
        spin(for: 0.2)
        window.makeFirstResponder(container.textView)
        return container.textView
    }

    func type(_ text: String, into textView: CodeEditorView) {
        for character in text {
            textView.insertText(
                String(character),
                replacementRange: NSRange(location: NSNotFound, length: 0)
            )
            spin(for: 0.03)
        }
        spin(for: 0.2)
    }

    func spin(for seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private static func findContainer(in view: NSView) -> CodeEditorContainerView? {
        if let container = view as? CodeEditorContainerView { return container }
        for subview in view.subviews {
            if let container = findContainer(in: subview) { return container }
        }
        return nil
    }
}

/// Interaction state kept in storage SwiftUI does not observe, as Ready Room
/// keeps it.
@MainActor
final class HostedInteractionBox {
    var state = EditorInteractionState()
}

@MainActor
@Observable
final class HostedEditorStore {
    var text: String
    var tick = 0
    var lineNumbers = true
    var showsEditor = true
    @ObservationIgnored let interaction = HostedInteractionBox()
    @ObservationIgnored let controller = EditorController()

    init(_ text: String) {
        self.text = text
    }
}

enum HostedEditorMode {
    /// Text binding + `.onTextChange` into an observed store + an
    /// interaction-state binding into unobserved storage (Ready Room's shape).
    case appLike
    /// Text binding only.
    case bindingOnly
    /// Text binding + `.onTextChange` + an `EditorController`.
    case controller
    /// A binding whose setter is ignored, with `.onTextChange` updating the
    /// store (Ready Room's Diagram Source panel).
    case setterIgnored
}

struct HostedEditor: View {
    let store: HostedEditorStore
    let mode: HostedEditorMode

    var body: some View {
        _ = store.tick
        var configuration = EditorConfiguration.default
        configuration.display.isLineNumbersEnabled = store.lineNumbers
        let editor = CodeEditor(text: Binding(
            get: { store.text },
            set: { if mode != .setterIgnored { store.text = $0 } }
        ))
        return Group {
            if store.showsEditor {
                content(editor)
            }
        }
        .environment(\.codeEditorConfiguration, configuration)
    }

    @ViewBuilder
    private func content(_ editor: CodeEditor) -> some View {
        Group {
            switch mode {
            case .appLike:
                editor
                    .editorInteractionState(Binding(
                        get: { store.interaction.state },
                        set: { store.interaction.state = $0 }
                    ))
                    .onTextChange { store.text = $0 }

            case .bindingOnly:
                editor

            case .controller:
                editor
                    .onTextChange { store.text = $0 }
                    .editorController(store.controller)

            case .setterIgnored:
                editor
                    .onTextChange { store.text = $0 }
            }
        }
    }
}
#endif
