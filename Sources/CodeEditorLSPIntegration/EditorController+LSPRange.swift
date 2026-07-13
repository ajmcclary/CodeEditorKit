import CodeEditorLSP
import CodeEditorSwiftUI
import Foundation

#if canImport(SwiftUI)

extension EditorController {
    /// Convert an LSP range (a `(start, end)` pair of zero-based positions)
    /// into a UTF-16 `NSRange` in the editor's content. Returns nil when
    /// no view is attached or either endpoint is out of range.
    ///
    /// This is the supported way to convert LSP diagnostics, hover ranges,
    /// definitions, etc. into editor offsets — host code should not
    /// attempt to reimplement `(line, character)` arithmetic from the
    /// outside, since the buffer is the only source of truth for line
    /// boundaries.
    ///
    /// Lives in `CodeEditorLSPIntegration` (not `CodeEditorSwiftUI`) so the
    /// SwiftUI host target — and therefore the umbrella — carries no
    /// `CodeEditorLSP` dependency.
    public func nsRange(forLSPRange lspRange: LSPRange) -> NSRange? {
        guard let start = nsLocation(
            forLSPLine: lspRange.start.line,
            character: lspRange.start.character
        ),
        let end = nsLocation(
            forLSPLine: lspRange.end.line,
            character: lspRange.end.character
        ) else { return nil }
        let length = max(0, end - start)
        return NSRange(location: start, length: length)
    }
}

#endif
