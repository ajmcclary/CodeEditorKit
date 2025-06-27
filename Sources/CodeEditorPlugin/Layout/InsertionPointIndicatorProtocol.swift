#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@preconcurrency import AppKit

/// Custom insertion point indicator view. Optional.
public protocol InsertionPointIndicatorProtocol: NSView {
    var insertionPointColor: NSColor { get set }

    func blinkStart()
    func blinkStop()
}

#elseif canImport(UIKit)
import UIKit

/// Custom insertion point indicator view. Optional.
public protocol InsertionPointIndicatorProtocol: UIView {
    var insertionPointColor: UIColor { get set }

    func blinkStart()
    func blinkStop()
}
#endif
