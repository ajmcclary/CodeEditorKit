#if canImport(AppKit)
@testable import CodeEditorKit
@testable import CodeEditorSwiftUI
import CodeEditorUI
@testable import CodeEditorView
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EditorTitleBarSnapshots: XCTestCase {
    func testEmptyTrailingDark() {
        snap(theme: .dark, trailing: false, name: "empty-trailing-dark")
    }

    func testEmptyTrailingLight() {
        snap(theme: .light, trailing: false, name: "empty-trailing-light")
    }

    func testWithToolbarDark() {
        snap(theme: .dark, trailing: true, name: "with-toolbar-dark")
    }

    func testWithToolbarLight() {
        snap(theme: .light, trailing: true, name: "with-toolbar-light")
    }

    private enum ThemeChoice {
        case dark
        case light
    }

    @ViewBuilder
    private func toolbarPills() -> some View {
        HStack(spacing: 6) {
            Text("⌘B")
                .font(.system(size: 10, design: .monospaced))
                .padding(.horizontal, 8)
                .frame(height: 22)
            Text("▶")
                .font(.system(size: 10, design: .monospaced))
                .padding(.horizontal, 8)
                .frame(height: 22)
            Text("◧")
                .font(.system(size: 10, design: .monospaced))
                .padding(.horizontal, 8)
                .frame(height: 22)
        }
    }

    private func snap(theme: ThemeChoice, trailing: Bool, name: String) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        let state = EditorState()
        // Sample display text baked into the committed __Snapshots__ PNGs — kept as the
        // package's former name so the recorded baselines stay valid.
        state.documentName = "EditorState.swift — CodeEditorPlugin"
        let titleBar: AnyView = trailing
            ? AnyView(EditorTitleBar { self.toolbarPills() })
            : AnyView(EditorTitleBar())
        let view = SnapshotSupport.framed(
            titleBar.environment(\.editorState, state),
            theme: resolved
        )
        let host = SnapshotSupport.host(view, size: SnapshotSupport.rowSize)
        assertSnapshot(
            of: host,
            as: .image(precision: 0.99, perceptualPrecision: 0.99),
            named: name,
            testName: "EditorTitleBarSnapshots"
        )
    }
}
#endif
