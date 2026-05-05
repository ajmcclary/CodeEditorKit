#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EditorTrafficLightsSnapshots: XCTestCase {
    func testDecorativeDark() {
        snap(theme: .dark, withCallbacks: false, name: "decorative-dark")
    }

    func testDecorativeLight() {
        snap(theme: .light, withCallbacks: false, name: "decorative-light")
    }

    func testWithCallbacksDark() {
        snap(theme: .dark, withCallbacks: true, name: "callbacks-dark")
    }

    func testWithCallbacksLight() {
        snap(theme: .light, withCallbacks: true, name: "callbacks-light")
    }

    private enum ThemeChoice {
        case dark
        case light
    }

    private func snap(theme: ThemeChoice, withCallbacks: Bool, name: String) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        var configuration = TrafficLightsConfiguration.standard
        if withCallbacks {
            configuration.onClose = {}
            configuration.onMinimize = {}
            configuration.onZoom = {}
        }
        let view = SnapshotSupport.framed(
            EditorTrafficLights(configuration: configuration).padding(8),
            theme: resolved
        )
        let host = SnapshotSupport.host(view, size: SnapshotSupport.trafficLightsSize)
        assertSnapshot(
            of: host,
            as: .image(precision: 0.99, perceptualPrecision: 0.99),
            named: name,
            testName: "EditorTrafficLightsSnapshots"
        )
    }
}
#endif
