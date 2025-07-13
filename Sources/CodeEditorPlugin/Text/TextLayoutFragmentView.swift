import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

// MARK: - TextLayoutFragmentView

/// View for rendering text layout fragments
public class TextLayoutFragmentView: NSView {
    public var layoutFragment: NSTextLayoutFragment? {
        didSet {
            needsDisplay = true
        }
    }

    public init(layoutFragment: NSTextLayoutFragment?, frame frameRect: NSRect) {
        self.layoutFragment = layoutFragment
        super.init(frame: frameRect)
        setup()
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        wantsLayer = true
        #endif
        #if canImport(UIKit)
        backgroundColor = .clear
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        // backgroundColor not available on NSView
        #endif
    }

    #if canImport(UIKit)

    #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let layoutFragment else {
            return
        }

        // Get the graphics context
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        // Draw the layout fragment
        layoutFragment.draw(at: .zero, in: context)
    }

    /// Text views need a flipped coordinate system on macOS
    override public var isFlipped: Bool {
        true
    }
    #endif

    deinit {
        // Cleanup if needed
    }
}

#elseif canImport(UIKit)
import UIKit

// MARK: - TextLayoutFragmentView (iOS Stub)

/// Stub implementation for iOS
public class TextLayoutFragmentView: UIView {
    public var layoutFragment: NSTextLayoutFragment? {
        didSet {
            setNeedsDisplay()
        }
    }

    public init(layoutFragment: NSTextLayoutFragment?, frame frameRect: CGRect) {
        self.layoutFragment = layoutFragment
        super.init(frame: frameRect)
        setup()
    }

    override public init(frame frameRect: CGRect) {
        self.layoutFragment = nil
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        self.layoutFragment = nil
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
