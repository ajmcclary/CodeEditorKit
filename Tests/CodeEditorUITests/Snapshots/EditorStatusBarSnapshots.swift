#if canImport(AppKit)
import CodeEditorCommon
import CodeEditorConfiguration
@testable import CodeEditorPlugin
import CodeEditorUI
@testable import CodeEditorView
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EditorStatusBarSnapshots: XCTestCase {
    func testNoDocDark() {
        snap(theme: .dark, scenario: .noDoc, name: "no-doc-dark")
    }

    func testNoDocLight() {
        snap(theme: .light, scenario: .noDoc, name: "no-doc-light")
    }

    func testWithSelectionDark() {
        snap(theme: .dark, scenario: .docWithSelection, name: "selection-dark")
    }

    func testWithSelectionLight() {
        snap(theme: .light, scenario: .docWithSelection, name: "selection-light")
    }

    func testWithTrailingDark() {
        snap(theme: .dark, scenario: .docWithTrailingExtras, name: "trailing-dark")
    }

    func testWithTrailingLight() {
        snap(theme: .light, scenario: .docWithTrailingExtras, name: "trailing-light")
    }

    private enum ThemeChoice {
        case dark
        case light
    }

    private enum Scenario {
        case noDoc
        case docWithSelection
        case docWithTrailingExtras
    }

    @ViewBuilder
    private func trailingExtras() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right")
            Text("LSP").font(.system(size: 11, design: .monospaced))
        }
    }

    private func snap(theme: ThemeChoice, scenario: Scenario, name: String) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        let state = EditorState()
        switch scenario {
        case .noDoc:
            break

        case .docWithSelection, .docWithTrailingExtras:
            state.selection = SelectionState(line: 142, column: 18, selectionLength: 0)
            state.language = .swift
            state.lineCount = 380
            state.hardwareAccelerationActive = true
        }
        let bar: AnyView = {
            switch scenario {
            case .docWithTrailingExtras:
                return AnyView(EditorStatusBar { self.trailingExtras() })

            default:
                return AnyView(EditorStatusBar())
            }
        }()
        let configuration = EditorConfiguration()
        let view = SnapshotSupport.framed(
            bar
                .environment(\.editorState, state)
                .environment(\.codeEditorConfiguration, configuration),
            theme: resolved
        )
        let host = SnapshotSupport.host(view, size: SnapshotSupport.rowSize)
        assertSnapshot(
            of: host,
            as: .image(precision: 0.99, perceptualPrecision: 0.99),
            named: name,
            testName: "EditorStatusBarSnapshots"
        )
    }
}
#endif
