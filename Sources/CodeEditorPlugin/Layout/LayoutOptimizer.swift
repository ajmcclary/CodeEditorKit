import Foundation

// MARK: - Layout Optimizer

/// Provides layout optimization recommendations based on configuration and available space
@MainActor
public enum LayoutOptimizer {
    // MARK: - Constants

    /// Width threshold for limited horizontal space
    public static let limitedWidthThreshold: CGFloat = 600

    /// Height threshold for limited vertical space
    public static let limitedHeightThreshold: CGFloat = 400

    /// Base animation duration for layout changes
    public static let baseAnimationDuration: TimeInterval = 0.25

    // MARK: - Optimization Recommendations

    /// Recommends layout optimizations based on configuration and available space
    /// - Parameters:
    ///   - configuration: The editor configuration
    ///   - availableSpace: The available space for the editor
    /// - Returns: Layout optimization recommendations
    public static func recommendOptimizations(
        for configuration: EditorConfiguration,
        availableSpace: CGSize
    ) -> EditorLayoutService.LayoutOptimizations {
        let hasLimitedWidth = availableSpace.width < limitedWidthThreshold
        let hasLimitedHeight = availableSpace.height < limitedHeightThreshold

        return EditorLayoutService.LayoutOptimizations(
            useMinimapOptimization: configuration.display.isMinimapVisible && !hasLimitedWidth,
            useGutterOptimization: configuration.display.isLineNumbersEnabled,
            useScrollOptimization: !hasLimitedHeight,
            recommendedAnimationDuration: calculateOptimalAnimationDuration(for: configuration)
        )
    }

    /// Calculates optimal animation duration based on configuration
    /// - Parameter configuration: The editor configuration
    /// - Returns: Optimal animation duration
    public static func calculateOptimalAnimationDuration(
        for _: EditorConfiguration
    ) -> TimeInterval {
        // Faster animations for better perceived performance
        baseAnimationDuration * 0.8
    }

    /// Determines if layout should animate based on configuration changes
    /// - Parameters:
    ///   - oldConfiguration: The previous configuration
    ///   - newConfiguration: The new configuration
    /// - Returns: Whether the layout change should be animated
    public static func shouldAnimateLayoutChange(
        from oldConfiguration: EditorConfiguration,
        to newConfiguration: EditorConfiguration
    ) -> Bool {
        // Don't animate if fundamental display properties changed
        if oldConfiguration.display.isLineNumbersEnabled != newConfiguration.display.isLineNumbersEnabled ||
           oldConfiguration.display.isMinimapVisible != newConfiguration.display.isMinimapVisible {
            return false
        }

        // Animate for minor adjustments
        return true
    }

    /// Calculates optimal Z-positioning for editor components
    /// - Returns: Dictionary mapping component names to Z positions
    public static func calculateZPositions() -> [String: CGFloat] {
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
}
