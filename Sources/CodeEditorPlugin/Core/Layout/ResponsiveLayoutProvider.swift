import Foundation

// MARK: - Responsive Layout Provider

/// Provides responsive layout constraints based on screen size
@MainActor
public enum ResponsiveLayoutProvider {
    // MARK: - Responsive Constraints

    /// Creates layout constraints appropriate for the given screen size
    /// - Parameter screenSize: The screen size category
    /// - Returns: Layout constraints optimized for the screen size
    public static func createConstraints(
        for screenSize: ScreenSize
    ) -> EditorLayoutService.LayoutConstraints {
        switch screenSize {
        case .compact:
            return EditorLayoutService.LayoutConstraints(
                minimumGutterWidth: 30,
                maximumGutterWidth: 60,
                minimumTextWidth: 150,
                minimumMinimapWidth: 0, // Disable minimap on compact screens
                maximumMinimapWidth: 0
            )

        case .regular:
            return EditorLayoutService.LayoutConstraints(
                minimumGutterWidth: 40,
                maximumGutterWidth: 100,
                minimumTextWidth: 200,
                minimumMinimapWidth: 60,
                maximumMinimapWidth: 120
            )

        case .large:
            // Use defaults for large screens
            return EditorLayoutService.LayoutConstraints()
        }
    }

    /// Detects the screen size category from available dimensions
    /// - Parameter size: The available size
    /// - Returns: The appropriate screen size category
    public static func detectScreenSize(from size: CGSize) -> ScreenSize {
        let minDimension = min(size.width, size.height)

        if minDimension < 400 {
            return .compact
        } else if minDimension < 800 {
            return .regular
        } else {
            return .large
        }
    }

    /// Adjusts configuration for the given screen size
    /// - Parameters:
    ///   - configuration: The original configuration
    ///   - screenSize: The target screen size
    /// - Returns: Adjusted configuration for the screen size
    public static func adjustConfiguration(
        _ configuration: EditorConfiguration,
        for screenSize: ScreenSize
    ) -> EditorConfiguration {
        var adjusted = configuration

        switch screenSize {
        case .compact:
            // Disable minimap on compact screens
            adjusted.display.showMinimap = false

        case .regular:
            // Keep minimap if enabled, but use smaller width
            break

        case .large:
            // Use full configuration
            break
        }

        return adjusted
    }
}

// MARK: - Screen Size

/// Screen size categories for responsive layout
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
