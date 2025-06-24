//  Created by Claude Code
//  Line highlight view

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// View for highlighting the current line
public class STLineHighlightView: PlatformView {
    
    public var highlightColor: PlatformColor = {
        #if canImport(UIKit)
        return UIColor.systemBlue.withAlphaComponent(0.1)
        #else
        return NSColor.controlAccentColor.withAlphaComponent(0.1)
        #endif
    }() {
        didSet {
            #if canImport(UIKit)
            backgroundColor = highlightColor
            #else
            wantsLayer = true
            layer?.backgroundColor = highlightColor.cgColor
            #endif
        }
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
        #if canImport(UIKit)
        backgroundColor = highlightColor
        #else
        wantsLayer = true
        layer?.backgroundColor = highlightColor.cgColor
        #endif
    }
    
    #if canImport(AppKit)
    // Text views need a flipped coordinate system on macOS
    public override var isFlipped: Bool {
        return true
    }
    #endif
}