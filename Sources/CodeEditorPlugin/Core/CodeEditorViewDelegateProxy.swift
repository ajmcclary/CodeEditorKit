#if canImport(AppKit) && !targetEnvironment(macCatalyst)
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

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    func textDidChange(_ notification: Notification) {
        // Forward NSTextView's textDidChange to our custom notification
        if let textView = notification.object as? CodeEditorView {
            let textChangeNotification = Notification(name: NSText.didChangeNotification, object: textView)
            textViewDidChangeText(textChangeNotification)
        }
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        // Convert NSRange to NSTextRange for CodeEditorView compatibility
        guard let codeEditorView = textView as? CodeEditorView else {
            return true
        }
        
        // Try to convert NSRange to NSTextRange
        if let textLayoutManager = codeEditorView.textLayoutManager,
           let textContentManager = textLayoutManager.textContentManager,
           let textRange = NSTextRange(affectedCharRange, provider: textContentManager) {
            // Forward to the CodeEditorView delegate method with proper NSTextRange
            return source?.textView(codeEditorView, shouldChangeTextIn: textRange, replacementString: replacementString) ?? true
        }
        
        // Fallback: allow the change if we can't convert the range
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
        // Convert NSRange to NSTextRange for CodeEditorView compatibility
        guard let codeEditorView = textView as? CodeEditorView else {
            return true
        }
        
        // UITextView doesn't have TextKit2 support, so we'll create a simple NSTextRange
        if let textRange = NSTextRange(range) {
            return source?.textView(codeEditorView, shouldChangeTextIn: textRange, replacementString: text) ?? true
        }
        
        // Fallback: allow the change if we can't convert the range
        return true
    }
    #endif
}

// MARK: - Platform-specific Protocol Conformance

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
extension CodeEditorViewDelegateProxy: NSTextViewDelegate {}
#elseif canImport(UIKit)
extension CodeEditorViewDelegateProxy: UITextViewDelegate {}
#endif
