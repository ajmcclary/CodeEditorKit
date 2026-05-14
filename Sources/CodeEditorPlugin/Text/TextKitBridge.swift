import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - TextKitBridge
//
// As of 0.2.0 the framework is TextKit2-only. The bridge no longer chooses
// with the required TextKit2 surface — its purpose is to provide a single
// `NSRange ↔ NSTextRange` and TextKit2 layout convenience surface so call
// sites don't need to repeat the location-translation boilerplate.

/// Unified TextKit2-only convenience surface for editor operations.
@MainActor
final class TextKitBridge {
    // MARK: - Properties

    private static let logger = CrossPlatformLogger.logger(
        subsystem: "com.codeeditor.plugin",
        category: "TextKitBridge"
    )

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

    // MARK: - TK2-Safe Document Access
    //
    // These accessors funnel reads through `textContentStorage?.textStorage`
    // — the content-manager-owned NSTextStorage — instead of
    // `textView?.textStorage`, which triggers Apple's TK1 compatibility shim
    // and clears `textLayoutManager`. All framework code that previously read
    // `view.textStorage` should go through these.

    /// Internal-only `NSTextStorage` accessor. Prefers the TK2-safe path
    /// (`textContentStorage?.textStorage`); when the view has already been
    /// coerced to TK1 by an external trigger (e.g., the NSRulerView gutter's
    /// `drawHashMarksAndLabels` reading `textView.layoutManager`), the TK2
    /// content storage is nil and we fall back to the legacy
    /// `textView.textStorage` property. Reading that property *after*
    /// coercion has already fired doesn't re-trigger the shim — it just
    /// returns the active NSTextStorage. This lets the framework's
    /// highlighting and persistent-attribute writes keep working even when
    /// the view is operating in TK1 mode at runtime.
    private var safeTextStorage: NSTextStorage? {
        if let tk2Storage = textContentStorage?.textStorage {
            return tk2Storage
        }
        return textView?.textStorage
    }

    /// UTF-16 length of the document. Returns 0 when the TK2 stack is not yet ready.
    var documentLength: Int {
        safeTextStorage?.length ?? 0
    }

    /// Full document string. Returns "" when the TK2 stack is not yet ready.
    var documentString: String {
        safeTextStorage?.string ?? ""
    }

    /// Substring for a UTF-16 range. Returns nil for empty ranges or when
    /// the TK2 stack is not yet ready. Clamps `range` to document bounds.
    func substring(in range: NSRange) -> String? {
        guard let storage = safeTextStorage else { return nil }
        let length = storage.length
        let lower = max(0, min(range.location, length))
        let upper = max(lower, min(range.location + range.length, length))
        let clamped = NSRange(location: lower, length: upper - lower)
        guard clamped.length > 0 else { return nil }
        // swiftlint:disable:next legacy_objc_type
        return (storage.string as NSString).substring(with: clamped)
    }

    /// Attributed substring for a UTF-16 range. Returns nil for empty ranges
    /// or when the TK2 stack is not yet ready.
    func attributedSubstring(in range: NSRange) -> NSAttributedString? {
        guard let storage = safeTextStorage else { return nil }
        let length = storage.length
        let lower = max(0, min(range.location, length))
        let upper = max(lower, min(range.location + range.length, length))
        let clamped = NSRange(location: lower, length: upper - lower)
        guard clamped.length > 0 else { return nil }
        return storage.attributedSubstring(from: clamped)
    }

    // MARK: - TK2-Safe Content Mutation

    /// Replace characters in the given range with a plain string. No-op
    /// (with one logged warning) when the TK2 stack is not yet ready.
    ///
    /// Callers that need to batch multiple mutations should wrap their
    /// calls in `NSTextContentManager.performEditingTransaction(_:)`; this
    /// method does NOT open its own transaction (nesting trips
    /// `NSTextContentStorageBreakOnEnumerateWhileEditing` per the existing
    /// guard in `CodeEditorView+SyntaxHighlightingExtensions.swift`).
    func replaceCharacters(in range: NSRange, with string: String) {
        guard let storage = safeTextStorage else {
            Self.logger.error("replaceCharacters: TextKit 2 stack not ready; mutation dropped")
            return
        }
        storage.replaceCharacters(in: range, with: string)
    }

    /// Replace characters in the given range with an attributed string.
    func replaceCharacters(in range: NSRange, with attributedString: NSAttributedString) {
        guard let storage = safeTextStorage else {
            Self.logger.error("replaceCharacters: TextKit 2 stack not ready; mutation dropped")
            return
        }
        storage.replaceCharacters(in: range, with: attributedString)
    }

    // MARK: - TK2-Safe Persistent Attributes
    //
    // These methods mutate the content-manager-owned NSTextStorage's
    // attributes. Use them ONLY for attributes that must survive serialization
    // or that other code reads back via
    // `textStorage.attribute(_:at:effectiveRange:)`:
    //   - fold indicator marks (read by the gutter)
    //   - search-result highlighting
    //   - layout-affecting attributes (font, baseline, paragraph style)
    //   - the temporary-attributes store
    //
    // For syntax-highlighting colors, use `addAttributes(_:range:)` instead
    // (rendering attributes — non-destructive, TK2-native).

    /// Apply persistent text-storage attributes to a range.
    func addPersistentAttributes(_ attributes: [NSAttributedString.Key: Any], range: NSRange) {
        guard let storage = safeTextStorage else { return }
        storage.beginEditing()
        storage.addAttributes(attributes, range: range)
        storage.endEditing()
        ensureLayout(for: range)
    }

    /// Remove a persistent text-storage attribute key from a range.
    func removePersistentAttribute(_ key: NSAttributedString.Key, range: NSRange) {
        guard let storage = safeTextStorage else { return }
        storage.beginEditing()
        storage.removeAttribute(key, range: range)
        storage.endEditing()
        ensureLayout(for: range)
    }

    /// Remove multiple persistent text-storage attribute keys from a range.
    func removePersistentAttributes(_ keys: [NSAttributedString.Key], range: NSRange) {
        guard let storage = safeTextStorage else { return }
        storage.beginEditing()
        for key in keys {
            storage.removeAttribute(key, range: range)
        }
        storage.endEditing()
        ensureLayout(for: range)
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

    // MARK: - Rendering Attributes

    /// Apply rendering attributes for syntax highlighting (non-destructive
    /// when TK2 is live). Attributes do NOT persist into the underlying
    /// NSAttributedString — they're applied per-fragment during layout.
    ///
    /// When the view has been coerced to TK1 (e.g., by the NSRulerView
    /// gutter), `textLayoutManager` is nil and this method falls back to
    /// text-storage attributes so highlighting still renders.
    ///
    /// Use this for syntax highlighting colors. For attributes that must
    /// persist regardless of TK state (fold marks, search highlights,
    /// layout-affecting attributes), use `addPersistentAttributes(_:range:)`.
    func addAttributes(_ attributes: [NSAttributedString.Key: Any], range: NSRange) {
        if let textLayoutManager = textView?.textLayoutManager,
           let textRange = textRangeFromNSRange(range) {
            textLayoutManager.setRenderingAttributes(attributes, for: textRange)
            return
        }
        // TK1 fallback: apply as text-storage attributes.
        guard let storage = safeTextStorage else { return }
        storage.beginEditing()
        storage.addAttributes(attributes, range: range)
        storage.endEditing()
    }

    /// Remove rendering attribute keys from a range. Counterpart to
    /// `addAttributes(_:range:)`. Falls back to text-storage attribute
    /// removal when TK2 is not available.
    func removeAttributes(_ attributeKeys: [NSAttributedString.Key], range: NSRange) {
        if let textLayoutManager = textView?.textLayoutManager,
           let textRange = textRangeFromNSRange(range) {
            // `setRenderingAttributes` replaces (not merges) the attribute set
            // for a range. To strip specific keys, enumerate existing
            // rendering attributes, filter the unwanted keys, and re-apply
            // the remainder per fragment.
            var fragments: [(NSTextRange, [NSAttributedString.Key: Any])] = []
            textLayoutManager.enumerateRenderingAttributes(
                from: textRange.location,
                reverse: false
            ) { _, attrs, attrRange in
                guard attrRange.intersects(textRange) else { return true }
                var filtered = attrs
                for key in attributeKeys {
                    filtered.removeValue(forKey: key)
                }
                fragments.append((attrRange, filtered))
                return attrRange.endLocation.compare(textRange.endLocation) == .orderedAscending
            }
            for (subRange, attrs) in fragments {
                textLayoutManager.setRenderingAttributes(attrs, for: subRange)
            }
            return
        }
        // TK1 fallback: remove from text-storage.
        guard let storage = safeTextStorage else { return }
        storage.beginEditing()
        for key in attributeKeys {
            storage.removeAttribute(key, range: range)
        }
        storage.endEditing()
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
    /// Applies temporary attributes through TextKit2 APIs.
    func setTemporaryAttributes(_ attributes: [NSAttributedString.Key: Any], for range: NSRange) {
        guard let textRange = textRangeFromNSRange(range),
              let textLayoutManager = textView?.textLayoutManager else { return }

        textLayoutManager.setRenderingAttributes(attributes, for: textRange)
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
        info += "  Text Length: \(documentLength) characters\n"
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
