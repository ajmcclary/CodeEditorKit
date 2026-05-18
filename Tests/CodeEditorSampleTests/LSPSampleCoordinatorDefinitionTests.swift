#if canImport(AppKit)
import CodeEditorLSP
import CodeEditorPlugin
@testable import CodeEditorSample
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import Foundation
import Testing

@MainActor
@Suite("LSPSampleCoordinator definition resolver")
struct LSPSampleCoordinatorDefinitionTests {
    @Test func openInWorkspaceForInWorkspaceLocation() {
        let workspace = URL(fileURLWithPath: "/Users/me/proj")
        let location = Location(
            uri: "file:///Users/me/proj/Foo.swift",
            range: LSPRange(
                start: Position(line: 3, character: 0),
                end: Position(line: 3, character: 1)
            )
        )

        let target = LSPSampleCoordinator.resolveDefinitionTarget(
            locations: [location],
            workspaceRoot: workspace
        )

        if case .openInWorkspace(let url, let line) = target {
            #expect(url.path == "/Users/me/proj/Foo.swift")
            #expect(line == 3)
        } else {
            Issue.record("expected .openInWorkspace, got \(target)")
        }
    }

    @Test func toastForOutOfWorkspaceLocation() {
        let workspace = URL(fileURLWithPath: "/Users/me/proj")
        let location = Location(
            uri: "file:///Applications/Xcode.app/Foundation.swift",
            range: LSPRange(
                start: Position(line: 10, character: 0),
                end: Position(line: 10, character: 5)
            )
        )

        let target = LSPSampleCoordinator.resolveDefinitionTarget(
            locations: [location],
            workspaceRoot: workspace
        )

        if case .toast(let message) = target {
            #expect(message.contains("Foundation.swift"))
            #expect(message.contains("10"))
        } else {
            Issue.record("expected .toast, got \(target)")
        }
    }

    @Test func noneForEmptyLocations() {
        let target = LSPSampleCoordinator.resolveDefinitionTarget(
            locations: [],
            workspaceRoot: URL(fileURLWithPath: "/Users/me/proj")
        )

        if case .empty = target {
            // pass
        } else {
            Issue.record("expected .empty, got \(target)")
        }
    }

    @Test func toastWhenWorkspaceIsNil() {
        let location = Location(
            uri: "file:///Users/me/proj/Foo.swift",
            range: LSPRange(
                start: Position(line: 3, character: 0),
                end: Position(line: 3, character: 1)
            )
        )

        let target = LSPSampleCoordinator.resolveDefinitionTarget(
            locations: [location],
            workspaceRoot: nil
        )

        if case .toast = target {
            // pass — without workspaceRoot, anything is "out of scope"
        } else {
            Issue.record("expected .toast, got \(target)")
        }
    }
}
#endif
