import CodeEditorSwiftUI
import CodeEditorTheming
import SwiftUI

/// `ViewModifier` that applies the platform's Liquid Glass surface to its
/// content, layered with a theme-driven tint, role-specific background,
/// and (for `.popover`) the theme's popover shadow.
///
/// Reads `\.codeEditorTheme` from the SwiftUI environment to pick up
/// `Theme.platform.glass` and `Theme.style.chrome.*` colors. Pass a `Role`
/// to indicate which kind of chrome surface this is — the modifier maps
/// roles to backgrounds and tint multipliers per the spec's table.
public struct PlatformGlassSurface: ViewModifier {
    /// The kind of chrome surface — drives background, tint multiplier,
    /// and shadow choice.
    public enum Role: Hashable, Sendable {
        /// Window-top title bar (`Theme.titleBarColor` background, 1.0× tint).
        case titleBar
        /// File-tab strip (`Theme.tabBarColor` background, 0.8× tint).
        case tabBar
        /// Bottom status bar (`Theme.statusBarColor` background, 1.0× tint).
        case statusBar
        /// Side panel / sidebar shell (`Theme.panelColor` background, 1.2× tint).
        case panel
        /// Floating popover, e.g. command palette (`Theme.elevatedColor`
        /// background, 1.2× tint, plus the theme's popover drop shadow).
        case popover
    }

    @Environment(\.codeEditorTheme) private var theme

    /// Surface role; selected by the host at modifier-installation time.
    public let role: Role

    /// Creates a glass-surface modifier for the given role.
    public init(role: Role) {
        self.role = role
    }

    public func body(content: Content) -> some View {
        content
            .background(theme.glassTintColor.opacity(scaledOpacity))
            .background(roleBackground)
            .background(.regularMaterial)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: shadowX,
                y: shadowY
            )
    }

    // MARK: - Role-driven layers

    private var roleBackground: Color {
        switch role {
        case .titleBar:  return theme.titleBarColor
        case .tabBar:    return theme.tabBarColor
        case .statusBar: return theme.statusBarColor
        case .panel:     return theme.panelColor
        case .popover:   return theme.elevatedColor
        }
    }

    private var scaledOpacity: Double {
        let base = theme.glassOpacity
        let multiplier: Double
        switch role {
        case .titleBar, .statusBar: multiplier = 1.0
        case .tabBar:               multiplier = 0.8
        case .panel, .popover:      multiplier = 1.2
        }
        return min(base * multiplier, 1.0)
    }

    private var shadowColor: Color {
        role == .popover ? theme.popoverShadow.color : .clear
    }

    private var shadowRadius: CGFloat {
        role == .popover ? theme.popoverShadow.blur : 0
    }

    private var shadowX: CGFloat {
        role == .popover ? theme.popoverShadow.x : 0
    }

    private var shadowY: CGFloat {
        role == .popover ? theme.popoverShadow.y : 0
    }
}

extension View {
    /// Apply the platform's Liquid Glass surface for the given chrome role.
    ///
    /// The modifier reads the active `Theme` from the environment and
    /// composes background fill, tint, and shadow per role.
    public func platformGlassSurface(_ role: PlatformGlassSurface.Role) -> some View {
        modifier(PlatformGlassSurface(role: role))
    }
}
