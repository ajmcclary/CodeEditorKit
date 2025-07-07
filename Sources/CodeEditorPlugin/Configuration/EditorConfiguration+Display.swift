import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension EditorConfiguration {
    /// Display configuration options for visual elements.
    ///
    /// Controls the appearance of code editor features including syntax highlighting,
    /// line numbers, code folding, and visual indicators.
    public struct Display: Equatable, Sendable {
        // MARK: - Properties
        
        /// Whether to enable syntax highlighting
        public var enableSyntaxHighlighting: Bool = true
        
        /// Alias for enableSyntaxHighlighting for backward compatibility
        @available(*, deprecated, renamed: "enableSyntaxHighlighting")
        public var syntaxHighlighting: Bool {
            get { enableSyntaxHighlighting }
            set { enableSyntaxHighlighting = newValue }
        }
        
        /// Font size for the editor text
        public var fontSize: CGFloat = PlatformConstants.defaultFontSize
        
        /// Whether to show line numbers in the gutter
        public var showLineNumbers: Bool = true
        
        /// Whether to enable annotations support
        public var enableAnnotations: Bool = true
        
        /// Alias for enableAnnotations for backward compatibility
        @available(*, deprecated, renamed: "enableAnnotations")
        public var annotations: Bool {
            get { enableAnnotations }
            set { enableAnnotations = newValue }
        }
        
        /// Whether to highlight the currently selected line
        public var highlightSelectedLine: Bool = true
        
        /// Color used to highlight the selected line
        public var selectedLineHighlightColor: PlatformColor = PlatformColors.selectedLineHighlight
        
        /// Number of lines visible in the editor
        public var visibleLines: Int = PlatformConstants.defaultVisibleLines
        
        /// Whether to show invisible characters (spaces, tabs)
        public var showInvisibleCharacters: Bool = false
        
        /// Whether to show indent guides (vertical lines at indentation levels)
        public var showIndentGuides: Bool = false
        
        /// Whether to enable code folding functionality
        public var enableCodeFolding: Bool = false
        
        /// Alias for enableCodeFolding for backward compatibility
        @available(*, deprecated, renamed: "enableCodeFolding")
        public var codeFolding: Bool {
            get { enableCodeFolding }
            set { enableCodeFolding = newValue }
        }
        
        /// Whether to show folding controls in the gutter
        public var showFoldingControls: Bool = false
        
        /// Minimum number of lines required for folding
        public var minimumFoldableLines: Int = PlatformConstants.minimumFoldableLines
        
        /// Whether to animate code folding/unfolding
        public var animateCodeFolding: Bool = true
        
        /// Whether to show a minimap
        public var showMinimap: Bool = false
        
        /// Whether to automatically scroll to keep cursor visible
        public var autoScrollToCursor: Bool = true
        
        // MARK: - Initialization
        
        public init() {}
    }
}

// MARK: - Codable Implementation

extension EditorConfiguration.Display: Codable {
    private enum CodingKeys: String, CodingKey {
        case enableSyntaxHighlighting
        case fontSize
        case showLineNumbers
        case enableAnnotations
        case highlightSelectedLine
        case selectedLineHighlightColor
        case visibleLines
        case showInvisibleCharacters
        case showIndentGuides
        case enableCodeFolding
        case showFoldingControls
        case minimumFoldableLines
        case animateCodeFolding
        case showMinimap
        case autoScrollToCursor
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enableSyntaxHighlighting = try container.decodeIfPresent(Bool.self, forKey: .enableSyntaxHighlighting) ?? true
        fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? 14
        showLineNumbers = try container.decodeIfPresent(Bool.self, forKey: .showLineNumbers) ?? true
        enableAnnotations = try container.decodeIfPresent(Bool.self, forKey: .enableAnnotations) ?? true
        highlightSelectedLine = try container.decodeIfPresent(Bool.self, forKey: .highlightSelectedLine) ?? true
        if let colorData = try container.decodeIfPresent(CodableColor.self, forKey: .selectedLineHighlightColor) {
            selectedLineHighlightColor = colorData.platformColor
        } else {
            selectedLineHighlightColor = PlatformColors.selectedLineHighlight
        }
        visibleLines = try container.decodeIfPresent(Int.self, forKey: .visibleLines) ?? 50
        showInvisibleCharacters = try container.decodeIfPresent(Bool.self, forKey: .showInvisibleCharacters) ?? false
        showIndentGuides = try container.decodeIfPresent(Bool.self, forKey: .showIndentGuides) ?? false
        enableCodeFolding = try container.decodeIfPresent(Bool.self, forKey: .enableCodeFolding) ?? false
        showFoldingControls = try container.decodeIfPresent(Bool.self, forKey: .showFoldingControls) ?? false
        minimumFoldableLines = try container.decodeIfPresent(Int.self, forKey: .minimumFoldableLines) ?? 3
        animateCodeFolding = try container.decodeIfPresent(Bool.self, forKey: .animateCodeFolding) ?? true
        showMinimap = try container.decodeIfPresent(Bool.self, forKey: .showMinimap) ?? false
        autoScrollToCursor = try container.decodeIfPresent(Bool.self, forKey: .autoScrollToCursor) ?? true
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enableSyntaxHighlighting, forKey: .enableSyntaxHighlighting)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(showLineNumbers, forKey: .showLineNumbers)
        try container.encode(enableAnnotations, forKey: .enableAnnotations)
        try container.encode(highlightSelectedLine, forKey: .highlightSelectedLine)
        try container.encode(CodableColor(color: selectedLineHighlightColor), forKey: .selectedLineHighlightColor)
        try container.encode(visibleLines, forKey: .visibleLines)
        try container.encode(showInvisibleCharacters, forKey: .showInvisibleCharacters)
        try container.encode(showIndentGuides, forKey: .showIndentGuides)
        try container.encode(enableCodeFolding, forKey: .enableCodeFolding)
        try container.encode(showFoldingControls, forKey: .showFoldingControls)
        try container.encode(minimumFoldableLines, forKey: .minimumFoldableLines)
        try container.encode(animateCodeFolding, forKey: .animateCodeFolding)
        try container.encode(showMinimap, forKey: .showMinimap)
        try container.encode(autoScrollToCursor, forKey: .autoScrollToCursor)
    }
}
