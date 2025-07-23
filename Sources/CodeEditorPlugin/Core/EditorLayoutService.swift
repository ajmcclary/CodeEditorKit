import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Editor Layout Service

/// Service responsible for complex layout calculations and component positioning
/// Extracts business logic from LayoutCoordinator and ContainerLayoutHelper
@MainActor
public final class EditorLayoutService {
    // MARK: - Types

    /// Frame information for all editor components.
    ///
    /// `ComponentFrames` contains the calculated frame rectangles for all
    /// major components of the editor layout, enabling proper positioning
    /// and sizing of UI elements.
    public struct ComponentFrames {
        /// The overall container frame for the entire editor
        public let containerFrame: CGRect
        /// The frame for the main text editing area
        public let textViewFrame: CGRect
        /// The frame for the line number gutter
        public let gutterFrame: CGRect
        /// The frame for the minimap (if enabled)
        public let minimapFrame: CGRect
        /// The frame for the scroll view containing the text
        public let scrollViewFrame: CGRect

        /// Creates a new component frames structure.
        ///
        /// - Parameters:
        ///   - containerFrame: The overall container frame
        ///   - textViewFrame: The main text editing area frame
        ///   - gutterFrame: The line number gutter frame
        ///   - minimapFrame: The minimap frame
        ///   - scrollViewFrame: The scroll view frame
        public init(
            containerFrame: CGRect,
            textViewFrame: CGRect,
            gutterFrame: CGRect,
            minimapFrame: CGRect,
            scrollViewFrame: CGRect
        ) {
            self.containerFrame = containerFrame
            self.textViewFrame = textViewFrame
            self.gutterFrame = gutterFrame
            self.minimapFrame = minimapFrame
            self.scrollViewFrame = scrollViewFrame
        }
    }

    /// Edge insets for layout calculations.
    ///
    /// `EdgeInsets` represents spacing from the edges of a container,
    /// similar to `UIEdgeInsets` but with cross-platform compatibility.
    public struct EdgeInsets: Sendable {
        /// Top edge inset
        public let top: CGFloat
        /// Left edge inset
        public let left: CGFloat
        /// Bottom edge inset
        public let bottom: CGFloat
        /// Right edge inset
        public let right: CGFloat

        /// Creates new edge insets.
        ///
        /// - Parameters:
        ///   - top: Top edge inset
        ///   - left: Left edge inset
        ///   - bottom: Bottom edge inset
        ///   - right: Right edge inset
        public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
            self.top = top
            self.left = left
            self.bottom = bottom
            self.right = right
        }

        /// Zero insets (no spacing)
        public static let zero = Self(top: 0, left: 0, bottom: 0, right: 0)
    }

    /// Layout optimization recommendations.
    ///
    /// `LayoutOptimizations` provides guidance on which layout optimizations
    /// should be applied based on available space and configuration.
    public struct LayoutOptimizations {
        /// Whether to optimize minimap rendering
        public let useMinimapOptimization: Bool
        /// Whether to optimize gutter rendering
        public let useGutterOptimization: Bool
        /// Whether to optimize scroll performance
        public let useScrollOptimization: Bool
        /// Recommended animation duration for layout changes
        public let recommendedAnimationDuration: TimeInterval

        /// Creates new layout optimizations.
        ///
        /// - Parameters:
        ///   - useMinimapOptimization: Whether to optimize minimap
        ///   - useGutterOptimization: Whether to optimize gutter
        ///   - useScrollOptimization: Whether to optimize scrolling
        ///   - recommendedAnimationDuration: Animation duration for changes
        public init(
            useMinimapOptimization: Bool,
            useGutterOptimization: Bool,
            useScrollOptimization: Bool,
            recommendedAnimationDuration: TimeInterval
        ) {
            self.useMinimapOptimization = useMinimapOptimization
            self.useGutterOptimization = useGutterOptimization
            self.useScrollOptimization = useScrollOptimization
            self.recommendedAnimationDuration = recommendedAnimationDuration
        }
    }

    /// Constraints for layout calculations.
    ///
    /// `LayoutConstraints` defines the minimum and maximum dimensions
    /// for various editor components, ensuring proper layout bounds.
    public struct LayoutConstraints {
        /// Minimum allowed gutter width
        public let minimumGutterWidth: CGFloat
        /// Maximum allowed gutter width
        public let maximumGutterWidth: CGFloat
        /// Minimum required text area width
        public let minimumTextWidth: CGFloat
        /// Minimum minimap width when enabled
        public let minimumMinimapWidth: CGFloat
        /// Maximum minimap width
        public let maximumMinimapWidth: CGFloat
        /// Safe area insets to respect
        public let safeAreaInsets: EdgeInsets

        /// Creates new layout constraints.
        ///
        /// - Parameters:
        ///   - minimumGutterWidth: Minimum gutter width (default: 40.0)
        ///   - maximumGutterWidth: Maximum gutter width (default: 200.0)
        ///   - minimumTextWidth: Minimum text area width (default: 200.0)
        ///   - minimumMinimapWidth: Minimum minimap width (default: 80.0)
        ///   - maximumMinimapWidth: Maximum minimap width (default: 150.0)
        ///   - safeAreaInsets: Safe area insets (default: .zero)
        public init(
            minimumGutterWidth: CGFloat = 40.0,
            maximumGutterWidth: CGFloat = 200.0,
            minimumTextWidth: CGFloat = 200.0,
            minimumMinimapWidth: CGFloat = 80.0,
            maximumMinimapWidth: CGFloat = 150.0,
            safeAreaInsets: EdgeInsets = .zero
        ) {
            self.minimumGutterWidth = minimumGutterWidth
            self.maximumGutterWidth = maximumGutterWidth
            self.minimumTextWidth = minimumTextWidth
            self.minimumMinimapWidth = minimumMinimapWidth
            self.maximumMinimapWidth = maximumMinimapWidth
            self.safeAreaInsets = safeAreaInsets
        }
    }

    // MARK: - Properties

    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "EditorLayoutService")
    private let gutterSizingService: GutterSizingService

    // Layout constants
    private let minimapWidthRatio: CGFloat = 0.15 // 15% of container width
    private let gutterWidthRatio: CGFloat = 0.08   // 8% of container width
    private let animationDuration: TimeInterval = 0.25

    // Cache for layout calculations
    private var layoutCache: [String: ComponentFrames] = [:]
    private let maxCacheSize = 10

    // MARK: - Initialization

    /// Creates a new editor layout service.
    ///
    /// - Parameter gutterSizingService: Service for calculating gutter dimensions
    public init(gutterSizingService: GutterSizingService) {
        self.gutterSizingService = gutterSizingService
    }

    // MARK: - Public Interface

    /// Calculates component frames for the given container bounds and configuration
    public func calculateComponentFrames(
        containerBounds: CGRect,
        configuration: EditorConfiguration,
        constraints: LayoutConstraints = LayoutConstraints(),
        lineCount: Int = 1_000
    ) -> ComponentFrames {
        let cacheKey = generateCacheKey(
            bounds: containerBounds,
            configuration: configuration,
            constraints: constraints,
            lineCount: lineCount
        )

        if let cached = layoutCache[cacheKey] {
            return cached
        }

        let frames = performLayoutCalculation(
            containerBounds: containerBounds,
            configuration: configuration,
            constraints: constraints,
            lineCount: lineCount
        )

        // Cache the result
        cacheLayout(cacheKey: cacheKey, frames: frames)

        return frames
    }

    /// Calculates text container insets based on configuration and component visibility
    public func calculateTextContainerInsets(
        configuration: EditorConfiguration,
        gutterVisible: Bool,
        gutterWidth: CGFloat = 0,
        safeAreaInsets: EdgeInsets = .zero
    ) -> EdgeInsets {
        var insets = EdgeInsets(
            top: safeAreaInsets.top,
            left: safeAreaInsets.left,
            bottom: safeAreaInsets.bottom,
            right: safeAreaInsets.right
        )

        // Add gutter width to left inset if gutter is visible
        if gutterVisible {
            insets = EdgeInsets(
                top: insets.top,
                left: insets.left + gutterWidth,
                bottom: insets.bottom,
                right: insets.right
            )
        }

        // Add standard text padding
        let textPadding = calculateTextPadding(configuration: configuration)
        insets = EdgeInsets(
            top: insets.top + textPadding.top,
            left: insets.left + textPadding.left,
            bottom: insets.bottom + textPadding.bottom,
            right: insets.right + textPadding.right
        )

        return insets
    }

    /// Optimizes layout based on configuration and available space
    public func optimizeLayoutForConfiguration(
        _ configuration: EditorConfiguration,
        availableSpace: CGSize
    ) -> LayoutOptimizations {
        let hasLimitedWidth = availableSpace.width < 600
        let hasLimitedHeight = availableSpace.height < 400

        return LayoutOptimizations(
            useMinimapOptimization: configuration.display.showMinimap && !hasLimitedWidth,
            useGutterOptimization: configuration.display.isLineNumbersEnabled,
            useScrollOptimization: !hasLimitedHeight,
            recommendedAnimationDuration: calculateOptimalAnimationDuration(for: configuration)
        )
    }

    /// Calculates optimal Z-positioning for components
    public func calculateZPositions(configuration _: EditorConfiguration) -> [String: CGFloat] {
        var zPositions: [String: CGFloat] = [:]

        // Base layer
        zPositions["textView"] = 0

        // UI overlays
        zPositions["gutter"] = 10
        zPositions["minimap"] = 15

        // Interactive elements
        zPositions["scrollbar"] = 20
        zPositions["searchOverlay"] = 25

        // Temporary overlays
        zPositions["completionPopup"] = 100
        zPositions["tooltip"] = 150

        return zPositions
    }

    /// Determines if layout should animate based on change type
    public func shouldAnimateLayoutChange(
        from oldConfiguration: EditorConfiguration,
        to newConfiguration: EditorConfiguration
    ) -> Bool {
        // Don't animate if fundamental display properties changed
        if oldConfiguration.display.isLineNumbersEnabled != newConfiguration.display.isLineNumbersEnabled ||
           oldConfiguration.display.showMinimap != newConfiguration.display.showMinimap {
            return false
        }

        // Animate for minor adjustments
        return true
    }

    /// Calculates layout for specific display modes
    public func calculateLayoutForDisplayMode(
        _ mode: DisplayMode,
        containerBounds: CGRect,
        configuration: EditorConfiguration
    ) -> ComponentFrames {
        var adjustedConfiguration = configuration

        switch mode {
        case .minimal:
            adjustedConfiguration.display.showMinimap = false
            adjustedConfiguration.display.isLineNumbersEnabled = false

        case .standard:
            // Use configuration as-is
            break

        case .presentation:
            adjustedConfiguration.display.fontSize = max(configuration.display.fontSize, 18)
            adjustedConfiguration.display.showMinimap = true

        case .debugging:
            adjustedConfiguration.display.isLineNumbersEnabled = true
            adjustedConfiguration.display.enableAnnotations = true
        }

        return calculateComponentFrames(
            containerBounds: containerBounds,
            configuration: adjustedConfiguration
        )
    }

    /// Updates layout for responsive design
    public func calculateResponsiveLayout(
        containerBounds: CGRect,
        configuration: EditorConfiguration,
        screenSize: ScreenSize
    ) -> ComponentFrames {
        let constraints = createResponsiveConstraints(for: screenSize)

        return calculateComponentFrames(
            containerBounds: containerBounds,
            configuration: configuration,
            constraints: constraints
        )
    }

    // MARK: - Cache Management

    /// Clears the layout cache
    public func clearCache() {
        layoutCache.removeAll()
        logger.debug("Layout cache cleared")
    }

    /// Invalidates cache for specific configuration
    public func invalidateCache(for configuration: EditorConfiguration) {
        let configHash = String(configuration.hashValue)
        let keysToRemove = layoutCache.keys.filter { $0.contains(configHash) }
        keysToRemove.forEach { layoutCache.removeValue(forKey: $0) }
        logger.debug("Layout cache invalidated for configuration")
    }
}

// MARK: - Supporting Types

/// Display modes for the editor.
///
/// `DisplayMode` defines different presentation modes that affect
/// how the editor components are laid out and which features are visible.
public enum DisplayMode {
    /// Minimal interface with essential features only
    case minimal
    /// Standard interface with full features
    case standard
    /// Presentation mode optimized for larger displays
    case presentation
    /// Debugging mode with additional developer tools
    case debugging
}

/// Screen size categories for responsive layout.
///
/// `ScreenSize` categorizes different screen sizes to enable
/// responsive layout adjustments across Apple platforms.
public enum ScreenSize {
    /// Compact screens (iPhone)
    case compact
    /// Regular screens (iPad)
    case regular
    /// Large screens (Mac)
    case large
}

// MARK: - Private Implementation

extension EditorLayoutService {
    func performLayoutCalculation(
        containerBounds: CGRect,
        configuration: EditorConfiguration,
        constraints: LayoutConstraints,
        lineCount: Int
    ) -> ComponentFrames {
        let adjustedBounds = applyConstraints(containerBounds, constraints: constraints)

        // Calculate gutter frame
        let gutterFrame = calculateGutterFrame(
            containerBounds: adjustedBounds,
            configuration: configuration,
            constraints: constraints,
            lineCount: lineCount
        )

        // Calculate minimap frame
        let minimapFrame = calculateMinimapFrame(
            containerBounds: adjustedBounds,
            configuration: configuration,
            constraints: constraints,
            gutterFrame: gutterFrame
        )

        // Calculate text view frame
        let textViewFrame = calculateTextViewFrame(
            containerBounds: adjustedBounds,
            gutterFrame: gutterFrame,
            minimapFrame: minimapFrame,
            configuration: configuration
        )

        // Calculate scroll view frame (encompasses text view)
        let scrollViewFrame = calculateScrollViewFrame(
            textViewFrame: textViewFrame,
            configuration: configuration
        )

        return ComponentFrames(
            containerFrame: adjustedBounds,
            textViewFrame: textViewFrame,
            gutterFrame: gutterFrame,
            minimapFrame: minimapFrame,
            scrollViewFrame: scrollViewFrame
        )
    }

    func calculateGutterFrame(
        containerBounds: CGRect,
        configuration: EditorConfiguration,
        constraints: LayoutConstraints,
        lineCount: Int
    ) -> CGRect {
        guard configuration.display.isLineNumbersEnabled else {
            return .zero
        }

        let font = PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize)
        let sizingResult = gutterSizingService.calculateOptimalWidth(
            lineCount: lineCount,
            font: font,
            configuration: configuration
        )

        let width = max(
            constraints.minimumGutterWidth,
            min(constraints.maximumGutterWidth, sizingResult.recommendedWidth)
        )

        return CGRect(
            x: containerBounds.minX,
            y: containerBounds.minY,
            width: width,
            height: containerBounds.height
        )
    }

    func calculateMinimapFrame(
        containerBounds: CGRect,
        configuration: EditorConfiguration,
        constraints: LayoutConstraints,
        gutterFrame: CGRect
    ) -> CGRect {
        guard configuration.display.showMinimap else {
            return .zero
        }

        let availableWidth = containerBounds.width - gutterFrame.width
        let proposedWidth = availableWidth * minimapWidthRatio

        let width = max(
            constraints.minimumMinimapWidth,
            min(constraints.maximumMinimapWidth, proposedWidth)
        )

        return CGRect(
            x: containerBounds.maxX - width,
            y: containerBounds.minY,
            width: width,
            height: containerBounds.height
        )
    }

    func calculateTextViewFrame(
        containerBounds: CGRect,
        gutterFrame: CGRect,
        minimapFrame: CGRect,
        configuration _: EditorConfiguration
    ) -> CGRect {
        let leftMargin = gutterFrame.width
        let rightMargin = minimapFrame.width

        let x = containerBounds.minX + leftMargin
        let width = containerBounds.width - leftMargin - rightMargin

        return CGRect(
            x: x,
            y: containerBounds.minY,
            width: max(200, width), // Ensure minimum text width
            height: containerBounds.height
        )
    }

    func calculateScrollViewFrame(
        textViewFrame: CGRect,
        configuration _: EditorConfiguration
    ) -> CGRect {
        // Scroll view encompasses the text view
        textViewFrame
    }

    func calculateTextPadding(configuration: EditorConfiguration) -> EdgeInsets {
        let basePadding: CGFloat = 8.0
        let scaleFactor = configuration.display.fontSize / 14.0 // Scale with font size

        let adjustedPadding = basePadding * scaleFactor

        return EdgeInsets(
            top: adjustedPadding,
            left: adjustedPadding,
            bottom: adjustedPadding,
            right: adjustedPadding
        )
    }

    func calculateOptimalAnimationDuration(for _: EditorConfiguration) -> TimeInterval {
        // Faster animations for better perceived performance
        animationDuration * 0.8
    }

    func applyConstraints(_ bounds: CGRect, constraints: LayoutConstraints) -> CGRect {
        CGRect(
            x: bounds.minX + constraints.safeAreaInsets.left,
            y: bounds.minY + constraints.safeAreaInsets.top,
            width: bounds.width - constraints.safeAreaInsets.left - constraints.safeAreaInsets.right,
            height: bounds.height - constraints.safeAreaInsets.top - constraints.safeAreaInsets.bottom
        )
    }

    func createResponsiveConstraints(for screenSize: ScreenSize) -> LayoutConstraints {
        switch screenSize {
        case .compact:
            return LayoutConstraints(
                minimumGutterWidth: 30,
                maximumGutterWidth: 60,
                minimumTextWidth: 150,
                minimumMinimapWidth: 0, // Disable minimap on compact screens
                maximumMinimapWidth: 0
            )

        case .regular:
            return LayoutConstraints(
                minimumGutterWidth: 40,
                maximumGutterWidth: 100,
                minimumTextWidth: 200,
                minimumMinimapWidth: 60,
                maximumMinimapWidth: 120
            )

        case .large:
            return LayoutConstraints() // Use defaults
        }
    }

    // MARK: - Cache Helpers

    func generateCacheKey(
        bounds: CGRect,
        configuration: EditorConfiguration,
        constraints: LayoutConstraints,
        lineCount: Int
    ) -> String {
        let boundsKey = "\(Int(bounds.width))x\(Int(bounds.height))"
        let configHash = String(configuration.hashValue)
        let constraintsKey = "\(Int(constraints.minimumGutterWidth))_\(Int(constraints.maximumGutterWidth))"

        return "\(boundsKey)_\(configHash)_\(constraintsKey)_\(lineCount)"
    }

    func cacheLayout(cacheKey: String, frames: ComponentFrames) {
        if layoutCache.count >= maxCacheSize,
           let oldestKey = layoutCache.keys.first {
            // Remove oldest entry
            layoutCache.removeValue(forKey: oldestKey)
        }
        layoutCache[cacheKey] = frames
    }
}

// MARK: - Convenience Extensions

extension EditorLayoutService {
    /// Quick layout calculation for standard use cases
    public func standardLayout(
        containerBounds: CGRect,
        configuration: EditorConfiguration,
        textView: CodeEditorView
    ) -> ComponentFrames {
        let lineCount = (textView.text ?? "").components(separatedBy: .newlines).count
        return calculateComponentFrames(
            containerBounds: containerBounds,
            configuration: configuration,
            lineCount: lineCount
        )
    }

    /// Determines if layout needs updating
    public func layoutNeedsUpdate(
        currentFrames: ComponentFrames,
        newBounds: CGRect,
        configuration: EditorConfiguration
    ) -> Bool {
        let newFrames = calculateComponentFrames(
            containerBounds: newBounds,
            configuration: configuration
        )

        // Check if any significant frame changed
        let threshold: CGFloat = 1.0

        return !newFrames.containerFrame.equalTo(currentFrames.containerFrame, threshold: threshold) ||
               !newFrames.textViewFrame.equalTo(currentFrames.textViewFrame, threshold: threshold) ||
               !newFrames.gutterFrame.equalTo(currentFrames.gutterFrame, threshold: threshold) ||
               !newFrames.minimapFrame.equalTo(currentFrames.minimapFrame, threshold: threshold)
    }
}

// MARK: - CGRect Extensions

extension CGRect {
    func equalTo(_ other: CGRect, threshold: CGFloat) -> Bool {
        abs(origin.x - other.origin.x) < threshold &&
               abs(origin.y - other.origin.y) < threshold &&
               abs(size.width - other.size.width) < threshold &&
               abs(size.height - other.size.height) < threshold
    }
}
