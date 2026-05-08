#if canImport(AppKit)
import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class PlatformGlassSurfaceSnapshots: XCTestCase {
    func testTitleBarRoleDark() {
        snap(role: .titleBar, theme: .dark, name: "titleBar-dark")
    }

    func testTitleBarRoleLight() {
        snap(role: .titleBar, theme: .light, name: "titleBar-light")
    }

    func testTabBarRoleDark() {
        snap(role: .tabBar, theme: .dark, name: "tabBar-dark")
    }

    func testTabBarRoleLight() {
        snap(role: .tabBar, theme: .light, name: "tabBar-light")
    }

    func testStatusBarRoleDark() {
        snap(role: .statusBar, theme: .dark, name: "statusBar-dark")
    }

    func testStatusBarRoleLight() {
        snap(role: .statusBar, theme: .light, name: "statusBar-light")
    }

    func testPanelRoleDark() {
        snap(role: .panel, theme: .dark, name: "panel-dark")
    }

    func testPanelRoleLight() {
        snap(role: .panel, theme: .light, name: "panel-light")
    }

    func testPopoverRoleDark() {
        snap(role: .popover, theme: .dark, name: "popover-dark")
    }

    func testPopoverRoleLight() {
        snap(role: .popover, theme: .light, name: "popover-light")
    }

    private enum ThemeChoice {
        case dark
        case light
    }

    private func snap(role: PlatformGlassSurface.Role, theme: ThemeChoice, name: String) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        let body = SnapshotSupport.framed(
            Text(String(describing: role))
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .platformGlassSurface(role),
            theme: resolved
        )
        let host = SnapshotSupport.host(body, size: SnapshotSupport.glassSize)
        assertSnapshot(
            of: host,
            as: .image(precision: 0.99, perceptualPrecision: 0.99),
            named: name,
            testName: "PlatformGlassSurfaceSnapshots"
        )
    }
}
#endif
