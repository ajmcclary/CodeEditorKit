#if canImport(AppKit)
import AppKit
@testable import CodeEditorView
import XCTest

/// The editor watches undo notifications to announce TextKit 2 undos. It
/// must watch only its own undo manager: an undo on another manager, on
/// another thread, must not reach (and trap in) its main-actor handler.
final class UndoObservationTests: XCTestCase {
    private final class Target: @unchecked Sendable {
        var value = 0
    }

    @MainActor
    func testAnUndoOffTheMainThreadElsewhereDoesNotReachTheEditor() async {
        let editor = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        editor.string = "abc"

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().async {
                let manager = UndoManager()
                manager.groupsByEvent = false
                let target = Target()
                manager.beginUndoGrouping()
                manager.registerUndo(withTarget: target) { $0.value = 1 }
                manager.endUndoGrouping()
                manager.undo()
                manager.beginUndoGrouping()
                manager.registerUndo(withTarget: target) { $0.value = 2 }
                manager.endUndoGrouping()
                manager.undo()
                manager.redo()
                continuation.resume()
            }
        }

        XCTAssertEqual(editor.string, "abc")
    }
}
#endif
