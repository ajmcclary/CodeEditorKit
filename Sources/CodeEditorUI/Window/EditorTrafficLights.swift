#if canImport(AppKit)
import DesignKitTokens
import CodeEditorSwiftUI
import SwiftUI

/// Optional callbacks for the three traffic-light buttons.
///
/// `.standard` is the decorative form (no callbacks attached). Hosts
/// that have replaced the OS traffic-light buttons with this view —
/// e.g. by hosting the editor in a borderless `NSWindow` or by hiding
/// the standard window buttons themselves — can wire `onClose` to
/// `NSApp.keyWindow?.performClose(nil)`, etc. Embedding this view
/// inside a window that still shows its OS buttons stacks two sets of
/// traffic lights and is not a supported configuration; see
/// `EditorTitleBar` for the hosting requirements.
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
/// sizing. Available on macOS; absent on iOS.
///
/// Each circle is `size`×`size` (default 14pt). Callbacks from
/// `TrafficLightsConfiguration` fire on click; if all three are nil the
/// lights are decorative.
public struct EditorTrafficLights: View {
    /// Standard Tahoe close-button red (`Tokens.Palette.TrafficLight.close`).
    private static let closeColor = Color(tokens: Tokens.Palette.TrafficLight.close)
    /// Standard Tahoe minimize-button yellow (`Tokens.Palette.TrafficLight.minimize`).
    private static let minimizeColor = Color(tokens: Tokens.Palette.TrafficLight.minimize)
    /// Standard Tahoe zoom-button green (`Tokens.Palette.TrafficLight.zoom`).
    private static let zoomColor = Color(tokens: Tokens.Palette.TrafficLight.zoom)

    /// Stroke color for the dot's hairline border (UI-system primitive,
    /// not part of the brand palette).
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
