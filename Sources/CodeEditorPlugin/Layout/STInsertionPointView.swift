import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - STInsertionPointView

/// View representing the text insertion point (cursor)
public class STInsertionPointView: NSView {
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
        backgroundColor = UIColor.label
        #elseif canImport(AppKit)
        wantsLayer = true
        layer?.backgroundColor = NSColor.labelColor.cgColor
        #endif
    }

    #if canImport(AppKit)
    /// Text views need a flipped coordinate system on macOS
    override public var isFlipped: Bool {
        true
    }
    #endif

    deinit {
        // Cleanup if needed
    }
}
