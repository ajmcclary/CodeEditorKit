#if canImport(AppKit)
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
import CodeEditorUI
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class EditorSidebarShellSnapshots: XCTestCase {
    func testFullDark() {
        snap(theme: .dark, name: "full-dark")
    }

    func testFullLight() {
        snap(theme: .light, name: "full-light")
    }

    private enum ThemeChoice {
        case dark
        case light
    }

    @ViewBuilder
    private func tabBar() -> some View {
        HStack(spacing: 4) {
            sidebarTab("Files", isActive: true)
            sidebarTab("Search", isActive: false)
            sidebarTab("Issues", isActive: false)
            Spacer()
        }
    }

    private func sidebarTab(_ label: String, isActive: Bool) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? Color.white.opacity(0.08) : .clear)
            .clipShape(.rect(cornerRadius: 5))
    }

    @ViewBuilder
    private func contentBody() -> some View {
        let labels = [
            "Sources",
            "CodeEditorPlugin",
            "Configuration",
            "EditorConfiguration.swift",
            "Theming"
        ]
        VStack(alignment: .leading, spacing: 6) {
            ForEach(labels, id: \.self) { label in
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                    Text(label)
                }
                .font(.system(size: 12))
                .padding(.leading, 8)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func footerBody() -> some View {
        HStack(spacing: 4) {
            ForEach(["Swift", "TS", "Python", "Rust", "JSON"], id: \.self) { label in
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func snap(theme: ThemeChoice, name: String) {
        let resolved = (theme == .dark) ? SnapshotSupport.darkTheme : SnapshotSupport.lightTheme
        let view = SnapshotSupport.framed(
            EditorSidebarShell(
                sectionTitle: "CodeEditorPlugin",
                header: { self.tabBar() },
                content: { self.contentBody() },
                footer: { self.footerBody() }
            ),
            theme: resolved
        )
        let host = SnapshotSupport.host(view, size: SnapshotSupport.panelSize)
        assertSnapshot(
            of: host,
            as: .image(precision: 0.99, perceptualPrecision: 0.99),
            named: name,
            testName: "EditorSidebarShellSnapshots"
        )
    }
}
#endif
