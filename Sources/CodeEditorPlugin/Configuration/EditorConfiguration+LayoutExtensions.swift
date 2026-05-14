import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension EditorConfiguration {
    /// Layout configuration options for text formatting and spacing.
    ///
    /// Controls text layout properties including tabs, wrapping, padding,
    /// and gutter appearance.
    public struct Layout: Equatable, Sendable {
        // MARK: - Properties

        /// Width of tab characters in number of spaces
        public var tabWidth: Int = PlatformConstants.defaultTabWidth

        /// Whether to insert spaces instead of tabs
        public var insertSpacesForTabs: Bool = true

        /// Whether to wrap lines at the editor width
        public var wrapLines: Bool = false

        /// Width of the line numbers gutter
        public var gutterWidth: CGFloat = PlatformConstants.defaultGutterWidth

        /// Padding for line numbers within the gutter
        public var lineNumberPadding: CGFloat = PlatformConstants.defaultLineNumberPadding

        /// Text container inset
        public var textContainerInset = PlatformConstants.defaultTextContainerInset

        /// Line height multiple
        public var lineHeightMultiple: CGFloat = PlatformConstants.defaultLineHeightMultiple

        /// Inter-character spacing
        public var characterSpacing: CGFloat = 0

        /// Text container fraction (1.0 = full width)
        public var textContainerWidthFraction: CGFloat = 1.0

        /// Size of annotation badges
        public var annotationBadgeSize: CGFloat = 16.0

        /// Padding around annotation badges
        public var annotationBadgePadding: CGFloat = 4.0

        /// Width of the minimap view
        public var minimapWidth: CGFloat = 120.0

        /// Size of fold/unfold control buttons in the gutter
        public var foldingControlSize: CGFloat = 14.0

        /// Padding around folding control buttons
        public var foldingControlPadding: CGFloat = 2.0

        // MARK: - Initialization

        public init() {}
    }
}

// MARK: - Codable Implementation

extension EditorConfiguration.Layout: Codable {
    private enum CodingKeys: String, CodingKey {
        case tabWidth
        case insertSpacesForTabs
        case wrapLines
        case gutterWidth
        case lineNumberPadding
        case textContainerInsetTop
        case textContainerInsetLeading
        case textContainerInsetBottom
        case textContainerInsetTrailing
        case lineHeightMultiple
        case characterSpacing
        case textContainerWidthFraction
        case annotationBadgeSize
        case annotationBadgePadding
        case minimapWidth
        case foldingControlSize
        case foldingControlPadding
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tabWidth = try container.decodeIfPresent(Int.self, forKey: .tabWidth) ?? 4
        insertSpacesForTabs = try container.decodeIfPresent(Bool.self, forKey: .insertSpacesForTabs) ?? true
        wrapLines = try container.decodeIfPresent(Bool.self, forKey: .wrapLines) ?? false
        gutterWidth = try container.decodeIfPresent(CGFloat.self, forKey: .gutterWidth) ?? 50
        lineNumberPadding = try container.decodeIfPresent(CGFloat.self, forKey: .lineNumberPadding) ?? 8.0

        let top = try container.decodeIfPresent(CGFloat.self, forKey: .textContainerInsetTop) ?? 8
        let leading = try container.decodeIfPresent(CGFloat.self, forKey: .textContainerInsetLeading) ?? 8
        let bottom = try container.decodeIfPresent(CGFloat.self, forKey: .textContainerInsetBottom) ?? 8
        let trailing = try container.decodeIfPresent(CGFloat.self, forKey: .textContainerInsetTrailing) ?? 8
        textContainerInset = EdgeInsets(top: top, left: leading, bottom: bottom, right: trailing)

        lineHeightMultiple = try container.decodeIfPresent(CGFloat.self, forKey: .lineHeightMultiple) ?? 1.2
        characterSpacing = try container.decodeIfPresent(CGFloat.self, forKey: .characterSpacing) ?? 0
        textContainerWidthFraction = try container.decodeIfPresent(CGFloat.self, forKey: .textContainerWidthFraction) ?? 1.0
        annotationBadgeSize = try container.decodeIfPresent(CGFloat.self, forKey: .annotationBadgeSize) ?? 16.0
        annotationBadgePadding = try container.decodeIfPresent(CGFloat.self, forKey: .annotationBadgePadding) ?? 4.0
        minimapWidth = try container.decodeIfPresent(CGFloat.self, forKey: .minimapWidth) ?? 120.0
        foldingControlSize = try container.decodeIfPresent(CGFloat.self, forKey: .foldingControlSize) ?? 14.0
        foldingControlPadding = try container.decodeIfPresent(CGFloat.self, forKey: .foldingControlPadding) ?? 2.0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tabWidth, forKey: .tabWidth)
        try container.encode(insertSpacesForTabs, forKey: .insertSpacesForTabs)
        try container.encode(wrapLines, forKey: .wrapLines)
        try container.encode(gutterWidth, forKey: .gutterWidth)
        try container.encode(lineNumberPadding, forKey: .lineNumberPadding)
        try container.encode(textContainerInset.top, forKey: .textContainerInsetTop)
        try container.encode(textContainerInset.left, forKey: .textContainerInsetLeading)
        try container.encode(textContainerInset.bottom, forKey: .textContainerInsetBottom)
        try container.encode(textContainerInset.right, forKey: .textContainerInsetTrailing)
        try container.encode(lineHeightMultiple, forKey: .lineHeightMultiple)
        try container.encode(characterSpacing, forKey: .characterSpacing)
        try container.encode(textContainerWidthFraction, forKey: .textContainerWidthFraction)
        try container.encode(annotationBadgeSize, forKey: .annotationBadgeSize)
        try container.encode(annotationBadgePadding, forKey: .annotationBadgePadding)
        try container.encode(minimapWidth, forKey: .minimapWidth)
        try container.encode(foldingControlSize, forKey: .foldingControlSize)
        try container.encode(foldingControlPadding, forKey: .foldingControlPadding)
    }
}
