@preconcurrency import AppKit

public protocol CompletionViewControllerProtocol: NSViewController {
    typealias Item = any CompletionItem

    var items: [Item] { get set }
    var delegate: CompletionViewControllerDelegate? { get set }
}
