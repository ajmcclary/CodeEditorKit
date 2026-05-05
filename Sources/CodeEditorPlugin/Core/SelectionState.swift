import Foundation

/// Caret/selection position in the active document.
///
/// Line and column are 1-based to match the convention used throughout
/// editor UIs. `selectionLength` is in characters (not bytes); zero means
/// caret-only with no selected range.
public struct SelectionState: Hashable, Sendable {
    /// 1-based line number.
    public var line: Int
    /// 1-based column number, in display columns.
    public var column: Int
    /// Length of the active selection in characters; zero when caret-only.
    public var selectionLength: Int

    /// Creates a new selection state.
    /// - Parameters:
    ///   - line: 1-based line number.
    ///   - column: 1-based column number.
    ///   - selectionLength: length in characters; defaults to 0 (caret-only).
    public init(line: Int, column: Int, selectionLength: Int = 0) {
        self.line = line
        self.column = column
        self.selectionLength = selectionLength
    }
}
