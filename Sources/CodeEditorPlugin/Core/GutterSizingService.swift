import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Gutter Sizing Service

/// Service responsible for gutter width calculations and sizing decisions
/// Extracts business logic from various layout helpers and hardcoded values
@MainActor
public final class GutterSizingService {
    // MARK: - Types

    /// Result of gutter width calculation.
    ///
    /// `SizingResult` provides comprehensive information about the calculated
    /// gutter dimensions, including optimal, minimum, and maximum widths.
    public struct SizingResult {
        /// The calculated optimal width for the gutter
        public let optimalWidth: CGFloat
        /// The minimum acceptable gutter width
        public let minimumWidth: CGFloat
        /// The maximum allowable gutter width
        public let maximumWidth: CGFloat
        /// The recommended width after applying optimizations
        public let recommendedWidth: CGFloat
        /// Whether the gutter width should be updated
        public let shouldUpdate: Bool

        /// Creates a new sizing result.
        ///
        /// - Parameters:
        ///   - optimalWidth: The calculated optimal width
        ///   - minimumWidth: The minimum acceptable width
        ///   - maximumWidth: The maximum allowable width
        ///   - recommendedWidth: The recommended width after optimizations
        ///   - shouldUpdate: Whether the width should be updated
        public init(
            optimalWidth: CGFloat,
            minimumWidth: CGFloat,
            maximumWidth: CGFloat,
            recommendedWidth: CGFloat,
            shouldUpdate: Bool
        ) {
            self.optimalWidth = optimalWidth
            self.minimumWidth = minimumWidth
            self.maximumWidth = maximumWidth
            self.recommendedWidth = recommendedWidth
            self.shouldUpdate = shouldUpdate
        }
    }

    /// Constraints for gutter sizing calculations.
    ///
    /// `SizingConstraints` defines the parameters and limits used when
    /// calculating gutter dimensions, allowing customization of sizing behavior.
    public struct SizingConstraints {
        /// Minimum number of digits to display (ensures consistent width)
        public let minimumDigits: Int
        /// Maximum number of digits to accommodate
        public let maximumDigits: Int
        /// Base padding around line numbers
        public let basePadding: CGFloat
        /// Additional padding for special cases
        public let extraPadding: CGFloat
        /// Whether the gutter can resize dynamically
        public let allowDynamicResizing: Bool

        /// Creates new sizing constraints.
        ///
        /// - Parameters:
        ///   - minimumDigits: Minimum digits to display (default: 3)
        ///   - maximumDigits: Maximum digits to accommodate (default: 10)
        ///   - basePadding: Base padding around numbers (default: 16.0)
        ///   - extraPadding: Additional padding (default: 0.0)
        ///   - allowDynamicResizing: Enable dynamic resizing (default: true)
        public init(
            minimumDigits: Int = 3,
            maximumDigits: Int = 10,
            basePadding: CGFloat = 16.0,
            extraPadding: CGFloat = 0.0,
            allowDynamicResizing: Bool = true
        ) {
            self.minimumDigits = minimumDigits
            self.maximumDigits = maximumDigits
            self.basePadding = basePadding
            self.extraPadding = extraPadding
            self.allowDynamicResizing = allowDynamicResizing
        }
    }

    // MARK: - Properties

    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "GutterSizingService")
    private let lineNumberCalculationService: LineNumberCalculationService

    // Cache for expensive font metrics
    private var fontMetricsCache: [String: CGFloat] = [:]
    private let maxCacheSize = 20

    // Configuration constants
    private let defaultConstraints = SizingConstraints()

    // MARK: - Initialization

    /// Creates a new gutter sizing service.
    ///
    /// - Parameter lineNumberCalculationService: Service for line number calculations
    public init(lineNumberCalculationService: LineNumberCalculationService) {
        self.lineNumberCalculationService = lineNumberCalculationService
    }

    // MARK: - Public Interface

    /// Calculates optimal gutter width based on line count and configuration
    public func calculateOptimalWidth(
        lineCount: Int,
        font: PlatformFont,
        configuration: EditorConfiguration,
        constraints: SizingConstraints = SizingConstraints()
    ) -> SizingResult {
        let metrics = lineNumberCalculationService.calculateGutterMetrics(
            for: lineCount,
            font: font,
            configuration: configuration
        )

        let minimumWidth = calculateMinimumWidth(
            font: font,
            configuration: configuration,
            constraints: constraints
        )

        let maximumWidth = calculateMaximumWidth(
            font: font,
            configuration: configuration,
            constraints: constraints
        )

        let optimalWidth = max(minimumWidth, min(maximumWidth, metrics.requiredWidth))
        let recommendedWidth = applyDisplayOptimizations(width: optimalWidth, configuration: configuration)

        return SizingResult(
            optimalWidth: optimalWidth,
            minimumWidth: minimumWidth,
            maximumWidth: maximumWidth,
            recommendedWidth: recommendedWidth,
            shouldUpdate: true
        )
    }

    /// Determines minimum required width for gutter based on configuration
    public func minimumRequiredWidth(
        for configuration: EditorConfiguration,
        font: PlatformFont? = nil,
        constraints: SizingConstraints = SizingConstraints()
    ) -> CGFloat {
        let effectiveFont = font ?? PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize)
        return calculateMinimumWidth(font: effectiveFont, configuration: configuration, constraints: constraints)
    }

    /// Checks if gutter width should be updated based on current state
    public func shouldUpdateWidth(
        newLineCount: Int,
        currentWidth: CGFloat,
        font: PlatformFont,
        configuration: EditorConfiguration,
        constraints: SizingConstraints = SizingConstraints()
    ) -> Bool {
        guard constraints.allowDynamicResizing else { return false }

        let result = calculateOptimalWidth(
            lineCount: newLineCount,
            font: font,
            configuration: configuration,
            constraints: constraints
        )

        // Update if the difference is significant (more than 10% or 20 points)
        let difference = abs(result.recommendedWidth - currentWidth)
        let percentageDifference = difference / currentWidth

        return percentageDifference > 0.1 || difference > 20.0
    }

    /// Calculates width adjustments for different display states
    public func calculateDisplayAdjustments(
        baseWidth: CGFloat,
        configuration: EditorConfiguration
    ) -> CGFloat {
        var adjustedWidth = baseWidth

        // Add space for folding controls if enabled
        if configuration.display.enableCodeFolding && configuration.display.showFoldingControls {
            adjustedWidth += calculateFoldingControlSpace(configuration: configuration)
        }

        // Add space for annotations if enabled
        if configuration.display.enableAnnotations {
            adjustedWidth += calculateAnnotationSpace(configuration: configuration)
        }

        // Add space for debugging indicators
        adjustedWidth += calculateDebuggingSpace(configuration: configuration)

        return adjustedWidth
    }

    /// Optimizes gutter width for different screen sizes and accessibility
    public func optimizeForAccessibility(
        baseWidth: CGFloat,
        configuration: EditorConfiguration
    ) -> CGFloat {
        var optimizedWidth = baseWidth

        // Increase width for better accessibility on smaller screens
        #if canImport(UIKit)
        let screenScale = UIKitScreenMetrics.scale
        if screenScale > 2.0 {
            optimizedWidth *= 1.1 // 10% increase for high-resolution displays
        }
        #endif

        // Accessibility font size adjustments
        let fontSize = configuration.display.fontSize
        if fontSize > 18.0 {
            optimizedWidth *= (fontSize / 18.0) // Scale proportionally
        }

        return optimizedWidth
    }

    /// Calculates gutter width for specific content scenarios
    public func calculateContextualWidth(
        contentType: ContentType,
        lineCount: Int,
        font: PlatformFont,
        configuration: EditorConfiguration
    ) -> CGFloat {
        let baseResult = calculateOptimalWidth(
            lineCount: lineCount,
            font: font,
            configuration: configuration
        )

        switch contentType {
        case .code:
            return baseResult.recommendedWidth

        case .markdown:
            // Markdown typically has fewer line numbers visible
            return baseResult.minimumWidth * 1.2

        case .json:
            // JSON can be deeply nested, may need more space
            return baseResult.recommendedWidth * 1.1

        case .log:
            // Log files can have many lines
            return baseResult.maximumWidth

        case .plainText:
            return baseResult.minimumWidth
        }
    }

    // MARK: - Cache Management

    /// Clears the font metrics cache
    public func clearCache() {
        fontMetricsCache.removeAll()
        logger.debug("Gutter sizing cache cleared")
    }
}

// MARK: - Supporting Types

/// Types of content that affect gutter sizing.
///
/// `ContentType` categorizes different types of text content, allowing
/// the gutter sizing service to optimize dimensions based on content characteristics.
public enum ContentType {
    /// Source code content (requires standard gutter)
    case code
    /// Markdown content (typically fewer visible line numbers)
    case markdown
    /// JSON content (may be deeply nested)
    case json
    /// Log file content (can have many lines)
    case log
    /// Plain text content (minimal gutter needs)
    case plainText
}

// MARK: - Private Implementation

extension GutterSizingService {
    func calculateMinimumWidth(
        font: PlatformFont,
        configuration _: EditorConfiguration,
        constraints: SizingConstraints
    ) -> CGFloat {
        let characterWidth = getCachedCharacterWidth(for: font)
        let minimumDigitWidth = CGFloat(constraints.minimumDigits) * characterWidth
        let basePadding = constraints.basePadding + constraints.extraPadding

        return minimumDigitWidth + basePadding
    }

    func calculateMaximumWidth(
        font: PlatformFont,
        configuration: EditorConfiguration,
        constraints: SizingConstraints
    ) -> CGFloat {
        let characterWidth = getCachedCharacterWidth(for: font)
        let maximumDigitWidth = CGFloat(constraints.maximumDigits) * characterWidth
        let basePadding = constraints.basePadding + constraints.extraPadding

        var maxWidth = maximumDigitWidth + basePadding
        maxWidth = calculateDisplayAdjustments(baseWidth: maxWidth, configuration: configuration)

        return maxWidth
    }

    func applyDisplayOptimizations(
        width: CGFloat,
        configuration: EditorConfiguration
    ) -> CGFloat {
        var optimizedWidth = width

        // Apply display-specific adjustments
        optimizedWidth = calculateDisplayAdjustments(baseWidth: optimizedWidth, configuration: configuration)

        // Apply accessibility optimizations
        optimizedWidth = optimizeForAccessibility(baseWidth: optimizedWidth, configuration: configuration)

        // Round to nearest reasonable increment for clean layout
        return roundToLayoutIncrement(optimizedWidth)
    }

    func calculateFoldingControlSpace(configuration _: EditorConfiguration) -> CGFloat {
        // Space for folding triangles/indicators
        16.0 // Standard control size + margin
    }

    func calculateAnnotationSpace(configuration _: EditorConfiguration) -> CGFloat {
        // Space for annotation indicators (breakpoints, errors, etc.)
        8.0 // Small margin for indicators
    }

    func calculateDebuggingSpace(configuration _: EditorConfiguration) -> CGFloat {
        // Space for debugging indicators
        4.0 // Minimal space for debugging indicators
    }

    func getCachedCharacterWidth(for font: PlatformFont) -> CGFloat {
        let cacheKey = generateFontCacheKey(for: font)

        if let cached = fontMetricsCache[cacheKey] {
            return cached
        }

        let characterWidth = calculateCharacterWidth(for: font)
        cacheFontMetrics(cacheKey: cacheKey, characterWidth: characterWidth)

        return characterWidth
    }

    func calculateCharacterWidth(for font: PlatformFont) -> CGFloat {
        // Use multiple representative characters to get average width
        let testCharacters = ["0", "1", "9", "W", "M"]
        var totalWidth: CGFloat = 0

        for character in testCharacters {
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let size = character.size(withAttributes: attributes)
            totalWidth += size.width
        }

        return totalWidth / CGFloat(testCharacters.count)
    }

    func roundToLayoutIncrement(_ width: CGFloat) -> CGFloat {
        // Round to nearest 4pt increment for clean layout
        let increment: CGFloat = 4.0
        return (width / increment).rounded() * increment
    }

    // MARK: - Cache Helpers

    func generateFontCacheKey(for font: PlatformFont) -> String {
        "\(font.fontName)_\(font.pointSize)"
    }

    func cacheFontMetrics(cacheKey: String, characterWidth: CGFloat) {
        if fontMetricsCache.count >= maxCacheSize,
           let oldestKey = fontMetricsCache.keys.first {
            // Remove oldest entry
            fontMetricsCache.removeValue(forKey: oldestKey)
        }
        fontMetricsCache[cacheKey] = characterWidth
    }
}

// MARK: - Convenience Extensions

extension GutterSizingService {
    /// Convenience method for calculating standard gutter width
    public func standardWidth(
        for textView: CodeEditorView,
        configuration: EditorConfiguration
    ) -> CGFloat {
        let font = PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize)
        let lineCount = (textView.text ?? "").components(separatedBy: .newlines).count

        let result = calculateOptimalWidth(
            lineCount: lineCount,
            font: font,
            configuration: configuration
        )

        return result.recommendedWidth
    }

    /// Quick check if gutter width needs adjustment
    public func needsWidthAdjustment(
        currentWidth: CGFloat,
        for textView: CodeEditorView,
        configuration: EditorConfiguration
    ) -> Bool {
        let font = PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize)
        let lineCount = (textView.text ?? "").components(separatedBy: .newlines).count

        return shouldUpdateWidth(
            newLineCount: lineCount,
            currentWidth: currentWidth,
            font: font,
            configuration: configuration
        )
    }
}
