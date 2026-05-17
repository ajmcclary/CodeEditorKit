import CodeEditorPlatform
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension CodeEditorView {
    /// Returns the scroll view that hosts this editor on each platform.
    /// On macOS this is the enclosing `NSScrollView`; on iOS the text view
    /// is itself a `UIScrollView`.
    var crossPlatformEnclosingScrollView: PlatformScrollView? {
        #if canImport(AppKit)
        return super.enclosingScrollView
        #else
        return self
        #endif
    }
}
