import CodeEditorPlatform
import Foundation

// MARK: - Foldable Region

/// Represents a foldable region in the text
internal struct FoldableRegion: Identifiable {
    internal let id = UUID()
    internal var range: NSRange
    internal var title: String
    internal var type: FoldingType
    internal var level: Int = 0
    internal var parentId: UUID?
    internal var foldedText: String?

    init(range: NSRange, title: String, type: FoldingType) {
        self.range = range
        self.title = title
        self.type = type
    }
}

// MARK: - Folding Type

/// Types of foldable regions
internal enum FoldingType: Equatable {
    case function
    case `class`
    case method
    case block
    case comment
    case imports
    case region
    case custom(String)
}

// MARK: - Code Folding Configuration

/// Configuration for code folding behavior
internal struct CodeFoldingConfiguration {
    internal var enabled = true
    internal var showGutterControls = true
    internal var hidesFoldedContent = true
    internal var minimumLineCount = 3
    internal var foldedIndicator = " ⋯ "

    internal var indicatorColor = PlatformColors.secondaryLabel

    internal var animatesFolding = true
    internal var saveFoldState = true
    internal var enableIncrementalUpdates = true
}

// MARK: - Code Folding Provider Protocol

/// Protocol for language-specific folding providers
@MainActor
internal protocol CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion]
}
