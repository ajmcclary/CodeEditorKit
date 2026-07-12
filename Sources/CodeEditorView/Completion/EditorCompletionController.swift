import CodeEditorCompletion
import CodeEditorPlatform

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
        if announcesChange {
            attachedView?.announceChange("Code completion dismissed")
        }
    }
}
