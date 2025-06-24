@preconcurrency import AppKit

public protocol STCompletionViewControllerProtocol: NSViewController {
    typealias Item = any STCompletionItem

    var items: [Item] { get set }
    var delegate: STCompletionViewControllerDelegate? { get set }
}
