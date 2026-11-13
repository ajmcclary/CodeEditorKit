import CodeEditorCompletion
import CodeEditorLanguages
import CodeEditorPlatform
import CodeEditorTextModel

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Cancellation surface required by the editor-level completion lifecycle.
@MainActor
package protocol CompletionRequestCancelling: AnyObject {
    /// Cancels the current completion request, if one exists.
    func cancelCurrentRequest()
}

extension CompletionManager: CompletionRequestCancelling {}

/// Owns completion request and presentation state for one editor attachment.
@MainActor
package final class EditorCompletionController: EditorFeatureController {
    private weak var attachedView: CodeEditorView?
    private var cancellation: any CompletionRequestCancelling

    internal var viewController: (any CompletionViewControllerRepresentable)?
    internal var isActive = false

    /// UTF-16 offset where the word being completed starts. Accepting an
    /// item replaces the text from here to the caret.
    internal var anchorLocation = 0
    /// The items the provider returned, before filtering by what was typed.
    internal var presentedItems: [CompletionItemModel] = []

    #if canImport(AppKit)
    /// Dismisses the popup when the editor scrolls.
    internal var scrollObserver: NSObjectProtocol?
    #endif

    internal var triggerCharacters: Set<Character> = [".", "(", "[", "<", " "]

    #if canImport(AppKit)
    internal var window: NSWindow?
    #else
    internal var popover: PlatformViewController?
    #endif

    package private(set) var isAttached = false

    package init(cancellation: any CompletionRequestCancelling) {
        self.cancellation = cancellation
    }

    package func attach(to view: CodeEditorView) {
        guard isAttached == false || attachedView !== view else { return }

        detach()
        attachedView = view
        isAttached = true
    }

    package func detach() {
        guard isAttached else { return }

        cancellation.cancelCurrentRequest()
        hidePresentation(announcesChange: false)
        attachedView = nil
        isAttached = false
    }

    package func replaceCancellation(with newCancellation: any CompletionRequestCancelling) {
        guard ObjectIdentifier(cancellation) != ObjectIdentifier(newCancellation) else { return }

        if isAttached {
            cancellation.cancelCurrentRequest()
        }
        cancellation = newCancellation
    }

    package func hidePresentation(announcesChange: Bool) {
        guard isActive else { return }

        #if canImport(AppKit)
        window?.close()
        window = nil
        #else
        popover?.dismiss(animated: true)
        popover = nil
        #endif

        viewController = nil
        isActive = false
        presentedItems = []
        #if canImport(AppKit)
        if let scrollObserver {
            NotificationCenter.default.removeObserver(scrollObserver)
            self.scrollObserver = nil
        }
        #endif
        if announcesChange {
            attachedView?.announceChange("Code completion dismissed")
        }
    }
}

// MARK: - Filtering

extension EditorCompletionController {
    /// The presented items that still match what was typed since the anchor;
    /// empty when the popup no longer applies: the caret left the word, a
    /// selection was made, a non-identifier character was typed, or nothing
    /// matches. Matching is case-insensitive and in-order (each typed
    /// character appears in the item's filter text in sequence).
    internal func itemsMatching(text: String, caret: Int, selectionLength: Int) -> [CompletionItemModel] {
        // swiftlint:disable:next legacy_objc_type
        let nsText = text as NSString
        guard selectionLength == 0, caret >= anchorLocation, caret <= nsText.length else { return [] }
        let typed = nsText.substring(with: NSRange(location: anchorLocation, length: caret - anchorLocation))
        guard typed.allSatisfy(TextRangeUtilities.isIdentifierCharacter) else { return [] }
        guard !typed.isEmpty else { return presentedItems }

        let needle = Array(typed.lowercased())
        return presentedItems.filter { item in
            var remaining = needle[...]
            for character in (item.filterText ?? item.label).lowercased() where character == remaining.first {
                remaining = remaining.dropFirst()
                if remaining.isEmpty { return true }
            }
            return remaining.isEmpty
        }
    }
}
