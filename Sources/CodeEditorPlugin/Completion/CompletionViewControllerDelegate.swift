@preconcurrency import AppKit

@MainActor
public protocol CompletionViewControllerDelegate: AnyObject {
    func completionViewController(
        _ viewController: some CompletionViewControllerProtocol,
        complete item: any CompletionItem,
        movement: NSTextMovement
    )
}
