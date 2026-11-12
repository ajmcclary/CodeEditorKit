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

    // MARK: - Hosting

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
            set: { store.text = $0 }
        ))
        return Group {
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
            }
        }
        .environment(\.codeEditorConfiguration, configuration)
    }
}
#endif
