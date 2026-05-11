import Foundation
#if canImport(AppKit)
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

        /// Whether syntax highlighting is enabled.
        public var isSyntaxHighlightingEnabled: Bool = true

        /// Font size for the editor text.
        public var fontSize: CGFloat = PlatformConstants.defaultFontSize

        /// Whether line numbers are enabled in the gutter.
        public var isLineNumbersEnabled: Bool = true

        /// Whether annotations support is enabled.
        public var areAnnotationsEnabled: Bool = true

        /// Whether the currently selected line is highlighted.
        public var isSelectedLineHighlighted: Bool = true

        /// Color used to highlight the selected line.
        public var selectedLineHighlightColor: PlatformColor = PlatformColors.selectedLineHighlight

        /// Number of lines visible in the editor.
        public var visibleLines: Int = PlatformConstants.defaultVisibleLines

        /// Whether invisible characters (spaces, tabs) are visible.
        /// - Note: Only supported on macOS. Not available on iOS or Mac Catalyst due to TextKit limitations.
        public var areInvisibleCharactersVisible: Bool = false

        /// Whether code folding functionality is enabled.
        public var isCodeFoldingEnabled: Bool = false

        /// Whether folding controls are visible in the gutter.
        public var areFoldingControlsVisible: Bool = false

        /// Minimum number of lines required for folding.
        public var minimumFoldableLines: Int = PlatformConstants.minimumFoldableLines

        /// Whether the minimap is visible.
        public var isMinimapVisible: Bool = false

        /// When `true` AND a range-highlighting controller is active,
        /// the legacy attributed-text highlighter is suppressed for
        /// character edits — the range attribute applier (Phase 2A)
        /// handles text styling instead.
        ///
        /// The legacy highlighter still runs for full-document initial
        /// highlighting when no range provider is registered for the
        /// current language. Set this to `true` after validating the
        /// range attribute applier's output against the legacy highlighter.
        public var useRangeStoreHighlighting: Bool = false

        // MARK: - Initialization

        public init() {}
    }
}

// MARK: - Codable Implementation

extension EditorConfiguration.Display: Codable {
    private enum CodingKeys: String, CodingKey {
        case isSyntaxHighlightingEnabled
        case fontSize
        case isLineNumbersEnabled
        case areAnnotationsEnabled
        case isSelectedLineHighlighted
        case selectedLineHighlightColor
        case visibleLines
        case areInvisibleCharactersVisible
        case isCodeFoldingEnabled
        case areFoldingControlsVisible
        case minimumFoldableLines
        case isMinimapVisible
        case useRangeStoreHighlighting
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isSyntaxHighlightingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSyntaxHighlightingEnabled) ?? true
        fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? 14
        isLineNumbersEnabled = try container.decodeIfPresent(Bool.self, forKey: .isLineNumbersEnabled) ?? true
        areAnnotationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .areAnnotationsEnabled) ?? true
        isSelectedLineHighlighted = try container.decodeIfPresent(Bool.self, forKey: .isSelectedLineHighlighted) ?? true
        if let colorData = try container.decodeIfPresent(CodableColor.self, forKey: .selectedLineHighlightColor) {
            selectedLineHighlightColor = colorData.platformColor
        } else {
            selectedLineHighlightColor = PlatformColors.selectedLineHighlight
        }
        visibleLines = try container.decodeIfPresent(Int.self, forKey: .visibleLines) ?? 50
        areInvisibleCharactersVisible = try container.decodeIfPresent(Bool.self, forKey: .areInvisibleCharactersVisible) ?? false
        isCodeFoldingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isCodeFoldingEnabled) ?? false
        areFoldingControlsVisible = try container.decodeIfPresent(Bool.self, forKey: .areFoldingControlsVisible) ?? false
        minimumFoldableLines = try container.decodeIfPresent(Int.self, forKey: .minimumFoldableLines) ?? 3
        isMinimapVisible = try container.decodeIfPresent(Bool.self, forKey: .isMinimapVisible) ?? false
        useRangeStoreHighlighting = try container.decodeIfPresent(Bool.self, forKey: .useRangeStoreHighlighting) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isSyntaxHighlightingEnabled, forKey: .isSyntaxHighlightingEnabled)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(isLineNumbersEnabled, forKey: .isLineNumbersEnabled)
        try container.encode(areAnnotationsEnabled, forKey: .areAnnotationsEnabled)
        try container.encode(isSelectedLineHighlighted, forKey: .isSelectedLineHighlighted)
        try container.encode(CodableColor(color: selectedLineHighlightColor), forKey: .selectedLineHighlightColor)
        try container.encode(visibleLines, forKey: .visibleLines)
        try container.encode(areInvisibleCharactersVisible, forKey: .areInvisibleCharactersVisible)
        try container.encode(isCodeFoldingEnabled, forKey: .isCodeFoldingEnabled)
        try container.encode(areFoldingControlsVisible, forKey: .areFoldingControlsVisible)
        try container.encode(minimumFoldableLines, forKey: .minimumFoldableLines)
        try container.encode(isMinimapVisible, forKey: .isMinimapVisible)
        try container.encode(useRangeStoreHighlighting, forKey: .useRangeStoreHighlighting)
    }
}
