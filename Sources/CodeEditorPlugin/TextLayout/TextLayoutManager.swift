#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - TextLayoutManager

public class TextLayoutManager: NSTextLayoutManager {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Posted when the selected range of characters changes.
    public static let didChangeSelectionNotification = NSTextView.didChangeSelectionNotification
    #else
    /// Posted when the selected range of characters changes.
    public static let didChangeSelectionNotification = Notification
        .Name("CodeEditorView.didChangeSelectionNotification")
    #endif

    private static let needsBoundsWorkaround = testIfNeedsBoundsWorkaround()

    override public var textSelections: [NSTextSelection] {
        didSet {
            let notification = Notification(name: Self.didChangeSelectionNotification, object: self, userInfo: nil)
            NotificationCenter.default.post(notification)
        }
    }

    @objc override public dynamic var usageBoundsForTextContainer: CGRect {
        var rect = super.usageBoundsForTextContainer
        if Self.needsBoundsWorkaround {
            // FB13290979: NSTextContainer.lineFragmentPadding does not affect end of the fragment usageBoundsForTextContainer rectangle
            // https://gist.github.com/krzyzanowskim/7adc5ee66be68df2f76b9752476aadfb
            // Changed in macOS 14 https://developer.apple.com/documentation/macos-release-notes/appkit-release-notes-for-macos-14#TextKit-API-Coordinate-System-Changes
            //   NSTextLineFragment.typographicBounds.size.width doesn’t contain NSTextContainer.lineFragmentPadding
            rect.size.width += textContainer?.lineFragmentPadding ?? 0
        }
        return rect
    }

    deinit {
        // Cleanup if needed
    }
}

/// Changed in macOS 14 https://developer.apple.com/documentation/macos-release-notes/appkit-release-notes-for-macos-14#TextKit-API-Coordinate-System-Changes
private func testIfNeedsBoundsWorkaround() -> Bool {
    if #available(macOS 14, iOS 17, *) {
        return true
    }

    return false
}
