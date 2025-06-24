//  Created by Marcin Krzyzanowski
//  https://github.com/krzyzanowskim/STTextView/blob/main/LICENSE.md

import Foundation
@preconcurrency import AppKit

@MainActor
class STTextViewDelegateProxy: NSObject, @preconcurrency STTextViewDelegate, NSTextViewDelegate {
    weak var source: STTextViewDelegate?

    init(source: STTextViewDelegate?) {
        self.source = source
    }

    func undoManager(for textView: STTextView) -> UndoManager? {
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

    func textView(_ textView: STTextView, shouldChangeTextIn affectedCharRange: NSTextRange, replacementString: String?) -> Bool {
        return source?.textView(textView, shouldChangeTextIn: affectedCharRange, replacementString: replacementString) ?? true
    }

    @MainActor
    func textView(_ textView: STTextView, willChangeTextIn affectedCharRange: NSTextRange, replacementString: String) {
        source?.textView(textView, willChangeTextIn: affectedCharRange, replacementString: replacementString)
    }

    @MainActor
    func textView(_ textView: STTextView, didChangeTextIn affectedCharRange: NSTextRange, replacementString: String) {
        source?.textView(textView, didChangeTextIn: affectedCharRange, replacementString: replacementString)
    }

    // Menu customization is not yet supported in the delegate protocol
    // @MainActor
    // func textView(_ textView: STTextView, menu: NSMenu, for event: NSEvent, at location: NSTextLocation) -> NSMenu? {
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
    // func textView(_ textView: STTextView, completionItemsAtLocation location: NSTextLocation) -> [any STCompletionItem]? {
    //     source?.textView(textView, completionItemsAtLocation: location)
    // }
    //
    // func textView(_ textView: STTextView, completionItemsAtLocation location: any NSTextLocation) async -> [any STCompletionItem]? {
    //     await source?.textView(textView, completionItemsAtLocation: location)
    // }

    func textView(_ textView: STTextView, insertCompletionItem item: any STCompletionItem) {
        source?.textView(textView, insertCompletionItem: item)
    }

    func textViewCompletionViewController(_ textView: STTextView) -> any STCompletionViewControllerProtocol {
        source?.textViewCompletionViewController(textView) ?? STCompletionViewController()
    }

    func textViewInsertionPointView(_ textView: STTextView, frame: CGRect) -> (STInsertionPointIndicatorProtocol)? {
        source?.textViewInsertionPointView(textView, frame: frame)
    }

    func textView(_ textView: STTextView, clickedOnLink link: Any, at location: any NSTextLocation) -> Bool {
        source?.textView(textView, clickedOnLink: link, at: location) ?? false
    }
    
    func textView(_ textView: STTextView, clickedOnAttachment attachment: NSTextAttachment, at location: any NSTextLocation) -> Bool {
        source?.textView(textView, clickedOnAttachment: attachment, at: location) ?? false
    }
    
    func textView(_ textView: STTextView, shouldAllowInteractionWith attachment: NSTextAttachment, at location: any NSTextLocation) -> Bool {
        source?.textView(textView, shouldAllowInteractionWith: attachment, at: location) ?? true
    }

    // MARK: - NSTextViewDelegate forwarding
    
    func textDidChange(_ notification: Notification) {
        // Forward NSTextView's textDidChange to our custom notification
        if let textView = notification.object as? STTextView {
            let stNotification = Notification(name: NSText.didChangeNotification, object: textView)
            textViewDidChangeText(stNotification)
        }
    }
    
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        // Convert NSRange to NSTextRange for STTextView compatibility
        // This is a simplified approach - in a full implementation, we'd need proper conversion
        if let stTextView = textView as? STTextView {
            // For now, just forward with a simple implementation - skip the NSTextRange conversion
            // TODO: Properly convert NSRange to NSTextRange
            return true // source?.textView(stTextView, shouldChangeTextIn: convertedRange, replacementString: replacementString) ?? true
        }
        return true
    }

}
