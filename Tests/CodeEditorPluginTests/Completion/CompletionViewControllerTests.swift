#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
import Testing

@Suite("CompletionViewController")
struct CompletionViewControllerTests {
    @Test("Setting completion items before view load does not re-enter lazy table construction")
    @MainActor
    func completionItemsBeforeViewLoadDoesNotReenterLazyTableConstruction() {
        let controller = CompletionViewController()

        controller.completionItems = [
            CompletionItemModel(label: "alpha", kind: .keyword)
        ]

        #expect(controller.selectedCompletionItem()?.label == "alpha")
    }
}
#endif
