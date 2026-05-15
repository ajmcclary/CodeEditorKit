#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
@testable import CodeEditorSample
import SnapshotTesting
import SwiftUI
import XCTest

/// Snapshot baseline for the cross-platform `InspectorPanelStack`. The
/// stack composes six panels (LSP / Performance / Completion /
/// Annotations / EventLog / Configuration text + Copy). This suite
/// covers the empty-state rendering against a freshly constructed
/// `AppState` — the panels exercise their "no data yet" branches, which
/// is the most fragile rendering and most likely to drift.
@MainActor
final class InspectorPanelStackSnapshotTests: XCTestCase {
    func testEmptyStateLight() {
        let appState = AppState()
        let view = InspectorPanelStack(
            appState: appState,
            showingPerformanceReport: .constant(false)
        )
        assertSnapshot(
            of: host(view, scheme: .light),
            as: .image(precision: 0.99),
            named: "empty-light"
        )
    }

    func testEmptyStateDark() {
        let appState = AppState()
        let view = InspectorPanelStack(
            appState: appState,
            showingPerformanceReport: .constant(false)
        )
        assertSnapshot(
            of: host(view, scheme: .dark),
            as: .image(precision: 0.99),
            named: "empty-dark"
        )
    }

    // MARK: - Helpers

    private func host<V: View>(_ view: V, scheme: ColorScheme) -> NSView {
        let hosting = NSHostingView(rootView: view.preferredColorScheme(scheme))
        hosting.frame = CGRect(x: 0, y: 0, width: 360, height: 1_200)
        return hosting
    }
}
#endif
