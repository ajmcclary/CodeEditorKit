import Foundation

/// The value-oriented contract an editor uses to obtain syntax highlights.
///
/// This is the decentralized replacement for the editor's old internal
/// `RangeHighlightProviding` seam, which was main-actor-bound and took a
/// concrete editor view. Every method here trades in `Sendable` value types
/// (``HighlightDocumentSnapshot``, ``HighlightTextEdit``, ``HighlightRange``,
/// ``HighlightToken``, ``HighlightInvalidation``) and never names an editor
/// view, so an external package — for example a future tree-sitter adapter —
/// can conform without depending on the editor surface and without being
/// pinned to the main actor.
///
/// The editor drives the contract in a pull loop: it ``prepare(for:)``s the
/// provider once per document/language, asks it to ``invalidate(for:in:)``
/// after each edit, and ``highlights(in:of:)`` visible ranges on demand.
public protocol HighlightRangeProviding: AnyObject, Sendable {
    /// Prepares the provider for a document. Called once on attach and again
    /// whenever the language changes.
    func prepare(for document: HighlightDocumentSnapshot) async

    /// Reports which regions are stale after an edit. The editor re-queries
    /// only the intersection of the result with the visible viewport.
    func invalidate(
        for edit: HighlightTextEdit,
        in document: HighlightDocumentSnapshot
    ) async -> HighlightInvalidation

    /// Returns the highlight tokens intersecting `range` in the given
    /// document snapshot. Token ranges are document-relative (UTF-16).
    func highlights(
        in range: HighlightRange,
        of document: HighlightDocumentSnapshot
    ) async throws -> [HighlightToken]
}
