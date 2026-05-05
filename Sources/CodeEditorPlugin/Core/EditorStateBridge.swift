import Foundation

/// Internal helper for converting editor primitives (`NSRange`, raw
/// text) into the value types `EditorState` expects. Lives in the
/// editor target so the SwiftUI bridge's call sites can use it without
/// importing `CodeEditorUI`.
enum EditorStateBridge {
    /// Maps an `NSRange` over `text` to a `SelectionState` with 1-based
    /// line and column. Walks `text` from the start to the range's
    /// `location` counting newlines. O(n) — fine for typical selection
    /// changes. For very large documents the editor can cache line
    /// offsets and short-circuit; that's a sub-project 3 concern.
    static func deriveSelection(from range: NSRange, in text: String) -> SelectionState {
        let utf16Length = text.utf16.count
        let safeLocation = max(0, min(range.location, utf16Length))
        let utf16View = text.utf16
        let endIndex = utf16View.index(utf16View.startIndex, offsetBy: safeLocation)
        let prefix = String(utf16View[utf16View.startIndex..<endIndex]) ?? ""
        let lines = prefix.components(separatedBy: "\n")
        let line = lines.count
        let column = (lines.last?.count ?? 0) + 1
        return SelectionState(line: line, column: column, selectionLength: range.length)
    }

    /// Counts lines in `text` (number of `\n` + 1, or 0 for empty).
    static func lineCount(of text: String) -> Int {
        if text.isEmpty { return 0 }
        return text.components(separatedBy: "\n").count
    }
}
