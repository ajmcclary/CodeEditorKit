import CodeEditorConfiguration
import CodeEditorLayout
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Editor Layout Service

/// Service responsible for complex layout calculations and component positioning
/// Extracts business logic from LayoutCoordinator and ContainerLayoutHelper
///
/// This class serves as a facade that coordinates layout calculations through
/// dedicated components: ComponentFrameCalculator, LayoutOptimizer,
/// ResponsiveLayoutProvider, and LayoutCache. The supporting value types
/// (`ComponentFrames`, `EdgeInsets`, `LayoutOptimizations`, `LayoutConstraints`)
/// live in `CodeEditorLayout` (extracted there during §6.2.11 to break the
/// carry-set → umbrella reference chain).
@MainActor
public final class EditorLayoutService {
    // MARK: - Properties

    private let gutterSizingService: GutterSizingService
    private let layoutCache: LayoutCache

    // MARK: - Initialization

    /// Creates a new editor layout service.
    ///
    /// - Parameter gutterSizingService: Service for calculating gutter dimensions
    public init(gutterSizingService: GutterSizingService) {
        self.gutterSizingService = gutterSizingService
        self.layoutCache = LayoutCache()
    }

    // MARK: - Public Interface

    /// Calculates component frames for the given container bounds and configuration
    public func calculateComponentFrames(
        containerBounds: CGRect,
        configuration: EditorConfiguration,
        constraints: LayoutConstraints = LayoutConstraints(),
        lineCount: Int = 1_000
    ) -> ComponentFrames {
        let cacheKey = LayoutCache.generateKey(
            bounds: containerBounds,
            configuration: configuration,
            constraints: constraints,
            lineCount: lineCount
        )

        if let cached = layoutCache.get(cacheKey) {
            return cached
        }

        let frames = performLayoutCalculation(
            containerBounds: containerBounds,
            configuration: configuration,
            constraints: constraints,
            lineCount: lineCount
        )

        layoutCache.store(frames, forKey: cacheKey)

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
        let textPadding = ComponentFrameCalculator.calculateTextPadding(configuration: configuration)
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
        LayoutOptimizer.recommendOptimizations(for: configuration, availableSpace: availableSpace)
    }

    /// Calculates optimal Z-positioning for components
    public func calculateZPositions(configuration _: EditorConfiguration) -> [String: CGFloat] {
        LayoutOptimizer.calculateZPositions()
    }

    /// Determines if layout should animate based on change type
    public func shouldAnimateLayoutChange(
        from oldConfiguration: EditorConfiguration,
        to newConfiguration: EditorConfiguration
    ) -> Bool {
        LayoutOptimizer.shouldAnimateLayoutChange(from: oldConfiguration, to: newConfiguration)
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
            adjustedConfiguration.display.isMinimapVisible = false
            adjustedConfiguration.display.isLineNumbersEnabled = false

        case .standard:
            // Use configuration as-is
            break

        case .presentation:
            adjustedConfiguration.display.fontSize = max(configuration.display.fontSize, 18)
            adjustedConfiguration.display.isMinimapVisible = true

        case .debugging:
            adjustedConfiguration.display.isLineNumbersEnabled = true
            adjustedConfiguration.display.areAnnotationsEnabled = true
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
        let constraints = ResponsiveLayoutProvider.createConstraints(for: screenSize)

        return calculateComponentFrames(
            containerBounds: containerBounds,
            configuration: configuration,
            constraints: constraints
        )
    }

    // MARK: - Cache Management

    /// Clears the layout cache
    public func clearCache() {
        layoutCache.clear()
    }

    /// Invalidates cache for specific configuration
    public func invalidateCache(for configuration: EditorConfiguration) {
        layoutCache.invalidate(for: configuration)
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

// MARK: - Private Implementation

extension EditorLayoutService {
    func performLayoutCalculation(
        containerBounds: CGRect,
        configuration: EditorConfiguration,
        constraints: LayoutConstraints,
        lineCount: Int
    ) -> ComponentFrames {
        let adjustedBounds = ComponentFrameCalculator.applyConstraints(containerBounds, constraints: constraints)

        // Calculate gutter frame
        let gutterFrame = ComponentFrameCalculator.calculateGutterFrame(
            containerBounds: adjustedBounds,
            configuration: configuration,
            constraints: constraints,
            lineCount: lineCount,
            gutterSizingService: gutterSizingService
        )

        // Calculate minimap frame
        let minimapFrame = ComponentFrameCalculator.calculateMinimapFrame(
            containerBounds: adjustedBounds,
            configuration: configuration,
            constraints: constraints,
            gutterFrame: gutterFrame
        )

        // Calculate text view frame
        let textViewFrame = ComponentFrameCalculator.calculateTextViewFrame(
            containerBounds: adjustedBounds,
            gutterFrame: gutterFrame,
            minimapFrame: minimapFrame
        )

        // Calculate scroll view frame (encompasses text view)
        let scrollViewFrame = ComponentFrameCalculator.calculateScrollViewFrame(textViewFrame: textViewFrame)

        return ComponentFrames(
            containerFrame: adjustedBounds,
            textViewFrame: textViewFrame,
            gutterFrame: gutterFrame,
            minimapFrame: minimapFrame,
            scrollViewFrame: scrollViewFrame
        )
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
