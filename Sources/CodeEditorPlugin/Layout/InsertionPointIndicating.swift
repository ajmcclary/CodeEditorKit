#if canImport(AppKit)
@preconcurrency import AppKit

/// Custom insertion point indicator view. Optional.
public protocol InsertionPointIndicating: NSView {
    var insertionPointColor: PlatformColor { get set }

    func blinkStart()
    func blinkStop()
}

#elseif canImport(UIKit)
import UIKit

/// Custom insertion point indicator view. Optional.
public protocol InsertionPointIndicating: UIView {
    var insertionPointColor: PlatformColor { get set }

    func blinkStart()
    func blinkStop()
}
#endif
