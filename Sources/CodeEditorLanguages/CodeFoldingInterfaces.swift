import CodeEditorTextModel
import Foundation

/// UTF-16 offset of the start of each line in `lines`, where `lines` came
/// from splitting a document on single-unit line separators.
func utf16LineStartLocations(of lines: [String]) -> [Int] {
    var locations: [Int] = []
    locations.reserveCapacity(lines.count)
    var cursor = 0
    for line in lines {
        locations.append(cursor)
        cursor += TextRangeUtilities.utf16Length(of: line) + 1
    }
    return locations
}

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
