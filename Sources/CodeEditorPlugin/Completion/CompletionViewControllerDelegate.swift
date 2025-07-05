#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@preconcurrency import AppKit
public typealias PlatformTextMovement = NSTextMovement
#endif
#if canImport(UIKit)
import UIKit
public enum PlatformTextMovement: Int {
    case cancel = 0
    case other = 1
    case tab = 2
    case backtab = 3
    case up = 4
    case down = 5
    case left = 6
    case right = 7
    case `return` = 8
}
#endif

@MainActor
public protocol CompletionViewControllerDelegate: AnyObject {
    func completionViewController(
        _ viewController: some CompletionViewControllerRepresentable,
        complete item: any CompletionItem,
        movement: PlatformTextMovement
    )
}
