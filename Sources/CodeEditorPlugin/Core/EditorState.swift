import Foundation
import Observation

/// Live state of the editor and its surrounding chrome.
///
/// Chrome views (`EditorStatusBar`, `EditorBreadcrumbView`, `EditorTitleBar`)
/// observe this object via `\.editorState` in the SwiftUI environment and
/// re-render when fields they read mutate. The editor target writes
/// `selection`, `language`, `isDirty`, `hardwareAccelerationActive`, and
/// `lineCount`; the host writes the rest (`documentName`, `documentURL`,
/// `tabs`, `activeTabID`, `breadcrumbPath`, `workspaceName`).
///
/// MainActor-isolated. `@Observable` does not synthesize `Sendable`, so
/// access is gated by the actor instead of a hand-written `@unchecked
/// Sendable` conformance.
@MainActor
@Observable
public final class EditorState {
    // MARK: Editor-written

    /// Caret/selection in the active document; nil before the editor mounts.
    public var selection: SelectionState?
    /// Detected/explicit language for the active document.
    public var language: Language?
    /// True when the active document has unsaved changes.
    public var isDirty: Bool
    /// Reflects the editor's *actual* hardware-acceleration state — what's
    /// running, not what's configured. Status bar reads this so the UI
    /// shows truth.
    public var hardwareAccelerationActive: Bool
    /// Total line count of the active document.
    public var lineCount: Int

    // MARK: Host-written

    /// Display name for the active document (e.g., `"EditorState.swift"`).
    public var documentName: String
    /// File URL for the active document, if any.
    public var documentURL: URL?
    /// Open tabs. Host owns ordering and lifecycle.
    public var tabs: [TabModel]
    /// Active tab in `tabs`; nil when no document is open.
    public var activeTabID: TabModel.ID?
    /// Breadcrumb trail. Host computes from `documentURL` + workspace root +
    /// symbol path.
    public var breadcrumbPath: [BreadcrumbComponent]
    /// Workspace name for the title bar / sidebar header.
    public var workspaceName: String

    /// Creates a fresh empty `EditorState`. All fields default to empty/nil.
    public init() {
        self.selection = nil
        self.language = nil
        self.isDirty = false
        self.hardwareAccelerationActive = false
        self.lineCount = 0
        self.documentName = ""
        self.documentURL = nil
        self.tabs = []
        self.activeTabID = nil
        self.breadcrumbPath = []
        self.workspaceName = ""
    }
}
