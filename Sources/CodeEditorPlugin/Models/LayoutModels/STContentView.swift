//  Created by Claude Code
//  Missing view type for consolidated package

import Foundation
#if canImport(UIKit)
import UIKit
public typealias PlatformView = UIView
#elseif canImport(AppKit)
import AppKit
public typealias PlatformView = NSView
#endif

/// Content view that contains layout fragments
public class STContentView: PlatformView {
    
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
    }
    
    #if canImport(AppKit)
    // Text views need a flipped coordinate system on macOS
    public override var isFlipped: Bool {
        return true
    }
    #endif
}