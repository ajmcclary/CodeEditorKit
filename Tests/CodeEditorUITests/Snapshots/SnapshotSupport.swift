@testable import CodeEditorSwiftUI
import CodeEditorTheming
#if canImport(AppKit)
import AppKit
import CodeEditorDesignTokens
@testable import CodeEditorPlugin
@testable import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

/// Shared snapshot-test helpers. Wraps a SwiftUI `View` in `NSHostingView`
/// at a fixed size so `assertSnapshot(of:as: .image)` can render it
/// deterministically on macOS CI runners.
@MainActor
enum SnapshotSupport {
    /// Default snapshot size for chrome rows (title bar, status bar, tab strip).
    static let rowSize = CGSize(width: 800, height: 60)
    /// Default snapshot size for breadcrumbs.
    static let breadcrumbSize = CGSize(width: 800, height: 28)
    /// Default snapshot size for vertical chrome (sidebar shell).
    static let panelSize = CGSize(width: 240, height: 480)
    /// Default snapshot size for popovers (command palette).
    static let popoverSize = CGSize(width: 480, height: 320)
    /// Default snapshot size for traffic lights only.
    static let trafficLightsSize = CGSize(width: 80, height: 24)
    /// Default snapshot size for glass surface samples.
    static let glassSize = CGSize(width: 400, height: 80)

    /// Themes used for parity snapshots.
    static let darkTheme: Theme = .lcarsDark
    static let lightTheme: Theme = pickLightTheme()

    private static func pickLightTheme() -> Theme {
        let family = ThemeFamily.bundled("zed-trek")
        if let light = family?.themes.first(where: { $0.name == "LCARS Light" }) {
            return light
        }
        if let firstLight = family?.themes.first(where: { $0.appearance == .light }) {
            return firstLight
        }
        return Theme.fallback(appearance: .light)
    }

    /// Wrap a SwiftUI view in an NSHostingView at the given size, ready
    /// for `assertSnapshot(of:as: .image(size:))`.
    static func host<V: View>(_ view: V, size: CGSize) -> NSView {
        let hostingView = NSHostingView(
            rootView: view.frame(width: size.width, height: size.height)
        )
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        return hostingView
    }

    /// Apply a theme + standard background to a view for snapshotting.
    @ViewBuilder
    static func framed<V: View>(_ view: V, theme: Theme) -> some View {
        view
            .environment(\.codeEditorTheme, theme)
            .environment(\.colorScheme, theme.appearance == .dark ? .dark : .light)
            .background(Color(tokens: theme.style.editor.background))
    }
}
#endif
