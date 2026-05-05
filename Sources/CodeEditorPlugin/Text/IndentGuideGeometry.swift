import Foundation

/// Pure-value indent-guide arithmetic. UI-free; operates on whitespace
/// strings and integers so the renderer can compose results with theme
/// colors to produce the actual draw calls.
public enum IndentGuideGeometry {
    /// Returns the indent-column indices that should have a guide drawn,
    /// given the leading-whitespace prefix of a line and the tab width.
    /// Returns an empty array when `tabWidth <= 0` or when the depth is
    /// less than two indent stops (no inner guide to draw).
    public static func indentColumns(
        forLeadingWhitespace leading: String,
        tabWidth: Int
    ) -> [Int] {
        guard tabWidth > 0 else { return [] }
        var spaces = 0
        for ch in leading {
            if ch == " " {
                spaces += 1
            } else if ch == "\t" {
                spaces += tabWidth
            } else {
                break
            }
        }
        let depth = spaces / tabWidth
        guard depth >= 2 else { return [] }
        return Array(1..<depth)
    }

    /// Blank-line continuity: a blank line inherits the indent depth of
    /// its prior non-blank neighbor.
    public static func effectiveDepth(forBlankLineWithPriorDepth priorDepth: Int) -> Int {
        priorDepth
    }
}
