//  Created by Claude Code
//  Data source protocol for annotations

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Data source for text annotations
public protocol STAnnotationsDataSource: AnyObject {
    /// Returns the annotations for the given text range
    func annotations(for textRange: NSTextRange) -> [STAnnotation]
    
    /// All annotations
    var textViewAnnotations: [STTextViewAnnotation] { get }
    
    /// Create a view for the given annotation
    func textView(_ textView: STTextView, viewForLineAnnotation annotation: STTextViewAnnotation, textLineFragment: NSTextLineFragment, proposedViewFrame: CGRect) -> NSView?
}