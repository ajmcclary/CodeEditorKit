import Foundation

// MARK: - Foldable Region

/// Represents a foldable region in the text
public struct FoldableRegion: Identifiable {
    public let id = UUID()
    public var range: NSRange
    public var title: String
    public var type: FoldingType
    public var level: Int = 0
    public var parentId: UUID?
    public var foldedText: String?

    public init(range: NSRange, title: String, type: FoldingType) {
        self.range = range
        self.title = title
        self.type = type
    }
}

// MARK: - Folding Type

/// Types of foldable regions
public enum FoldingType: Equatable, Sendable {
    case function
    case `class`
    case method
    case block
    case comment
    case imports
    case region
    case custom(String)
}

// MARK: - Code Folding Provider Protocol

/// Protocol for language-specific folding providers
@MainActor
public protocol CodeFoldingProvider {
    /// Detect foldable regions in the supplied source text.
    /// - Parameter text: The full source text to scan.
    /// - Returns: All foldable regions discovered.
    func detectFoldableRegions(in text: String) async -> [FoldableRegion]
}
