//  Created by Claude Code
//  Content view for annotations

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// View for displaying annotation content
public class STAnnotationsContentView: NSView {
    
    public var annotations: [STAnnotation] = [] {
        didSet {
            self.needsDisplay = true
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
        #if canImport(UIKit)
        backgroundColor = .clear
        #elseif canImport(AppKit)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        #endif
    }
    
    #if canImport(UIKit)
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        // Drawing handled by subviews
    }
    #elseif canImport(AppKit)
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Drawing handled by subviews
    }
    
    // Text views need a flipped coordinate system on macOS
    public override var isFlipped: Bool {
        return true
    }
    #endif
}