import Foundation

/// Internal helper for converting editor primitives (`NSRange`, raw
/// text) into the value types `EditorState` expects. Lives in the
/// editor target so the SwiftUI bridge's call sites can use it without
/// importing `CodeEditorUI`.
enum EditorStateBridge {
    /// Maps an `NSRange` over `text` to a `SelectionState` with 1-based
    /// line and column. Walks `text` from the start to the range's
    /// `location` counting newlines. O(n) — fine for typical selection
    /// changes.
    ///
    /// For very large documents, use `deriveSelection(from:in:lineGeometryStore:)`
    /// which accepts a pre-built line geometry store to avoid repeated O(n)
    /// newline walks.
    static func deriveSelection(from range: NSRange, in text: String) -> SelectionState {
        deriveSelection(from: range, utf16View: text.utf16)
    }

    /// Cache-aware overload that uses a `LineGeometryStore` for O(log n)
    /// line lookups instead of O(n) newline-walking. Prefer this over
    /// `deriveSelection(from:in:)` when a line geometry store is available
    /// (e.g., from `CodeEditorView.lineGeometryStore`).
    @MainActor
    static func deriveSelection(from range: NSRange, in text: String, lineGeometryStore: LineGeometryStore) -> SelectionState {
        let utf16Length = text.utf16.count
        let safeLocation = max(0, min(range.location, utf16Length))
        let lineIdx = lineGeometryStore.lineIndex(forUtf16Offset: safeLocation)
        let lineStart = lineGeometryStore.utf16Offset(forLineIndex: lineIdx)
        let column = safeLocation - lineStart + 1
        return SelectionState(line: lineIdx + 1, column: column, selectionLength: range.length)
    }

    /// Cache-aware overload that uses a `LineIndexCache` for O(log n)
    /// line lookups. Deprecated in favor of `deriveSelection(from:in:lineGeometryStore:)`
    /// which uses the UTF-16-correct `LineGeometryStore`.
    @available(*, deprecated, message: "Use deriveSelection(from:in:lineGeometryStore:) for UTF-16 correctness")
    static func deriveSelection(from range: NSRange, in text: String, lineIndexCache: LineIndexCache) -> SelectionState {
        let utf16Length = text.utf16.count
        let safeLocation = max(0, min(range.location, utf16Length))
        let (line, column) = lineIndexCache.lineAndColumn(at: safeLocation, in: text)
        return SelectionState(line: line, column: column, selectionLength: range.length)
    }

    /// Counts lines in `text` (number of `\n` + 1, or 0 for empty).
    static func lineCount(of text: String) -> Int {
        if text.isEmpty { return 0 }
        return text.components(separatedBy: "\n").count
    }

    // MARK: - Private

    private static func deriveSelection(from range: NSRange, utf16View: String.UTF16View) -> SelectionState {
        let utf16Length = utf16View.count
        let safeLocation = max(0, min(range.location, utf16Length))
        let endIndex = utf16View.index(utf16View.startIndex, offsetBy: safeLocation)
        let prefix = String(utf16View[utf16View.startIndex..<endIndex]) ?? ""
        let lines = prefix.components(separatedBy: "\n")
        let line = lines.count
        let column = (lines.last?.count ?? 0) + 1
        return SelectionState(line: line, column: column, selectionLength: range.length)
    }
}
