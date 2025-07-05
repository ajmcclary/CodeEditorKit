import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

// MARK: - LineHighlightView

/// View for highlighting the current line
@MainActor
public class LineHighlightView: NSView {
    public var highlightColor: PlatformColor = PlatformColors.controlAccentColor.withAlphaComponent(0.1) {
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

#elseif canImport(UIKit)
import UIKit

// MARK: - LineHighlightView (iOS Stub)

/// Stub implementation for iOS
public class LineHighlightView: UIView {
    public var highlightColor: PlatformColor = PlatformColors.tintColor.withAlphaComponent(0.1) {
        didSet {
            backgroundColor = highlightColor
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
        backgroundColor = highlightColor
    }

    deinit {
        // Cleanup if needed
    }
}
#endif
