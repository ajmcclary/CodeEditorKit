import Foundation
#if canImport(AppKit)
import AppKit

/// Default completion view controller implementation
public class CompletionViewController: NSViewController, CompletionViewControllerProtocol {
    public typealias Item = any CompletionItem

    public var items: [Item] = []
    public weak var delegate: CompletionViewControllerDelegate?

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override public func loadView() {
        view = NSView()
    }

    deinit {
        // Cleanup if needed
    }
}

#elseif canImport(UIKit)
import UIKit

/// iOS basic completion view controller implementation
public class BasicCompletionViewController: UIViewController, CompletionViewControllerProtocol {
    public typealias Item = any CompletionItem
    
    public var items: [Item] = []
    public weak var delegate: CompletionViewControllerDelegate?
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override public func loadView() {
        view = UIView()
    }
    
    deinit {
        // Cleanup if needed
    }
}
#endif
