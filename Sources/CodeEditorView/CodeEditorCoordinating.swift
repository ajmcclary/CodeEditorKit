import Foundation

/// Protocol for the SwiftUI-side coordinator class that owns a
/// `CodeEditorView`. Stored as a weak back-pointer on `CodeEditorView`
/// so the editor surface target can hold a reference without depending
/// on the SwiftUI/ slice (which would invert the build-graph dep
/// direction: `CodeEditorView` is phase 8, the umbrella SwiftUI slice
/// is phase 9). The concrete `CodeEditorBaseCoordinator` in the
/// umbrella's SwiftUI/ slice conforms.
@MainActor
package protocol CodeEditorCoordinating: AnyObject {
    /// Reset the dirty baseline to the view's current content. Called
    /// by `EditorController.markClean()` via
    /// `CodeEditorView.applyMarkClean()`.
    func markClean(view: CodeEditorView)
}
