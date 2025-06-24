//  Created by Claude Code
//  Line highlight view

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// View for highlighting the current line
public class STLineHighlightView: NSView {
    
    public var highlightColor: NSColor = NSColor.controlAccentColor.withAlphaComponent(0.1) {
        didSet {
            self.wantsLayer = true
            self.layer?.backgroundColor = highlightColor.cgColor
        }
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        self.wantsLayer = true
        self.layer?.backgroundColor = highlightColor.cgColor
    }
    
    // Text views need a flipped coordinate system on macOS
    public override var isFlipped: Bool {
        return true
    }
}