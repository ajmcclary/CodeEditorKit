import Foundation
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

// MARK: - STAnnotationsContentView

/// View for displaying annotation content
public class STAnnotationsContentView: NSView {
    public var annotations: [STAnnotation] = [] {
        didSet {
            needsDisplay = true
        }
    }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
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

    #elseif canImport(AppKit)

        /// Text views need a flipped coordinate system on macOS
        override public var isFlipped: Bool {
            true
        }
    #endif
    
    deinit {
        // Cleanup if needed
    }
}
