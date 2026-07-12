import CodeEditorDesignTokens
import CodeEditorSwiftUI
import CodeEditorTheming
import SwiftUI

/// SwiftUI `Color` accessors for `Theme.style.chrome.*` token values.
///
/// These helpers exist so chrome views can read theme values fluently:
/// `theme.titleBarColor` instead of
/// `Color(tokens: theme.style.chrome.titleBarBackground)`.
/// Each accessor is a simple bridge — no caching, no derivation.
extension Theme {
    /// Title bar background for the active window.
    public var titleBarColor: Color {
        Color(tokens: style.chrome.titleBarBackground)
    }

    /// Title bar background for an inactive window.
    public var titleBarInactiveColor: Color {
        Color(tokens: style.chrome.titleBarInactiveBackground)
    }

    /// Tab strip background.
    public var tabBarColor: Color {
        Color(tokens: style.chrome.tabBarBackground)
    }

    /// Active tab background.
    public var tabActiveColor: Color {
        Color(tokens: style.chrome.tabActiveBackground)
    }

    /// Inactive tab background.
    public var tabInactiveColor: Color {
        Color(tokens: style.chrome.tabInactiveBackground)
    }

    /// Status bar background.
    public var statusBarColor: Color {
        Color(tokens: style.chrome.statusBarBackground)
    }

    /// Toolbar background.
    public var toolbarColor: Color {
        Color(tokens: style.chrome.toolbarBackground)
    }

    /// Generic surface background.
    public var surfaceColor: Color {
        Color(tokens: style.chrome.surfaceBackground)
    }

    /// Elevated surface background (popovers, sheets).
    public var elevatedColor: Color {
        Color(tokens: style.chrome.elevatedSurfaceBackground)
    }

    /// Side panel background.
    public var panelColor: Color {
        Color(tokens: style.chrome.panelBackground)
    }

    /// Border color when a panel has focus.
    public var panelFocusedBorderColor: Color {
        Color(tokens: style.chrome.panelFocusedBorder)
    }
}
