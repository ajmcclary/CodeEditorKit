import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - LineHighlightView

/// View for highlighting the current line
public class LineHighlightView: NSView {
    public var highlightColor: NSColor = .controlAccentColor.withAlphaComponent(0.1) {
        didSet {
            wantsLayer = true
            layer?.backgroundColor = highlightColor.cgColor
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
        layer?.backgroundColor = highlightColor.cgColor
    }

    /// Text views need a flipped coordinate system on macOS
    override public var isFlipped: Bool {
        true
    }

    deinit {
        // Cleanup if needed
    }
}
