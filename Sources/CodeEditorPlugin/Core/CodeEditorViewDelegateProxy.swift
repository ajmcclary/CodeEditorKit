#if canImport(AppKit)
@preconcurrency import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import Foundation

@MainActor
class CodeEditorViewDelegateProxy: NSObject, CodeEditorViewDelegate {
    weak var source: CodeEditorViewDelegate?

    init(source: CodeEditorViewDelegate?) {
        self.source = source
    }

    func undoManager(for textView: CodeEditorView) -> UndoManager? {
        source?.undoManager(for: textView)
    }

    func textViewWillChangeText(_ notification: Notification) {
        source?.textViewWillChangeText(notification)
    }

    func textViewDidChangeText(_ notification: Notification) {
        source?.textViewDidChangeText(notification)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        source?.textViewDidChangeSelection(notification)
    }

    func textView(
        _ textView: CodeEditorView,
        shouldChangeTextIn affectedCharRange: NSTextRange,
        replacementString: String?
    ) -> Bool {
        source?.textView(textView, shouldChangeTextIn: affectedCharRange, replacementString: replacementString) ?? true
    }

    @MainActor
    func textView(_ textView: CodeEditorView, willChangeTextIn affectedCharRange: NSTextRange, replacementString: String) {
        source?.textView(textView, willChangeTextIn: affectedCharRange, replacementString: replacementString)
    }

    @MainActor
    func textView(_ textView: CodeEditorView, didChangeTextIn affectedCharRange: NSTextRange, replacementString: String) {
        source?.textView(textView, didChangeTextIn: affectedCharRange, replacementString: replacementString)
    }

    // Menu customization is not yet supported in the delegate protocol
    // @MainActor
    // func textView(_ textView: CodeEditorView, menu: NSMenu, for event: NSEvent, at location: NSTextLocation) -> NSMenu? {
    //     guard let textContentManager = textView.textLayoutManager.textContentManager else {
    //         return nil
    //     }
    //
    //     let effectiveMenu = source?.textView(textView, menu: menu, for: event, at: location)
    //
    //     // Append plugins menus
    //     let pluginMenus = textView.plugins.events.compactMap { events in
    //         events.onContextMenuHandler?(location, textContentManager)
    //     }
    //
    //     if let effectiveMenu, !pluginMenus.isEmpty {
    //         effectiveMenu.addItem(NSMenuItem.separator())
    //
    //         for pluginMenu in pluginMenus {
    //             if pluginMenu.items.count == 1, let firstItem = pluginMenu.items.first?.copy() as? NSMenuItem {
    //                 effectiveMenu.addItem(firstItem)
    //             } else if pluginMenu.items.count > 1 {
    //                 let menuItem = effectiveMenu.addItem(withTitle: pluginMenu.title, action: nil, keyEquivalent: "")
    //                 menuItem.submenu = pluginMenu
    //             }
    //         }
    //     }
    //
    //     return effectiveMenu
    // }

    // Completion items methods are not yet supported in the delegate protocol
    // @_unavailableFromAsync
    // func textView(_ textView: CodeEditorView, completionItemsAtLocation location: NSTextLocation) -> [any CompletionItem]? {
    //     source?.textView(textView, completionItemsAtLocation: location)
    // }
    //
    // func textView(_ textView: CodeEditorView, completionItemsAtLocation location: any NSTextLocation) async -> [any CompletionItem]? {
    //     await source?.textView(textView, completionItemsAtLocation: location)
    // }

    func textView(_ textView: CodeEditorView, insertCompletionItem item: any CompletionItemView) {
        source?.textView(textView, insertCompletionItem: item)
    }

    func textViewCompletionViewController(_ textView: CodeEditorView) -> any CompletionViewControllerRepresentable {
        source?.textViewCompletionViewController(textView) ?? CompletionViewController()
    }

    func textViewInsertionPointView(_ textView: CodeEditorView, frame: CGRect) -> (InsertionPointIndicating)? {
        source?.textViewInsertionPointView(textView, frame: frame)
    }

    func textView(_ textView: CodeEditorView, clickedOnLink link: Any, at location: any NSTextLocation) -> Bool {
        source?.textView(textView, clickedOnLink: link, at: location) ?? false
    }

    func textView(
        _ textView: CodeEditorView,
        clickedOnAttachment attachment: NSTextAttachment,
        at location: any NSTextLocation
    ) -> Bool {
        source?.textView(textView, clickedOnAttachment: attachment, at: location) ?? false
    }

    func textView(
        _ textView: CodeEditorView,
        shouldAllowInteractionWith attachment: NSTextAttachment,
        at location: any NSTextLocation
    ) -> Bool {
        source?.textView(textView, shouldAllowInteractionWith: attachment, at: location) ?? true
    }

    // MARK: - Platform-specific delegate forwarding

    #if canImport(AppKit)
    func textDidChange(_ notification: Notification) {
        // Forward NSTextView's textDidChange to our custom notification
        if let textView = notification.object as? CodeEditorView {
            let textChangeNotification = Notification(name: NSText.didChangeNotification, object: textView)
            textViewDidChangeText(textChangeNotification)
        }
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard let codeEditorView = textView as? CodeEditorView else {
            return true
        }
        guard codeEditorView.configuration.behavior.isEditable else {
            return false
        }

        let allowed: Bool
        let textRange: NSTextRange?
        if let textLayoutManager = codeEditorView.textLayoutManager,
           let textContentManager = textLayoutManager.textContentManager {
            textRange = NSTextRange(affectedCharRange, provider: textContentManager)
        } else {
            textRange = NSTextRange(affectedCharRange)
        }
        if let textRange {
            allowed = source?.textView(
                codeEditorView,
                shouldChangeTextIn: textRange,
                replacementString: replacementString
            ) ?? true
        } else {
            allowed = true
        }

        guard allowed else { return false }

        // Publish WillEditEvent after validation succeeds so rejected edits
        // do not leave stale pending transactions in downstream observers.
        codeEditorView.publishWillEditEvent(
            range: affectedCharRange,
            replacementText: replacementString ?? ""
        )
        return true
    }
    #elseif canImport(UIKit)
    func textViewDidChange(_ textView: UITextView) {
        // Forward UITextView's textViewDidChange to our custom notification
        if let codeEditorView = textView as? CodeEditorView {
            let textChangeNotification = Notification(name: UITextView.textDidChangeNotification, object: codeEditorView)
            textViewDidChangeText(textChangeNotification)
        }
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let codeEditorView = textView as? CodeEditorView else {
            return true
        }
        guard codeEditorView.configuration.behavior.isEditable else {
            return false
        }

        let allowed: Bool
        if let textRange = NSTextRange(range) {
            allowed = source?.textView(
                codeEditorView,
                shouldChangeTextIn: textRange,
                replacementString: text
            ) ?? true
        } else {
            allowed = true
        }

        guard allowed else { return false }

        codeEditorView.publishWillEditEvent(
            range: range,
            replacementText: text
        )
        return true
    }
    #endif
}

// MARK: - Platform-specific Protocol Conformance

#if canImport(AppKit)
extension CodeEditorViewDelegateProxy: NSTextViewDelegate {}
#elseif canImport(UIKit)
extension CodeEditorViewDelegateProxy: UITextViewDelegate {}
#endif
