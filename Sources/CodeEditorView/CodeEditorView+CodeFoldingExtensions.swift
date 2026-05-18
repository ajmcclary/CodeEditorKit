import CodeEditorLanguages
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Public Code Folding API

extension CodeEditorView {
    /// Toggle fold state at the specified line number.
    ///
    /// If the line contains a foldable region that is currently expanded, it will be folded.
    /// If the line contains a folded region, it will be unfolded.
    ///
    /// - Parameter lineNumber: The line number to toggle folding at (1-based)
    /// - Returns: `true` if the fold state was changed, `false` if no foldable region exists
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Toggle folding at line 25
    /// if editor.toggleFold(at: 25) {
    ///     print("Folding toggled successfully")
    /// }
    /// ```
    public func toggleFold(at lineNumber: Int) -> Bool {
        guard configuration.display.isCodeFoldingEnabled else { return false }

        return codeFoldingEngine.toggleFold(at: lineNumber)
    }

    /// Fold a code region at the specified line number.
    ///
    /// This method folds a foldable code region that starts at or contains the specified line.
    /// Common foldable regions include functions, classes, blocks, and comments.
    ///
    /// - Parameter lineNumber: The line number where folding should occur (1-based)
    /// - Returns: `true` if folding was successful, `false` if no foldable region exists
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fold function at line 42
    /// if editor.fold(at: 42) {
    ///     print("Function folded")
    /// }
    /// ```
    public func fold(at lineNumber: Int) -> Bool {
        guard configuration.display.isCodeFoldingEnabled else { return false }

        if let region = codeFoldingEngine.foldableRegion(at: lineNumber) {
            return codeFoldingEngine.fold(region)
        }
        return false
    }

    /// Unfold a code region at the specified line number.
    ///
    /// This method unfolds a previously folded code region at the specified line.
    ///
    /// - Parameter lineNumber: The line number where unfolding should occur (1-based)
    /// - Returns: `true` if unfolding was successful, `false` if no folded region exists
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Unfold code at line 42
    /// if editor.unfold(at: 42) {
    ///     print("Code unfolded")
    /// }
    /// ```
    public func unfold(at lineNumber: Int) -> Bool {
        guard configuration.display.isCodeFoldingEnabled else { return false }

        if let region = codeFoldingEngine.foldableRegion(at: lineNumber) {
            return codeFoldingEngine.unfold(region)
        }
        return false
    }

    /// Check if a line contains a foldable code region.
    ///
    /// Use this method to determine if folding controls should be shown for a specific line
    /// or to validate before attempting folding operations.
    ///
    /// - Parameter lineNumber: The line number to check (1-based)
    /// - Returns: `true` if the line contains a foldable region, `false` otherwise
    ///
    /// ## Example
    ///
    /// ```swift
    /// if editor.isFoldable(at: 25) {
    ///     // Show folding controls in UI
    ///     showFoldingButton(at: 25)
    /// }
    /// ```
    public func isFoldable(at lineNumber: Int) -> Bool {
        guard configuration.display.isCodeFoldingEnabled else { return false }
        return codeFoldingEngine.isStartOfFoldableRegion(lineNumber)
    }

    /// Check if a line is currently folded.
    ///
    /// - Parameter lineNumber: The line number to check (1-based)
    /// - Returns: `true` if the line is part of a folded region, `false` otherwise
    ///
    /// ## Example
    ///
    /// ```swift
    /// if editor.isFolded(at: 25) {
    ///     print("Line 25 is currently folded")
    /// }
    /// ```
    public func isFolded(at lineNumber: Int) -> Bool {
        guard configuration.display.isCodeFoldingEnabled else { return false }
        return codeFoldingEngine.isLineFolded(lineNumber)
    }

    /// Fold all regions of a specific type.
    ///
    /// This method folds all foldable regions of the specified type throughout the document.
    /// Useful for quickly collapsing all functions, classes, or other code structures.
    ///
    /// - Parameter type: The type of regions to fold
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fold all functions
    /// editor.foldAll(type: .function)
    ///
    /// // Fold all classes
    /// editor.foldAll(type: .class)
    ///
    /// // Fold all comments
    /// editor.foldAll(type: .comment)
    /// ```
    internal func foldAll(type: FoldingType) {
        guard configuration.display.isCodeFoldingEnabled else { return }

        let regionsToFold = codeFoldingEngine.foldableRegions.filter { $0.type == type }
        for region in regionsToFold {
            codeFoldingEngine.fold(region)
        }
    }

    /// Fold every foldable region in the document.
    ///
    /// Collapses all detected foldable code regions regardless of type
    /// (functions, classes, blocks, comments). Inert when code folding is
    /// disabled in `EditorConfiguration.display.isCodeFoldingEnabled`.
    public func foldAll() {
        guard configuration.display.isCodeFoldingEnabled else { return }

        for region in codeFoldingEngine.foldableRegions {
            codeFoldingEngine.fold(region)
        }
    }

    /// Unfold all currently folded regions.
    ///
    /// This method expands all folded code regions in the document, making all text visible.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Expand all folded code
    /// editor.unfoldAll()
    /// ```
    public func unfoldAll() {
        guard configuration.display.isCodeFoldingEnabled else { return }
        codeFoldingEngine.unfoldAll()
    }

    /// Get all foldable regions in the document.
    ///
    /// Returns an array of all detected foldable regions, useful for building custom
    /// folding interfaces or performing bulk operations.
    ///
    /// - Returns: Array of foldable regions with their line ranges and types
    ///
    /// ## Example
    ///
    /// ```swift
    /// let regions = editor.foldableRegions
    /// for region in regions {
    ///     print("Foldable \(region.type) at lines \(region.startLine)-\(region.endLine)")
    /// }
    /// ```
    internal var foldableRegions: [FoldableRegion] {
        guard configuration.display.isCodeFoldingEnabled else { return [] }
        return codeFoldingEngine.foldableRegions
    }

    /// Get all currently folded regions.
    ///
    /// - Returns: Array of currently folded regions
    internal var foldedRegions: [FoldableRegion] {
        guard configuration.display.isCodeFoldingEnabled else { return [] }
        return codeFoldingEngine.foldableRegions.filter { region in
            codeFoldingEngine.foldedRegions.contains(region.id)
        }
    }
}
