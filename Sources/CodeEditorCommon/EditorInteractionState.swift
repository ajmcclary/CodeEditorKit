import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// swiftlint:disable discouraged_optional_boolean discouraged_optional_collection
// All fields are optional by design to support partial state restoration.

/// Serializable interaction state for persisting and restoring cursor position,
/// scroll offset, find panel state, and collapsed folds.
///
/// Every field is optional to support partial state restoration.
/// Hosts can persist this independently from editor chrome state.
public struct EditorInteractionState: Equatable, Hashable, Sendable, Codable {
    /// Saved cursor positions (line/column pairs).
    public var cursorPositions: [EditorCursorPosition]?

    /// Saved scroll offset in the text view's content coordinate space.
    public var scrollPosition: CGPoint?

    /// Current find/search query text.
    public var findText: String?

    /// Current replace text.
    public var replaceText: String?

    /// Whether the find panel is visible.
    public var findPanelVisible: Bool?

    /// IDs of currently collapsed fold regions.
    public var collapsedFoldIDs: Set<String>?

    public init(
        cursorPositions: [EditorCursorPosition]? = nil,
        scrollPosition: CGPoint? = nil,
        findText: String? = nil,
        replaceText: String? = nil,
        findPanelVisible: Bool? = nil,
        collapsedFoldIDs: Set<String>? = nil
    ) {
        self.cursorPositions = cursorPositions
        self.scrollPosition = scrollPosition
        self.findText = findText
        self.replaceText = replaceText
        self.findPanelVisible = findPanelVisible
        self.collapsedFoldIDs = collapsedFoldIDs
    }
}

/// A 1-based line and column position.
public struct EditorCursorPosition: Equatable, Hashable, Sendable, Codable {
    public var line: Int
    public var column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

// swiftlint:enable discouraged_optional_boolean discouraged_optional_collection
