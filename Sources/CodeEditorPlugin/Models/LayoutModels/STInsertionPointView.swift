//  Created by Claude Code
//  Missing view type for consolidated package

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// View representing the text insertion point (cursor)
public class STInsertionPointView: NSView {
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        #if canImport(UIKit)
        backgroundColor = UIColor.label
        #elseif canImport(AppKit)
        wantsLayer = true
        layer?.backgroundColor = NSColor.labelColor.cgColor
        #endif
    }
    
    #if canImport(AppKit)
    // Text views need a flipped coordinate system on macOS
    public override var isFlipped: Bool {
        return true
    }
    #endif
}