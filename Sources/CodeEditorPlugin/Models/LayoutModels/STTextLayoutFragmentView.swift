//  Created by Claude Code
//  Missing view type for consolidated package

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// View for rendering text layout fragments
public class STTextLayoutFragmentView: PlatformView {
    
    public var layoutFragment: NSTextLayoutFragment? {
        didSet {
            #if canImport(UIKit)
            setNeedsDisplay()
            #elseif canImport(AppKit)
            needsDisplay = true
            #endif
        }
    }
    
    public init(layoutFragment: NSTextLayoutFragment?, frame: CGRect) {
        self.layoutFragment = layoutFragment
        super.init(frame: frame)
        setup()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        #if canImport(AppKit)
        wantsLayer = true
        #endif
        #if canImport(UIKit)
        backgroundColor = .clear
        #elseif canImport(AppKit)
        // backgroundColor not available on NSView
        #endif
    }
    
    #if canImport(UIKit)
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        // Drawing handled by layout fragment
    }
    #elseif canImport(AppKit)
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let layoutFragment = layoutFragment else { return }
        
        // Get the graphics context
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw the layout fragment
        layoutFragment.draw(at: .zero, in: context)
    }
    
    // Text views need a flipped coordinate system on macOS
    public override var isFlipped: Bool {
        return true
    }
    #endif
}