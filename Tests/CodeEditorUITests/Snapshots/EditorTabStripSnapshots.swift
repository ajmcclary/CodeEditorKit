#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@testable import CodeEditorPlugin
import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EditorTabStripSnapshots: XCTestCase {
    func testEmptyDark() {
        snap(theme: .dark, variant: .empty, name: "empty-dark")
    }

    func testEmptyLight() {
        snap(theme: .light, variant: .empty, name: "empty-light")
    }

    func testSingleDark() {
        snap(theme: .dark, variant: .single, name: "single-dark")
    }

    func testSingleLight() {
        snap(theme: .light, variant: .single, name: "single-light")
    }

    func testManyDark() {
        snap(theme: .dark, variant: .many, name: "many-dark")
    }

    func testManyLight() {
        snap(theme: .light, variant: .many, name: "many-light")
    }

    func testWithDirtyDark() {
        snap(theme: .dark, variant: .withDirty, name: "with-dirty-dark")
    }

    func testWithDirtyLight() {
        snap(theme: .light, variant: .withDirty, name: "with-dirty-light")
    }

    func testCompactStyleDark() {
        snap(theme: .dark, variant: .compactStyle, name: "compact-dark")
    }

    func testCompactStyleLight() {
        snap(theme: .light, variant: .compactStyle, name: "compact-light")
    }

    private enum ThemeChoice {
        case dark
        case light
    }

    private enum Variant {
        case empty
        case single
        case many
        case withDirty
        case compactStyle
    }

    private func snap(theme: ThemeChoice, variant: Variant, name: String) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        let tabs: [TabModel]
        switch variant {
        case .empty:
            tabs = []

        case .single:
            tabs = [TabModel(name: "Foo.swift", language: .swift)]

        case .many, .compactStyle:
            tabs = [
                TabModel(name: "Foo.swift", language: .swift),
                TabModel(name: "Bar.ts", language: .typescript),
                TabModel(name: "Baz.py", language: .python),
                TabModel(name: "Qux.json", language: .json)
            ]

        case .withDirty:
            tabs = [
                TabModel(name: "Foo.swift", language: .swift, isDirty: true),
                TabModel(name: "Bar.ts", language: .typescript)
            ]
        }
        let active = tabs.first?.id
        let view: AnyView = {
            let bindingTabs = Binding<[TabModel]>(get: { tabs }, set: { _ in })
            let bindingActive = Binding<TabModel.ID?>(get: { active }, set: { _ in })
            let strip = EditorTabStrip(tabs: bindingTabs, activeTabID: bindingActive)
            switch variant {
            case .compactStyle:
                return AnyView(strip.editorTabStripStyle(.compact))

            default:
                return AnyView(strip)
            }
        }()
        let framed = SnapshotSupport.framed(view, theme: resolved)
        let host = SnapshotSupport.host(framed, size: SnapshotSupport.rowSize)
        assertSnapshot(
            of: host,
            as: .image(precision: 0.99, perceptualPrecision: 0.99),
            named: name,
            testName: "EditorTabStripSnapshots"
        )
    }
}
#endif
