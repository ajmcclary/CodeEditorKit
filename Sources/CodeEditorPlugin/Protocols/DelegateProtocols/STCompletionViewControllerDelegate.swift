//  Created by Marcin Krzyzanowski
//  https://github.com/krzyzanowskim/STTextView/blob/main/LICENSE.md

@preconcurrency import AppKit

@MainActor
public protocol STCompletionViewControllerDelegate: AnyObject {
    func completionViewController<T: STCompletionViewControllerProtocol>(_ viewController: T, complete item: any STCompletionItem, movement: NSTextMovement)
}
