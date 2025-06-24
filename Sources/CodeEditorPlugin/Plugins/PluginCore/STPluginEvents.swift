import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - STPluginEvents

public class STPluginEvents {
    var willChangeTextHandler: ((_ affectedRange: NSTextRange) -> Void)?
    var didChangeTextHandler: ((_ affectedRange: NSTextRange, _ replacementString: String?) -> Void)?
    var shouldChangeTextHandler: ((_ affectedCharRange: NSTextRange, _ replacementString: String?) -> Bool)?

    #if canImport(UIKit)
    var onContextMenuHandler: ((_ location: NSTextLocation, _ contentManager: NSTextContentManager) -> UIMenu)?
    #elseif canImport(AppKit)
    var onContextMenuHandler: ((_ location: NSTextLocation, _ contentManager: NSTextContentManager) -> NSMenu)?
    #endif

    var didLayoutViewportHandler: ((_ visibleRange: NSTextRange?) -> Void)?

    @discardableResult
    public func onWillChangeText(_ handler: @escaping (_ affectedRange: NSTextRange) -> Void) -> Self {
        willChangeTextHandler = handler
        return self
    }

    @discardableResult
    public func onDidChangeText(
        _ handler: @escaping (
            _ affectedRange: NSTextRange,
            _ replacementString: String?
        ) -> Void
    ) -> Self {
        didChangeTextHandler = handler
        return self
    }

    @discardableResult
    public func shouldChangeText(
        _ handler: @escaping (
            _ affectedCharRange: NSTextRange,
            _ replacementString: String?
        ) -> Bool
    ) -> Self {
        shouldChangeTextHandler = handler
        return self
    }

    #if canImport(UIKit)
    @discardableResult
    public func onContextMenu(_ handler: @escaping (
        _ location: NSTextLocation,
        _ contentManager: NSTextContentManager
    ) -> UIMenu) -> Self {
        onContextMenuHandler = handler
        return self
    }

    #elseif canImport(AppKit)
    @discardableResult
    public func onContextMenu(_ handler: @escaping (
        _ location: NSTextLocation,
        _ contentManager: NSTextContentManager
    ) -> NSMenu) -> Self {
        onContextMenuHandler = handler
        return self
    }
    #endif

    @discardableResult
    public func onDidLayoutViewport(_ handler: @escaping (_ visibleRange: NSTextRange?) -> Void) -> Self {
        didLayoutViewportHandler = handler
        return self
    }

    deinit {
        // Cleanup if needed
    }
}
