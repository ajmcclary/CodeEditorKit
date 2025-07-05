import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

// MARK: - InsertionPointView

/// View representing the text insertion point (cursor)
@MainActor
public class InsertionPointView: NSView {
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
        backgroundColor = PlatformColors.label
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        wantsLayer = true
        layer?.backgroundColor = PlatformColors.label.cgColor
        #endif
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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

// MARK: - InsertionPointView (iOS Stub)

/// Stub implementation for iOS
@MainActor
public class InsertionPointView: UIView {
    override public init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .label
    }

    deinit {
        // Cleanup if needed
    }
}
#endif
