@testable import CodeEditorPlugin
import CodeEditorSymbols
import Foundation
import Testing

@Suite("EditorState public types conform to expected protocols")
struct EditorStateConformanceTests {
    private static func requireValueShape<T>(_ type: T.Type)
    where T: Sendable & Hashable {
        _ = String(describing: type)
    }

    @Test("SelectionState, TabModel, BreadcrumbComponent are Sendable + Hashable")
    func auditValueTypes() {
        Self.requireValueShape(SelectionState.self)
        Self.requireValueShape(TabModel.self)
        Self.requireValueShape(BreadcrumbComponent.self)
        Self.requireValueShape(BreadcrumbComponent.Kind.self)
    }

    @Test("TabModel and BreadcrumbComponent are Identifiable")
    func auditIdentifiable() {
        let tab = TabModel(name: "Foo.swift")
        _ = tab.id
        let crumb = BreadcrumbComponent(name: "Sources", kind: .folder)
        _ = crumb.id
    }
}
