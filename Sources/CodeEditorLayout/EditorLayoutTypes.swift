import CoreGraphics
import Foundation

// MARK: - Editor Layout Types
//
// Top-level layout data structures consumed by the carry-set layout
// engine (`ComponentFrameCalculator`, `LayoutCache`, `LayoutOptimizer`,
// `ResponsiveLayoutProvider`) and by the umbrella's `EditorLayoutService`
// facade. Originally declared as nested types inside `EditorLayoutService`
// (umbrella); extracted to break the carry-set → umbrella reference
// chain during §6.2.11. Consumers should refer to them as top-level
// types (`ComponentFrames`, `EdgeInsets`, etc.).

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
