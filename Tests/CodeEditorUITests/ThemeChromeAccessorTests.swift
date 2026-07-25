@testable import CodeEditorKit
@testable import CodeEditorSwiftUI
@testable import CodeEditorUI
import DesignKitThemes
import DesignKitTokens
import Foundation
import SwiftUI
import Testing

@Suite("Theme chrome + glass SwiftUI accessors")
@MainActor
struct ThemeChromeAccessorTests {
    @Test("chrome accessors map to style.chrome.* underlying tokens")
    func chromeAccessorsMapCorrectly() {
        let theme = Theme.lcarsDark
        #expect(theme.titleBarColor == Color(tokens: theme.style.chrome.titleBarBackground))
        #expect(theme.tabBarColor == Color(tokens: theme.style.chrome.tabBarBackground))
        #expect(theme.statusBarColor == Color(tokens: theme.style.chrome.statusBarBackground))
        #expect(theme.panelColor == Color(tokens: theme.style.chrome.panelBackground))
        #expect(theme.elevatedColor == Color(tokens: theme.style.chrome.elevatedSurfaceBackground))
        #expect(theme.tabActiveColor == Color(tokens: theme.style.chrome.tabActiveBackground))
        #expect(theme.tabInactiveColor == Color(tokens: theme.style.chrome.tabInactiveBackground))
        #expect(theme.toolbarColor == Color(tokens: theme.style.chrome.toolbarBackground))
        #expect(theme.surfaceColor == Color(tokens: theme.style.chrome.surfaceBackground))
        #expect(theme.titleBarInactiveColor == Color(tokens: theme.style.chrome.titleBarInactiveBackground))
        #expect(theme.panelFocusedBorderColor == Color(tokens: theme.style.chrome.panelFocusedBorder))
    }

    @Test("glass accessors map to glass.glass.* underlying tokens")
    func glassAccessorsMapCorrectly() {
        let theme = Theme.lcarsDark
        #expect(theme.glassTintColor == Color(tokens: theme.glass.glass.tint))
        #expect(theme.glassOpacity == theme.glass.glass.opacity)
    }

    @Test("popoverShadow returns the glass.shadows.popover values")
    func popoverShadowMaps() {
        let theme = Theme.lcarsDark
        let shadow = theme.popoverShadow
        let source = theme.glass.shadows.popover
        #expect(shadow.color == Color(tokens: source.color))
        #expect(shadow.blur == CGFloat(source.blur))
        #expect(shadow.x == CGFloat(source.xOffset))
        #expect(shadow.y == CGFloat(source.yOffset))
    }
}
