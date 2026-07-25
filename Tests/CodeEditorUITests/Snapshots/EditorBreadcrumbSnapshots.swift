#if canImport(AppKit)
@testable import CodeEditorKit
@testable import CodeEditorSwiftUI
import CodeEditorSymbols
import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EditorBreadcrumbSnapshots: XCTestCase {
    func testShortDark() {
        snap(theme: .dark, long: false, name: "short-dark")
    }

    func testShortLight() {
        snap(theme: .light, long: false, name: "short-light")
    }

    func testLongDark() {
        snap(theme: .dark, long: true, name: "long-dark")
    }

    func testLongLight() {
        snap(theme: .light, long: true, name: "long-light")
    }

    private enum ThemeChoice {
        case dark
        case light
    }

    private func snap(theme: ThemeChoice, long: Bool, name: String) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        let path: [BreadcrumbComponent] = long
            ? [
                .init(name: "Workspace", kind: .workspace),
                .init(name: "Sources", kind: .folder),
                // Sample display text baked into the committed __Snapshots__ PNGs — kept as
                // the package's former name so the recorded baselines stay valid.
                .init(name: "CodeEditorPlugin", kind: .folder),
                .init(name: "Theming", kind: .folder),
                .init(name: "Loader", kind: .folder),
                .init(name: "ThemeFamily.swift", kind: .file),
                .init(name: "ThemeFamily.theme(named:)", kind: .symbol)
            ]
            : [
                .init(name: "Sources", kind: .folder),
                .init(name: "Foo.swift", kind: .file),
                .init(name: "greet(_:)", kind: .symbol)
            ]
        let view = SnapshotSupport.framed(
            EditorBreadcrumbView(components: path)
                .padding(.horizontal, 14)
                .padding(.vertical, 4),
            theme: resolved
        )
        let host = SnapshotSupport.host(view, size: SnapshotSupport.breadcrumbSize)
        assertSnapshot(
            of: host,
            as: .image(precision: 0.99, perceptualPrecision: 0.99),
            named: name,
            testName: "EditorBreadcrumbSnapshots"
        )
    }
}
#endif
