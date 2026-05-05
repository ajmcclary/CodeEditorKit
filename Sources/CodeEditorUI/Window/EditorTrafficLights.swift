#if canImport(AppKit)
import CodeEditorDesignTokens
import SwiftUI

/// Optional callbacks for the three traffic-light buttons.
///
/// `.standard` is the decorative form (no callbacks attached). Hosts
/// embedding `EditorTrafficLights` inside a real `NSWindow` can wire
/// `onClose` to `NSApp.keyWindow?.close()`, etc.
public struct TrafficLightsConfiguration: Sendable {
    /// Invoked when the user clicks the close button.
    public var onClose: (@Sendable () -> Void)?
    /// Invoked when the user clicks the minimize button.
    public var onMinimize: (@Sendable () -> Void)?
    /// Invoked when the user clicks the zoom button.
    public var onZoom: (@Sendable () -> Void)?

    /// Decorative form — no callbacks. The lights render but don't act.
    public static let standard: Self = .init()

    /// Memberwise builder.
    public init(
        onClose: (@Sendable () -> Void)? = nil,
        onMinimize: (@Sendable () -> Void)? = nil,
        onZoom: (@Sendable () -> Void)? = nil
    ) {
        self.onClose = onClose
        self.onMinimize = onMinimize
        self.onZoom = onZoom
    }
}

/// Custom-painted SwiftUI traffic lights matching macOS Tahoe colors and
/// sizing. Available on macOS and Mac Catalyst; absent on iOS.
///
/// Each circle is `size`×`size` (default 14pt). Callbacks from
/// `TrafficLightsConfiguration` fire on click; if all three are nil the
/// lights are decorative.
public struct EditorTrafficLights: View {
    /// Standard Tahoe close-button red.
    private static let closeColor = Color(red: 1.0, green: 0.365, blue: 0.341)
    /// Standard Tahoe minimize-button yellow.
    private static let minimizeColor = Color(red: 0.996, green: 0.737, blue: 0.180)
    /// Standard Tahoe zoom-button green.
    private static let zoomColor = Color(red: 0.157, green: 0.784, blue: 0.251)

    /// Stroke color for the dot's hairline border.
    private static let strokeColor = Color.black.opacity(0.18)

    /// Configuration carrying optional click callbacks.
    public let configuration: TrafficLightsConfiguration
    /// Diameter of each light in points.
    public let size: CGFloat

    /// Creates a traffic-lights cluster.
    /// - Parameters:
    ///   - configuration: optional callbacks; defaults to decorative.
    ///   - size: diameter in points; defaults to 14.
    public init(
        configuration: TrafficLightsConfiguration = .standard,
        size: CGFloat = 14
    ) {
        self.configuration = configuration
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 9) {
            light(color: Self.closeColor, action: configuration.onClose)
            light(color: Self.minimizeColor, action: configuration.onMinimize)
            light(color: Self.zoomColor, action: configuration.onZoom)
        }
    }

    @ViewBuilder
    private func light(color: Color, action: (@Sendable () -> Void)?) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Self.strokeColor, lineWidth: 0.5))
            .accessibilityHidden(action == nil)
            .accessibilityAddTraits(.isButton)
            .onTapGesture { action?() }
    }
}
#endif
