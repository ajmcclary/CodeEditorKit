#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@preconcurrency import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import Foundation

@MainActor
class CodeEditorViewDelegateProxy: NSObject, @preconcurrency CodeEditorViewDelegate {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    // NSTextViewDelegate methods will be implemented
    #elseif canImport(UIKit)
    // UITextViewDelegate methods will be implemented
    #endif
    
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

    func textView(_ textView: CodeEditorView, insertCompletionItem item: any CompletionItem) {
        source?.textView(textView, insertCompletionItem: item)
    }

    func textViewCompletionViewController(_ textView: CodeEditorView) -> any CompletionViewControllerProtocol {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return source?.textViewCompletionViewController(textView) ?? CompletionViewController()
        #else
        // iOS stub - return a minimal implementation
        return source?.textViewCompletionViewController(textView) ?? BasicCompletionViewController()
        #endif
    }

    func textViewInsertionPointView(_ textView: CodeEditorView, frame: CGRect) -> (InsertionPointIndicatorProtocol)? {
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
            let stNotification = Notification(name: NSText.didChangeNotification, object: textView)
            textViewDidChangeText(stNotification)
        }
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn _: NSRange, replacementString _: String?) -> Bool {
        // Convert NSRange to NSTextRange for CodeEditorView compatibility
        // This is a simplified approach - in a full implementation, we'd need proper conversion
        if textView is CodeEditorView {
            // For now, just forward with a simple implementation - skip the NSTextRange conversion
            // TODO: Properly convert NSRange to NSTextRange
            return true // source?.textView(stTextView, shouldChangeTextIn: convertedRange, replacementString: replacementString) ?? true
        }
        return true
    }
    #elseif canImport(UIKit)
    func textViewDidChange(_ textView: UITextView) {
        // Forward UITextView's textViewDidChange to our custom notification
        if let codeEditorView = textView as? CodeEditorView {
            let stNotification = Notification(name: UITextView.textDidChangeNotification, object: codeEditorView)
            textViewDidChangeText(stNotification)
        }
    }

    func textView(_ textView: UITextView, shouldChangeTextIn _: NSRange, replacementText _: String) -> Bool {
        // Convert NSRange to NSTextRange for CodeEditorView compatibility
        if textView is CodeEditorView {
            // For now, just forward with a simple implementation
            return true
        }
        return true
    }
    #endif

    deinit {
        // Cleanup if needed
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
// swiftlint:disable:next no_grouping_extension
extension CodeEditorViewDelegateProxy: NSTextViewDelegate {}
#elseif canImport(UIKit)
// swiftlint:disable:next no_grouping_extension
extension CodeEditorViewDelegateProxy: UITextViewDelegate {}
#endif
