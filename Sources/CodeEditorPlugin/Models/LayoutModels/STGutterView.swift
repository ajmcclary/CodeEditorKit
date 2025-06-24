//  Created by Claude Code
//  Missing view type for consolidated package

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// View for displaying line numbers and other gutter information
public class STGutterView: PlatformView {
    
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
        backgroundColor = AdaptiveColorSystem.gutterBackgroundColor
        #elseif canImport(AppKit)
        wantsLayer = true
        layer?.backgroundColor = AdaptiveColorSystem.gutterBackgroundColor.cgColor
        #endif
    }
}