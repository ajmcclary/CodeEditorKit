//  Created by Claude Code
//  Basic completion view controller

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
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override func loadView() {
        self.view = NSView()
    }
}
#endif