import CodeEditorPlugin
import CodeEditorSwiftUI
import CodeEditorView
import Foundation

/// Sample-local protocol over `EditorController`'s find / replace
/// surface. Exists so `FindReplaceModel` can be unit-tested with a
/// stub. Conformance for the real controller is provided below.
@MainActor
protocol FindReplaceControlling: AnyObject {
    var matchCount: Int { get }
    var currentMatchIndex: Int { get }

    func find(_ pattern: String, options: SearchOptions?) async -> [SearchResult]
    @discardableResult func findNext() -> SearchResult?
    @discardableResult func findPrevious() -> SearchResult?
    @discardableResult func replaceCurrent(with replacement: String) -> Bool
    @discardableResult
    func replaceAll(_ pattern: String, with replacement: String, options: SearchOptions?) async -> Int
    func clearSearch()
}

extension EditorController: FindReplaceControlling {}
