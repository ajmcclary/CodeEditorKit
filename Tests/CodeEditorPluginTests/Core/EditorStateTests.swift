import CodeEditorCommon
import CodeEditorLanguages
@testable import CodeEditorPlugin
import CodeEditorSymbols
@testable import CodeEditorView
import Foundation
import Observation
import Testing

/// Sendable-safe counter for observation-fire assertions. The @Sendable
/// closure passed to `withObservationTracking(_:onChange:)` can't mutate
/// captured `var`s under Swift 6 strict concurrency, so tests use this
/// class-wrapped reference type instead.
private final class FireCounter: @unchecked Sendable {
    private(set) var value: Int = 0

    func increment() { value += 1 }
}

@Suite("EditorState observation")
@MainActor
struct EditorStateTests {
    @Test("Default EditorState has empty/nil fields")
    func defaultsAreEmpty() {
        let state = EditorState()
        #expect(state.selection == nil)
        #expect(state.language == nil)
        #expect(state.isDirty == false)
        #expect(state.hardwareAccelerationActive == false)
        #expect(state.lineCount == 0)
        #expect(state.documentName.isEmpty)
        #expect(state.documentURL == nil)
        #expect(state.tabs.isEmpty)
        #expect(state.activeTabID == nil)
        #expect(state.breadcrumbPath.isEmpty)
        #expect(state.workspaceName.isEmpty)
    }

    @Test("Mutating selection fires observation")
    func mutatingSelectionFiresObservers() {
        let state = EditorState()
        let counter = FireCounter()
        withObservationTracking {
            _ = state.selection
        } onChange: {
            counter.increment()
        }
        state.selection = SelectionState(line: 1, column: 1)
        #expect(counter.value == 1)
    }

    @Test("Mutating tabs fires observation")
    func mutatingTabsFiresObservers() {
        let state = EditorState()
        let counter = FireCounter()
        withObservationTracking {
            _ = state.tabs
        } onChange: {
            counter.increment()
        }
        state.tabs.append(TabModel(name: "Foo.swift"))
        #expect(counter.value == 1)
    }

    @Test("SelectionState equality")
    func selectionEquality() {
        let lhs = SelectionState(line: 10, column: 4, selectionLength: 3)
        let rhs = SelectionState(line: 10, column: 4, selectionLength: 3)
        let other = SelectionState(line: 10, column: 4)
        #expect(lhs == rhs)
        #expect(lhs != other)
    }

    @Test("TabModel preserves identity across mutations")
    func tabModelIdentityStable() {
        var tab = TabModel(name: "Foo.swift")
        let id = tab.id
        tab.name = "Bar.swift"
        tab.isDirty = true
        #expect(tab.id == id)
    }

    @Test("BreadcrumbComponent round-trips through array")
    func breadcrumbRoundtrip() {
        let crumbs = [
            BreadcrumbComponent(name: "Sources", kind: .folder),
            BreadcrumbComponent(name: "CodeEditorPlugin", kind: .folder),
            BreadcrumbComponent(name: "Foo.swift", kind: .file),
            BreadcrumbComponent(name: "greet(_:)", kind: .symbol)
        ]
        let copy = Array(crumbs)
        #expect(copy == crumbs)
        #expect(copy.map(\.id) == crumbs.map(\.id))
    }
}
