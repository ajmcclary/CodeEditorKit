import Foundation
#if canImport(AppKit)
    import AppKit

    /// Default completion view controller implementation
    public class STCompletionViewController: NSViewController, STCompletionViewControllerProtocol {
        public typealias Item = any STCompletionItem

        public var items: [Item] = []
        public weak var delegate: STCompletionViewControllerDelegate?

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
#endif
