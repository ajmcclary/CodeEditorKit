import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - AnnotationsContentView

/// View for displaying annotation content
#if canImport(AppKit)
public class AnnotationsContentView: NSView {
    public var annotations: [Annotation] = [] {
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
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    /// Text views need a flipped coordinate system on macOS
    override public var isFlipped: Bool {
        true
    }

    deinit {
        // Cleanup if needed
    }
}
#elseif canImport(UIKit)
public class AnnotationsContentView: UIView {
    public var annotations: [Annotation] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    override public init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
    }

    deinit {
        // Cleanup if needed
    }
}
#endif
