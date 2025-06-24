import Foundation
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

extension NSParagraphStyle {
    /// Custom line height multiple property for STTextView
    var stLineHeightMultiple: CGFloat {
        lineHeightMultiple > 0 ? lineHeightMultiple : 1.0
    }
}
