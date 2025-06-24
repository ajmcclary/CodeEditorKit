@preconcurrency import AppKit

@MainActor
public protocol STCompletionViewControllerDelegate: AnyObject {
    func completionViewController(
        _ viewController: some STCompletionViewControllerProtocol,
        complete item: any STCompletionItem,
        movement: NSTextMovement
    )
}
