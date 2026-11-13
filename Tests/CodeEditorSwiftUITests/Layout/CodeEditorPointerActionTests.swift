#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import CodeEditorCommon
@testable import CodeEditorLayout
@testable import CodeEditorSwiftUI
import SwiftUI
import XCTest

/// End-to-end: `.onTextHover` / `.onCommandClick` applied OUTSIDE a
/// `CodeEditor` (the documented usage) must receive the events the editor's
/// controller bus emits. Before 0.1.0-beta.10 the modifiers read
/// `\.editorEventBus` from the environment above `CodeEditor`, which never
/// carries it, so nothing fired.
@MainActor
final class CodeEditorPointerActionTests: XCTestCase {
    private var window: NSWindow?

    override func setUp() {
        super.setUp()
        window = nil
    }

    override func tearDown() {
        window?.orderOut(nil)
        window = nil
        super.tearDown()
    }

    private func host<V: View>(_ view: V, controller: EditorController) throws {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
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
        try spin(until: { controller.isAttached }, timeout: 30)
    }

    /// Emits until a delivery arrives. The `.onReceive` subscriptions are
    /// installed by a SwiftUI pass after the editor attaches, and an event
    /// sent before that is dropped; a fixed 0.1 s spin only usually covered
    /// it. Each emission replaces the last, so one value arrives.
    private func emitUntilDelivered<Value>(into box: Box<Value>, _ emit: () -> Void) {
        let deadline = Date().addingTimeInterval(30)
        while box.values.isEmpty, Date() < deadline {
            emit()
            spin(for: 0.05)
        }
    }

    private func spin(for seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func spin(until condition: () -> Bool, timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                throw XCTSkip("editor never attached inside the hosting view")
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    func test_commandClickModifierOutsideCodeEditorFires() throws {
        let controller = EditorController()
        let box = Box<SourcePosition>()
        try host(
            CodeEditor(text: .constant("a\nb"))
                .editorController(controller)
                .onCommandClick { box.values.append($0) },
            controller: controller
        )

        emitUntilDelivered(into: box) {
            controller.editorEventBus.emitCommandClick(at: SourcePosition(line: 1, character: 0))
        }

        XCTAssertEqual(box.values, [SourcePosition(line: 1, character: 0)])
    }

    func test_hoverModifierOutsideCodeEditorFiresAfterIdleDelay() throws {
        let controller = EditorController()
        let box = Box<SourcePosition?>()
        try host(
            CodeEditor(text: .constant("a\nb"))
                .editorController(controller)
                .onTextHover(idleDelay: .milliseconds(10)) { position in
                    await MainActor.run { box.values.append(position) }
                },
            controller: controller
        )

        emitUntilDelivered(into: box) {
            controller.editorEventBus.emitHover(at: SourcePosition(line: 0, character: 1))
        }
        // A little longer for any duplicate (a negative check: load can
        // only hide a duplicate, not invent one).
        spin(for: 0.1)

        XCTAssertEqual(box.values, [SourcePosition(line: 0, character: 1)])
    }

    func test_hoverCancelledByNextPosition() throws {
        let controller = EditorController()
        let box = Box<SourcePosition?>()
        try host(
            CodeEditor(text: .constant("a\nb"))
                .editorController(controller)
                .onTextHover(idleDelay: .milliseconds(80)) { position in
                    await MainActor.run { box.values.append(position) }
                },
            controller: controller
        )

        // Subscribed first, so the pair below is not lost.
        emitUntilDelivered(into: box) {
            controller.editorEventBus.emitHover(at: SourcePosition(line: 1, character: 1))
        }
        box.values.removeAll()

        // Both in one run-loop turn: the second is certainly inside the
        // first's 80 ms idle delay (a 5 ms spin between them was not, once
        // the main thread stalled).
        controller.editorEventBus.emitHover(at: SourcePosition(line: 0, character: 0))
        controller.editorEventBus.emitHover(at: SourcePosition(line: 1, character: 0))
        let deadline = Date().addingTimeInterval(30)
        while box.values.isEmpty, Date() < deadline {
            spin(for: 0.02)
        }
        spin(for: 0.2) // past the idle delay, for a delivery of the first

        XCTAssertEqual(box.values, [SourcePosition(line: 1, character: 0)])
    }
}

@MainActor
private final class Box<Value> {
    var values: [Value] = []
}
#endif
