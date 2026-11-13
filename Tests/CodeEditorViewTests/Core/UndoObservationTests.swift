#if canImport(AppKit)
import AppKit
@testable import CodeEditorView
import XCTest

/// The editor watches undo notifications to announce TextKit 2 undos. It
/// must watch only its own undo manager, and a notification delivered off
/// the main thread must not enter (and trap in) its main-actor state.
///
/// The notifications are posted directly from a background queue: that is
/// exactly what an `UndoManager` driven off the main thread does, without
/// running an undo handler (which the SDK marks main-actor) off-main here.
final class UndoObservationTests: XCTestCase {
    private final class Box: @unchecked Sendable {
        let object: AnyObject

        init(_ object: AnyObject) {
            self.object = object
        }
    }

    @MainActor
    func testUndoNotificationsPostedOffTheMainThreadDoNotReachTheEditor() async {
        let editor = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        editor.string = "abc"
        let own = Box(editor.editorUndoManager)
        let foreign = Box(NSObject())

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().async {
                for name in [Notification.Name.NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange] {
                    NotificationCenter.default.post(name: name, object: foreign.object)
                    NotificationCenter.default.post(name: name, object: own.object)
                }
                continuation.resume()
            }
        }

        XCTAssertEqual(editor.string, "abc")
    }
}
#endif
