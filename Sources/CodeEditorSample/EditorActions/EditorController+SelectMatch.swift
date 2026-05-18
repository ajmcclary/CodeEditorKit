#if canImport(AppKit)
import CodeEditorPlugin
import CodeEditorSearch
import Foundation

extension EditorController {
    /// Routes a project-search hit into the editor: computes the NSRange
    /// from `(lineNumber, column, matchedText)`, selects it, and scrolls
    /// it into view. Returns `false` when `lineNumber`/`column` falls
    /// outside the attached document (e.g. file changed since indexing).
    @discardableResult
    public func selectMatch(_ result: ProjectSearchResult) -> Bool {
        // ProjectSearchResult line/column are 1-based; LSP positions are 0-based.
        let lspLine = result.lineNumber - 1
        let lspChar = result.column - 1
        guard lspLine >= 0, lspChar >= 0,
              let start = nsLocation(forLSPLine: lspLine, character: lspChar) else {
            return false
        }
        let length = result.matchedText.utf16.count
        let range = NSRange(location: start, length: length)
        selectRange(range, scroll: true)
        return true
    }
}
#endif
