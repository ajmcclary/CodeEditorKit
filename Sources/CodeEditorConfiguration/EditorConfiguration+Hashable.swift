import Foundation

extension EditorConfiguration: Hashable {
    /// Helper to generate a stable hash for caching purposes.
    ///
    /// Hashes a stable subset of properties (font size, line numbers,
    /// invisible character visibility) suitable for layout-cache keying.
    /// The full equality semantics live in `EditorConfiguration+Equatable`
    /// in this target. Relocated from umbrella `Core/LineNumberCalculationService`
    /// during §6.2.11 so `CodeEditorLayout` could see the Hashable conformance.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(display.fontSize)
        hasher.combine(display.isLineNumbersEnabled)
        hasher.combine(display.areInvisibleCharactersVisible)
    }
}
