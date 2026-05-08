import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - TextKitBridge
//
// As of 0.2.0 the framework is TextKit2-only. The bridge no longer chooses
// between TextKit1 and TextKit2 — its purpose now is to provide a single
// `NSRange ↔ NSTextRange` and TextKit2 layout convenience surface so call
// sites don't need to repeat the location-translation boilerplate.

/// Unified TextKit2-only convenience surface for editor operations.
@MainActor
final class TextKitBridge {
    // MARK: - Properties

    private weak var textView: PlatformTextView?
    private let capabilities: PlatformCapabilities

    /// Reported TextKit version. Always `.textKit2` since 0.2.0; preserved as
    /// an enum for binary-compatible debug output.
    enum Version {
        case textKit2

        var description: String { "TextKit 2" }
    }

    var version: Version { .textKit2 }

    // MARK: - Initialization

    /// Creates a TextKitBridge instance.
    /// - Parameters:
    ///   - textView: The text view to bridge.
    ///   - capabilities: Platform capabilities (defaults to shared instance).
    init(textView: PlatformTextView, capabilities: PlatformCapabilities? = nil) {
        self.textView = textView
        self.capabilities = capabilities ?? CodeEditorDependencies.makePlatformCapabilities()
    }

    // MARK: - Text Storage Access

    /// Get the text storage.
    var textStorage: NSTextStorage? {
        textView?.textStorage
    }

    /// Get the text content storage.
    var textContentStorage: NSTextContentStorage? {
        #if canImport(AppKit)
        return textView?.textContentStorage
        #else
        if let codeEditorView = textView as? CodeEditorView {
            return codeEditorView.textContentStorage
        }
        return nil
        #endif
    }

    // MARK: - Layout Management

    /// Perform layout for a specific range.
    func ensureLayout(for range: NSRange) {
        guard let textLayoutManager = textView?.textLayoutManager else { return }
        if let textRange = textRangeFromNSRange(range) {
            textLayoutManager.ensureLayout(for: textRange)
        }
    }

    // MARK: - Range Conversion

    /// Convert NSRange to NSTextRange.
    func textRangeFromNSRange(_ nsRange: NSRange) -> NSTextRange? {
        guard let textLayoutManager = textView?.textLayoutManager,
              let textContentManager = textLayoutManager.textContentManager else {
            return nil
        }

        guard let startLocation = textContentManager.location(textContentManager.documentRange.location, offsetBy: nsRange.location) else {
            return nil
        }

        guard let endLocation = textContentManager.location(startLocation, offsetBy: nsRange.length) else {
            return nil
        }

        return NSTextRange(location: startLocation, end: endLocation)
    }

    /// Convert NSTextRange to NSRange.
    func nsRangeFromTextRange(_ textRange: NSTextRange) -> NSRange? {
        guard let textLayoutManager = textView?.textLayoutManager,
              let textContentManager = textLayoutManager.textContentManager else {
            return nil
        }

        let startOffset = textContentManager.offset(from: textContentManager.documentRange.location, to: textRange.location)
        let endOffset = textContentManager.offset(from: textContentManager.documentRange.location, to: textRange.endLocation)

        return NSRange(location: startOffset, length: Int(endOffset - startOffset))
    }

    // MARK: - Text Attributes

    /// Apply attributes to a range.
    func addAttributes(_ attributes: [NSAttributedString.Key: Any], range: NSRange) {
        guard let textStorage else { return }

        textStorage.beginEditing()
        textStorage.addAttributes(attributes, range: range)
        textStorage.endEditing()

        ensureLayout(for: range)
    }

    /// Remove attributes from a range.
    func removeAttributes(_ attributeKeys: [NSAttributedString.Key], range: NSRange) {
        guard let textStorage else { return }

        textStorage.beginEditing()
        for key in attributeKeys {
            textStorage.removeAttribute(key, range: range)
        }
        textStorage.endEditing()

        ensureLayout(for: range)
    }

    // MARK: - Layout Information

    /// Get line fragments for a range.
    func enumerateLineFragments(in range: NSRange, using block: @escaping (CGRect, NSRange) -> Void) {
        guard let textLayoutManager = textView?.textLayoutManager,
              let textRange = textRangeFromNSRange(range) else { return }

        textLayoutManager.enumerateTextLayoutFragments(from: textRange.location) { fragment in
            let frame = fragment.layoutFragmentFrame
            let fragmentRange = fragment.rangeInElement
            if let nsRange = self.nsRangeFromTextRange(fragmentRange) {
                block(frame, nsRange)
            }
            return fragment.rangeInElement.endLocation.compare(textRange.endLocation) == .orderedAscending
        }
    }

    // MARK: - Viewport Management

    /// Get the visible range of text.
    var visibleRange: NSRange? {
        guard let textLayoutManager = textView?.textLayoutManager,
              let textView else { return nil }

        #if canImport(AppKit)
        let visibleRect = textView.visibleRect
        #elseif canImport(UIKit)
        let contentOffset = textView.contentOffset
        let textContainerInset = textView.textContainerInset
        let bounds = textView.bounds
        let visibleRect = CGRect(
            x: 0,
            y: contentOffset.y,
            width: bounds.width - textContainerInset.left - textContainerInset.right,
            height: bounds.height
        )
        #endif

        var firstRange: NSRange?
        var lastRange: NSRange?

        textLayoutManager.enumerateTextLayoutFragments(from: textLayoutManager.documentRange.location) { fragment in
            let frame = fragment.layoutFragmentFrame

            if frame.intersects(visibleRect) {
                let fragmentRange = fragment.rangeInElement
                if let nsRange = self.nsRangeFromTextRange(fragmentRange) {
                    if firstRange == nil {
                        firstRange = nsRange
                    }
                    lastRange = nsRange
                }
            }

            return frame.minY <= visibleRect.maxY
        }

        if let first = firstRange, let last = lastRange {
            return NSRange(location: first.location, length: NSMaxRange(last) - first.location)
        }

        return nil
    }

    // MARK: - Cursor and Layout Calculations

    /// Get the cursor rect for a given character index.
    func cursorRect(at characterIndex: Int) -> CGRect? {
        guard let textLayoutManager = textView?.textLayoutManager,
              let textContentManager = textLayoutManager.textContentManager else { return nil }

        guard let location = textContentManager.location(textContentManager.documentRange.location, offsetBy: characterIndex) else {
            return nil
        }

        var cursorRect: CGRect?
        textLayoutManager.enumerateTextLayoutFragments(from: location) { fragment in
            if let lineFragment = fragment.textLineFragments.first {
                let lineOrigin = lineFragment.typographicBounds.origin
                let lineHeight = lineFragment.typographicBounds.height
                let glyphOrigin = lineFragment.glyphOrigin

                cursorRect = CGRect(
                    x: fragment.layoutFragmentFrame.origin.x + lineOrigin.x + glyphOrigin.x,
                    y: fragment.layoutFragmentFrame.origin.y + lineOrigin.y,
                    width: 1,
                    height: lineHeight
                )
            }
            return false
        }

        return cursorRect
    }

    /// Get the bounding rect for a character range.
    func boundingRect(for range: NSRange) -> CGRect? {
        guard let textRange = textRangeFromNSRange(range),
              let textLayoutManager = textView?.textLayoutManager else { return nil }

        var boundingRect = CGRect.null

        textLayoutManager.enumerateTextLayoutFragments(from: textRange.location) { fragment in
            let fragmentRange = fragment.rangeInElement

            if fragmentRange.location.compare(textRange.endLocation) == .orderedAscending &&
               fragmentRange.endLocation.compare(textRange.location) == .orderedDescending {
                if boundingRect.isNull {
                    boundingRect = fragment.layoutFragmentFrame
                } else {
                    boundingRect = boundingRect.union(fragment.layoutFragmentFrame)
                }
            }

            return fragmentRange.endLocation.compare(textRange.endLocation) == .orderedAscending
        }

        return boundingRect.isNull ? nil : boundingRect
    }

    // MARK: - Attributes Management

    /// Set rendering attributes on TextKit2 layout fragments for the given range.
    /// (Replaces TextKit1's `setTemporaryAttributes` API.)
    func setTemporaryAttributes(_: [NSAttributedString.Key: Any], for range: NSRange) {
        guard let textRange = textRangeFromNSRange(range),
              let textLayoutManager = textView?.textLayoutManager else { return }

        textLayoutManager.enumerateTextLayoutFragments(from: textRange.location) { fragment in
            fragment.invalidateLayout()
            return fragment.rangeInElement.endLocation.compare(textRange.endLocation) == .orderedAscending
        }

        textLayoutManager.ensureLayout(for: textRange)
    }

    /// Remove temporary/rendering attributes for a range.
    func removeTemporaryAttributes(for range: NSRange) {
        setTemporaryAttributes([:], for: range)
    }

    // MARK: - Line Height Calculation

    /// Calculate line height for a given font.
    func calculateLineHeight(for font: PlatformFont) -> CGFloat {
        TextMetricsCalculator.calculateLineHeight(for: font)
    }

    // MARK: - Text Container Properties

    /// Get or set the text container size.
    var textContainerSize: CGSize {
        get {
            #if canImport(AppKit)
            return textView?.textContainer?.containerSize ?? .zero
            #else
            return textView?.textContainer.size ?? .zero
            #endif
        }
        set {
            #if canImport(AppKit)
            textView?.textContainer?.containerSize = newValue
            #else
            textView?.textContainer.size = newValue
            #endif
        }
    }

    /// Get or set whether width tracks the text view (AppKit-only; iOS always tracks).
    var widthTracksTextView: Bool {
        get {
            #if canImport(AppKit)
            return textView?.textContainer?.widthTracksTextView ?? false
            #else
            return true
            #endif
        }
        set {
            #if canImport(AppKit)
            textView?.textContainer?.widthTracksTextView = newValue
            #endif
        }
    }

    // MARK: - Performance Optimization

    /// Optimize layout for a specific file size.
    func optimizeForFileSize(_ characterCount: Int) {
        guard let textLayoutManager = textView?.textLayoutManager else { return }
        if characterCount > 50_000 {
            textLayoutManager.limitsLayoutForSuspiciousContents = true
        }
    }

    // MARK: - Debug Information

    /// Get debug information about the current TextKit configuration.
    var debugInfo: String {
        var info = "TextKit Configuration:\n"
        info += "  Version: \(version.description)\n"
        info += "  Text Length: \(textStorage?.length ?? 0) characters\n"
        info += "  TextLayoutManager: \(textView?.textLayoutManager != nil)\n"
        info += "  TextContentStorage: \(textContentStorage != nil)\n"
        return info
    }

    deinit {
        // ARC handles cleanup
    }
}

// MARK: - TextKitBridge Factory

extension PlatformTextView {
    /// Create a TextKitBridge for this text view.
    func createTextKitBridge() -> TextKitBridge {
        TextKitBridge(textView: self)
    }
}
