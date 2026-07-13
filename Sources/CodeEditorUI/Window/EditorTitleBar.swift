#if canImport(AppKit)
import CodeEditorSwiftUI
import CodeEditorView
import DesignKitThemes
import DesignKitTokens
import SwiftUI

/// Tahoe-styled title bar with traffic lights, centered title, and a
/// trailing slot for toolbar pills.
///
/// Available on macOS. The title bar is an embeddable SwiftUI view —
/// it draws its own painted traffic lights and does not interact with
/// the host `NSWindow`'s real traffic-light buttons.
///
/// **Hosting requirement.** Combining this view with a standard
/// `NSWindow` produces a visible "app inside an app": `.windowStyle(
/// .hiddenTitleBar)` only hides the title-bar background, leaving the
/// OS traffic lights rendered in the window's top-left corner. Hosts
/// that embed this view are responsible for hiding the real buttons
/// (e.g. `window.standardWindowButton(.closeButton)?.isHidden = true`
/// for close/minimize/zoom) or for hosting the editor inside a window
/// that has none — a borderless `NSWindow`, an `NSPanel`, or an
/// in-process preview surface. `CodeEditorDemo` (the extracted demo app
/// at `apps/CodeEditorDemo` in the superproject) deliberately uses
/// the native NSWindow chrome instead of this view.
public struct EditorTitleBar<Trailing: View>: View {
    @Environment(\.designTheme) private var theme
    @Environment(\.editorState) private var editorState

    private let titleOverride: String?
    private let trafficLights: TrafficLightsConfiguration
    private let trailing: () -> Trailing

    /// Creates a title bar.
    /// - Parameters:
    ///   - title: shown in the centered title position. When nil, the bar
    ///     reads `\.editorState`'s `documentName`.
    ///   - trafficLights: callback configuration for the three buttons.
    ///   - trailing: `@ViewBuilder` slot for trailing toolbar content.
    public init(
        title: String? = nil,
        trafficLights: TrafficLightsConfiguration = .standard,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.titleOverride = title
        self.trafficLights = trafficLights
        self.trailing = trailing
    }

    public var body: some View {
        ZStack {
            HStack(spacing: 0) {
                EditorTrafficLights(configuration: trafficLights)
                    .padding(.leading, 14)
                Spacer()
                trailing()
                    .padding(.trailing, 14)
            }

            Text(resolvedTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(tokens: theme.style.text.base))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 120)
                .allowsHitTesting(false)
        }
        .frame(height: 38)
        .platformGlassSurface(.titleBar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(tokens: theme.style.borders.base).opacity(0.5))
                .frame(height: 0.5)
        }
    }

    private var resolvedTitle: String {
        if let titleOverride { return titleOverride }
        return editorState.documentName
    }
}
#endif
