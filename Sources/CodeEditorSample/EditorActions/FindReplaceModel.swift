import CodeEditorPlugin
import CodeEditorSwiftUI
import Foundation
import Observation

private let kSearchDebounce: Duration = .milliseconds(150)

/// Feature-scoped state container for the sample's find / replace
/// overlay. Owns the query text, the case / whole-word / regex
/// toggles, the overlay's open / expanded state, and the live
/// debounce cycle. View-side `FindReplaceOverlay` reads and writes
/// the model; integration glue in `WindowBody` drives the lifecycle
/// `.task(id:)` and the clear-on-edit / clear-on-tab-switch hooks.
///
/// This is the first slice of the AppState decomposition tracked by
/// NEXT.md A.3 #1.
@Observable
@MainActor
final class FindReplaceModel {
    /// User-typed search pattern. Setter is observed by the
    /// overlay's `.task(id:)` via `searchRequest(activeDocumentID:)`.
    var findText: String = ""

    /// User-typed replacement string.
    var replaceText: String = ""

    /// Pinned-at-top overlay visibility. Flip to `false` to dismiss.
    var isOverlayVisible: Bool = false

    /// Case / whole-word / regex toggles, surfaced in the overlay's
    /// expandable options row.
    var options: FindReplaceOptions = .init()

    /// Whether the disclosure row containing the option toggles is
    /// expanded. Closed by default to keep the overlay compact.
    var isOptionsExpanded: Bool = false

    /// Total match count from the most recent search. Mirrored from
    /// the controller so the overlay reads only the model.
    private(set) var matchCount: Int = 0

    /// 1-based position of the active match. `0` when no matches.
    private(set) var currentMatchPosition: Int = 0

    /// Last user-facing find error, or `nil` if the most recent
    /// search succeeded. Currently the only failure mode is regex
    /// pre-validation.
    private(set) var lastError: FindError?

    /// Monotonic counter bumped on every text edit so the
    /// `.task(id:)` running the live search sees a fresh request id
    /// and re-runs.
    private(set) var documentRevision: Int = 0

    /// User-facing find errors the overlay can render.
    enum FindError: Equatable {
        case invalidRegex
    }

    /// Hashable bag of every input that should cause the live search
    /// to re-run. Consumed by SwiftUI's `.task(id:)` modifier.
    struct SearchRequest: Hashable {
        var pattern: String
        var options: FindReplaceOptions
        var activeDocumentID: UUID?
        var documentRevision: Int
    }

    /// Builds a snapshot of the current request. Pass the host
    /// view's active-document id (or `nil` when no tab is open).
    func searchRequest(activeDocumentID: UUID?) -> SearchRequest {
        SearchRequest(
            pattern: findText,
            options: options,
            activeDocumentID: activeDocumentID,
            documentRevision: documentRevision
        )
    }

    /// Bump the revision counter so the live `.task(id:)` re-runs.
    /// Called from `WindowBody` on text mutation, tab switch,
    /// language change, and theme change.
    func markDocumentEdited() {
        documentRevision &+= 1
    }

    /// Sleep for the debounce window, then dispatch the search.
    /// Cancellation aware — if SwiftUI restarts the task before
    /// the sleep finishes, the controller is not touched.
    func runDebouncedSearch(controller: FindReplaceControlling) async {
        try? await Task.sleep(for: kSearchDebounce)
        guard !Task.isCancelled else { return }
        await runSearch(controller: controller)
    }

    /// Immediate (no-debounce) variant. Used by the overlay's
    /// re-run button.
    func runSearch(controller: FindReplaceControlling) async {
        if findText.isEmpty {
            controller.clearSearch()
            matchCount = 0
            currentMatchPosition = 0
            lastError = nil
            return
        }

        if options.useRegularExpression {
            do {
                _ = try NSRegularExpression(pattern: findText)
            } catch {
                lastError = .invalidRegex
                return
            }
        }

        lastError = nil
        _ = await controller.find(findText, options: options.toSearchOptions())
        matchCount = controller.matchCount
        currentMatchPosition = controller.matchCount == 0 ? 0 : controller.currentMatchIndex + 1
    }

    func findNext(controller: FindReplaceControlling) {
        _ = controller.findNext()
        currentMatchPosition = controller.matchCount == 0 ? 0 : controller.currentMatchIndex + 1
    }

    func findPrevious(controller: FindReplaceControlling) {
        _ = controller.findPrevious()
        currentMatchPosition = controller.matchCount == 0 ? 0 : controller.currentMatchIndex + 1
    }

    func replaceCurrent(controller: FindReplaceControlling) {
        guard controller.matchCount > 0 else { return }
        _ = controller.replaceCurrent(with: replaceText)
        matchCount = controller.matchCount
        currentMatchPosition = controller.matchCount == 0 ? 0 : controller.currentMatchIndex + 1
    }

    func replaceAll(controller: FindReplaceControlling) async {
        guard !findText.isEmpty else { return }
        _ = await controller.replaceAll(findText, with: replaceText, options: options.toSearchOptions())
        matchCount = controller.matchCount
        currentMatchPosition = controller.matchCount == 0 ? 0 : controller.currentMatchIndex + 1
    }

    func close(controller: FindReplaceControlling) {
        isOverlayVisible = false
        controller.clearSearch()
        matchCount = 0
        currentMatchPosition = 0
        lastError = nil
    }

    /// Whether the Replace / All buttons should be enabled.
    func canReplace(matchCount: Int, isReadOnly: Bool) -> Bool {
        matchCount > 0 && !isReadOnly
    }
}

#if DEBUG
extension FindReplaceModel {
    /// Test-only hook used by snapshot tests so they can stage a
    /// realistic match-count without spinning up a live editor.
    func applyMockCounts(match: Int, position: Int) {
        matchCount = match
        currentMatchPosition = position
    }

    /// Test-only hook used by snapshot tests.
    func applyMockError(_ error: FindError) {
        lastError = error
    }
}
#endif
