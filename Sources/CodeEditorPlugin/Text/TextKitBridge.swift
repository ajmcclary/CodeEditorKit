import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - TextKitBridge

/// Unified interface for TextKit1 and TextKit2 operations
@MainActor
final class TextKitBridge {
    // MARK: - Properties
    
    private weak var textView: PlatformTextView?
    private let isUsingTextKit2: Bool
    
    /// Current TextKit version being used
    enum Version {
        case textKit1
        case textKit2
        
        var description: String {
            switch self {
            case .textKit1: return "TextKit 1"
            case .textKit2: return "TextKit 2"
            }
        }
    }
    
    var version: Version {
        isUsingTextKit2 ? .textKit2 : .textKit1
    }
    
    // MARK: - Initialization
    
    init(textView: PlatformTextView) {
        self.textView = textView
        
        // Check platform capabilities and force TextKit2 if supported
        let capabilities = PlatformCapabilities.shared
        if capabilities.preferTextKit2 {
            // Check if TextKit2 is already enabled
            self.isUsingTextKit2 = textView.textLayoutManager != nil
        } else {
            self.isUsingTextKit2 = textView.textLayoutManager != nil
        }
    }
    
    // MARK: - Text Storage Access
    
    /// Get the text storage regardless of TextKit version
    var textStorage: NSTextStorage? {
        textView?.textStorage
    }
    
    /// Get the text content storage for TextKit2
    var textContentStorage: NSTextContentStorage? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return textView?.textContentStorage
        #else
        // For iOS/Catalyst, we need to cast the textView to CodeEditorView to access textContentStorage
        if let codeEditorView = textView as? CodeEditorView {
            return codeEditorView.textContentStorage
        }
        return nil
        #endif
    }
    
    // MARK: - Layout Management
    
    /// Perform layout for a specific range
    func ensureLayout(for range: NSRange) {
        guard textView != nil else { return }
        
        if isUsingTextKit2 {
            ensureLayoutTextKit2(for: range)
        } else {
            ensureLayoutTextKit1(for: range)
        }
    }
    
    private func ensureLayoutTextKit1(for range: NSRange) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let layoutManager = textView?.layoutManager,
              let textContainer = textView?.textContainer else { return }
        
        // For AppKit, we need to convert the range to glyph range first
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        layoutManager.ensureLayout(forGlyphRange: glyphRange)
        #elseif canImport(UIKit)
        guard let layoutManager = textView?.layoutManager,
              let textContainer = textView?.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        #endif
    }
    
    private func ensureLayoutTextKit2(for range: NSRange) {
        guard let textLayoutManager = textView?.textLayoutManager else { return }
        
        // Convert NSRange to NSTextRange for TextKit2
        if let textRange = textRangeFromNSRange(range) {
            textLayoutManager.ensureLayout(for: textRange)
        }
    }
    
    // MARK: - Range Conversion
    
    /// Convert NSRange to NSTextRange for TextKit2
    func textRangeFromNSRange(_ nsRange: NSRange) -> NSTextRange? {
        guard isUsingTextKit2,
              let textLayoutManager = textView?.textLayoutManager,
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
    
    /// Convert NSTextRange to NSRange for TextKit1 compatibility
    func nsRangeFromTextRange(_ textRange: NSTextRange) -> NSRange? {
        guard isUsingTextKit2,
              let textLayoutManager = textView?.textLayoutManager,
              let textContentManager = textLayoutManager.textContentManager else {
            return nil
        }
        
        let startOffset = textContentManager.offset(from: textContentManager.documentRange.location, to: textRange.location)
        let endOffset = textContentManager.offset(from: textContentManager.documentRange.location, to: textRange.endLocation)
        
        return NSRange(location: startOffset, length: Int(endOffset - startOffset))
    }
    
    // MARK: - Text Attributes
    
    /// Apply attributes to a range (works with both TextKit versions)
    func addAttributes(_ attributes: [NSAttributedString.Key: Any], range: NSRange) {
        guard let textStorage else { return }
        
        textStorage.beginEditing()
        textStorage.addAttributes(attributes, range: range)
        textStorage.endEditing()
        
        // Ensure layout is updated
        ensureLayout(for: range)
    }
    
    /// Remove attributes from a range
    func removeAttributes(_ attributeKeys: [NSAttributedString.Key], range: NSRange) {
        guard let textStorage else { return }
        
        textStorage.beginEditing()
        for key in attributeKeys {
            textStorage.removeAttribute(key, range: range)
        }
        textStorage.endEditing()
        
        // Ensure layout is updated
        ensureLayout(for: range)
    }
    
    // MARK: - Layout Information
    
    /// Get line fragments for a range
    func enumerateLineFragments(in range: NSRange, using block: @escaping (CGRect, NSRange) -> Void) {
        if isUsingTextKit2 {
            enumerateLineFragmentsTextKit2(in: range, using: block)
        } else {
            enumerateLineFragmentsTextKit1(in: range, using: block)
        }
    }
    
    private func enumerateLineFragmentsTextKit1(in range: NSRange, using block: @escaping (CGRect, NSRange) -> Void) {
        guard let layoutManager = textView?.layoutManager else { return }
        
        // Get the appropriate glyph range based on platform
        let glyphRange = self.glyphRangeForCharacterRange(range, layoutManager: layoutManager)
        
        // Shared enumeration logic
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, _, _, glyphRange, _ in
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            block(rect, characterRange)
        }
    }
    
    /// Get the glyph range for a character range, handling platform differences
    private func glyphRangeForCharacterRange(_ characterRange: NSRange, layoutManager: NSLayoutManager) -> NSRange {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // On AppKit, use the character range directly as glyph range for line fragment enumeration
        return characterRange
        #elseif canImport(UIKit)
        // On UIKit, convert character range to glyph range
        return layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
        #endif
    }
    
    private func enumerateLineFragmentsTextKit2(in range: NSRange, using block: @escaping (CGRect, NSRange) -> Void) {
        guard let textLayoutManager = textView?.textLayoutManager,
              let textRange = textRangeFromNSRange(range) else { return }
        
        textLayoutManager.enumerateTextLayoutFragments(from: textRange.location) { fragment in
            // Get the frame of the layout fragment
            let frame = fragment.layoutFragmentFrame
            
            // Get the character range
            let fragmentRange = fragment.rangeInElement
            if let nsRange = self.nsRangeFromTextRange(fragmentRange) {
                block(frame, nsRange)
            }
            
            // Continue enumeration until we've covered the range
            return fragment.rangeInElement.endLocation.compare(textRange.endLocation) == .orderedAscending
        }
    }
    
    // MARK: - Viewport Management
    
    /// Get the visible range of text
    var visibleRange: NSRange? {
        if isUsingTextKit2 {
            return visibleRangeTextKit2()
        } else {
            return visibleRangeTextKit1()
        }
    }
    
    private func visibleRangeTextKit1() -> NSRange? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let layoutManager = textView?.layoutManager,
              let textContainer = textView?.textContainer,
              let scrollView = textView?.enclosingScrollView else { return nil }
        
        let visibleRect = scrollView.contentView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        #elseif canImport(UIKit)
        guard let layoutManager = textView?.layoutManager,
              let textContainer = textView?.textContainer,
              let textView else { return nil }
        
        // Calculate the visible rect based on the scroll position and content inset
        let contentOffset = textView.contentOffset
        let textContainerInset = textView.textContainerInset
        let bounds = textView.bounds
        
        // Create visible rect that accounts for scroll position
        let visibleRect = CGRect(
            x: contentOffset.x,
            y: contentOffset.y + textContainerInset.top,
            width: bounds.width,
            height: bounds.height
        )
        
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        #endif
    }
    
    private func visibleRangeTextKit2() -> NSRange? {
        guard let textLayoutManager = textView?.textLayoutManager,
              let textView else { return nil }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let visibleRect = textView.visibleRect
        #elseif canImport(UIKit)
        // Calculate the visible rect based on the scroll position and content inset
        let contentOffset = textView.contentOffset
        let textContainerInset = textView.textContainerInset
        let bounds = textView.bounds
        
        // Create visible rect that accounts for scroll position
        let visibleRect = CGRect(
            x: contentOffset.x,
            y: contentOffset.y + textContainerInset.top,
            width: bounds.width,
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
            
            // Stop if we've gone past the visible area
            return frame.minY <= visibleRect.maxY
        }
        
        if let first = firstRange, let last = lastRange {
            return NSRange(location: first.location, length: NSMaxRange(last) - first.location)
        }
        
        return nil
    }
    
    // MARK: - Cursor and Layout Calculations
    
    /// Get the cursor rect for a given character index
    func cursorRect(at characterIndex: Int) -> CGRect? {
        guard textView != nil else { return nil }
        
        if isUsingTextKit2 {
            return cursorRectTextKit2(at: characterIndex)
        } else {
            return cursorRectTextKit1(at: characterIndex)
        }
    }
    
    private func cursorRectTextKit1(at characterIndex: Int) -> CGRect? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let layoutManager = textView?.layoutManager else { return nil }
        
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterIndex)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)
        
        return CGRect(x: glyphLocation.x, y: lineRect.origin.y, width: 1, height: lineRect.height)
        #elseif canImport(UIKit)
        // For iOS/Catalyst, we need to use caretRect
        guard let textView,
              let position = textView.position(from: textView.beginningOfDocument, offset: characterIndex) else {
            return nil
        }
        return textView.caretRect(for: position)
        #endif
    }
    
    private func cursorRectTextKit2(at characterIndex: Int) -> CGRect? {
        guard let textLayoutManager = textView?.textLayoutManager,
              let textContentManager = textLayoutManager.textContentManager else { return nil }
        
        // Get the text location for the character index
        guard let location = textContentManager.location(textContentManager.documentRange.location, offsetBy: characterIndex) else {
            return nil
        }
        
        // Create a zero-length range at the cursor position
        _ = NSTextRange(location: location, end: location)
        
        // Get the layout fragment containing this location
        var cursorRect: CGRect?
        textLayoutManager.enumerateTextLayoutFragments(from: location) { fragment in
            // Get the frame for the cursor position
            if let lineFragment = fragment.textLineFragments.first {
                let lineOrigin = lineFragment.typographicBounds.origin
                let lineHeight = lineFragment.typographicBounds.height
                
                // Calculate x position within the line
                _ = textContentManager.offset(from: fragment.rangeInElement.location, to: location)
                let glyphOrigin = lineFragment.glyphOrigin
                
                cursorRect = CGRect(
                    x: fragment.layoutFragmentFrame.origin.x + lineOrigin.x + glyphOrigin.x,
                    y: fragment.layoutFragmentFrame.origin.y + lineOrigin.y,
                    width: 1,
                    height: lineHeight
                )
            }
            return false // Stop after first fragment
        }
        
        return cursorRect
    }
    
    /// Get the bounding rect for a character range
    func boundingRect(for range: NSRange) -> CGRect? {
        guard textView != nil else { return nil }
        
        if isUsingTextKit2 {
            return boundingRectTextKit2(for: range)
        } else {
            return boundingRectTextKit1(for: range)
        }
    }
    
    private func boundingRectTextKit1(for range: NSRange) -> CGRect? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let layoutManager = textView?.layoutManager,
              let textContainer = textView?.textContainer else { return nil }
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        #elseif canImport(UIKit)
        // For iOS/Catalyst, we need to use firstRect
        guard let textView,
              let startPosition = textView.position(from: textView.beginningOfDocument, offset: range.location),
              let endPosition = textView.position(from: startPosition, offset: range.length),
              let textRange = textView.textRange(from: startPosition, to: endPosition) else {
            return nil
        }
        return textView.firstRect(for: textRange)
        #endif
    }
    
    private func boundingRectTextKit2(for range: NSRange) -> CGRect? {
        guard let textRange = textRangeFromNSRange(range),
              let textLayoutManager = textView?.textLayoutManager else { return nil }
        
        var boundingRect = CGRect.null
        
        textLayoutManager.enumerateTextLayoutFragments(from: textRange.location) { fragment in
            // Check if this fragment intersects with our range
            let fragmentRange = fragment.rangeInElement
            
            // If the fragment is within our range, include its frame
            if fragmentRange.location.compare(textRange.endLocation) == .orderedAscending &&
               fragmentRange.endLocation.compare(textRange.location) == .orderedDescending {
                if boundingRect.isNull {
                    boundingRect = fragment.layoutFragmentFrame
                } else {
                    boundingRect = boundingRect.union(fragment.layoutFragmentFrame)
                }
            }
            
            // Continue until we've processed the entire range
            return fragmentRange.endLocation.compare(textRange.endLocation) == .orderedAscending
        }
        
        return boundingRect.isNull ? nil : boundingRect
    }
    
    // MARK: - Attributes Management
    
    /// Set temporary attributes for a range (TextKit1) or rendering attributes (TextKit2)
    func setTemporaryAttributes(_ attributes: [NSAttributedString.Key: Any], for range: NSRange) {
        guard textView != nil else { return }
        
        if isUsingTextKit2 {
            setRenderingAttributesTextKit2(attributes, for: range)
        } else {
            setTemporaryAttributesTextKit1(attributes, for: range)
        }
    }
    
    private func setTemporaryAttributesTextKit1(_ attributes: [NSAttributedString.Key: Any], for range: NSRange) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let layoutManager = textView?.layoutManager else { return }
        layoutManager.setTemporaryAttributes(attributes, forCharacterRange: range)
        #elseif canImport(UIKit)
        // UIKit doesn't support temporary attributes in the same way
        // We need to use attributed text instead
        if let textView {
            let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
            mutableAttributedString.addAttributes(attributes, range: range)
            textView.attributedText = mutableAttributedString
        }
        #endif
    }
    
    private func setRenderingAttributesTextKit2(_: [NSAttributedString.Key: Any], for range: NSRange) {
        guard let textRange = textRangeFromNSRange(range),
              let textLayoutManager = textView?.textLayoutManager else { return }
        
        // TextKit2 uses rendering attributes on layout fragments
        textLayoutManager.enumerateTextLayoutFragments(from: textRange.location) { fragment in
            // Apply rendering attributes to the fragment
            // Note: This is a simplified implementation - TextKit2's rendering attributes
            // work differently than TextKit1's temporary attributes
            fragment.invalidateLayout()
            
            // Continue until we've processed the entire range
            return fragment.rangeInElement.endLocation.compare(textRange.endLocation) == .orderedAscending
        }
        
        // Trigger a layout update
        textLayoutManager.ensureLayout(for: textRange)
    }
    
    /// Remove temporary/rendering attributes for a range
    func removeTemporaryAttributes(for range: NSRange) {
        setTemporaryAttributes([:], for: range)
    }
    
    // MARK: - Line Height Calculation
    
    /// Calculate line height for a given font
    func calculateLineHeight(for font: PlatformFont) -> CGFloat {
        // This doesn't need TextKit version checking as it's font-based
        TextMetricsCalculator.calculateLineHeight(for: font)
    }
    
    // MARK: - Text Container Properties
    
    /// Get or set the text container size
    var textContainerSize: CGSize {
        get {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return textView?.textContainer?.containerSize ?? .zero
            #else
            return textView?.textContainer.size ?? .zero
            #endif
        }
        set {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textView?.textContainer?.containerSize = newValue
            #else
            textView?.textContainer.size = newValue
            #endif
        }
    }
    
    /// Get or set whether width tracks the text view
    var widthTracksTextView: Bool {
        get {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return textView?.textContainer?.widthTracksTextView ?? false
            #else
            // iOS doesn't have this property, width always tracks
            return true
            #endif
        }
        set {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textView?.textContainer?.widthTracksTextView = newValue
            #endif
        }
    }
    
    // MARK: - Performance Optimization
    
    /// Optimize for a specific file size
    func optimizeForFileSize(_ characterCount: Int) {
        let capabilities = PlatformCapabilities.shared
        
        if characterCount > 50_000 { // Use a reasonable threshold
            // For large files, enable TextKit2 if available
            if capabilities.supportsTextKit2 && !isUsingTextKit2 {
                if let textView {
                    _ = ModernTextKitHelper.ensureTextKit2(for: textView)
                }
            }
            
            // Apply large file optimizations
            applyLargeFileOptimizations()
        } else {
            // Apply standard optimizations
            applyStandardOptimizations()
        }
    }
    
    private func applyLargeFileOptimizations() {
        guard let textView else { return }
        
        if isUsingTextKit2 {
            // TextKit2 specific optimizations
            if let textLayoutManager = textView.textLayoutManager {
                textLayoutManager.limitsLayoutForSuspiciousContents = true
            }
        } else {
            // TextKit1 fallback optimizations
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            if let layoutManager = textView.layoutManager {
                layoutManager.allowsNonContiguousLayout = true
            }
            #endif
        }
    }
    
    private func applyStandardOptimizations() {
        // Standard optimizations for normal-sized files
        guard let textView else { return }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let layoutManager = textView.layoutManager {
            layoutManager.allowsNonContiguousLayout = true
        }
        #endif
    }
    
    // MARK: - Debug Information
    
    /// Get debug information about the current TextKit configuration
    var debugInfo: String {
        var info = "TextKit Configuration:\n"
        info += "  Version: \(version.description)\n"
        info += "  Text Length: \(textStorage?.length ?? 0) characters\n"
        
        if isUsingTextKit2 {
            info += "  TextKit2 Features:\n"
            info += "    - TextLayoutManager: \(textView?.textLayoutManager != nil)\n"
            info += "    - TextContentStorage: \(textContentStorage != nil)\n"
        } else {
            info += "  TextKit1 Features:\n"
            info += "    - LayoutManager: \(textView?.layoutManager != nil)\n"
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            info += "    - Non-contiguous Layout: \(textView?.layoutManager?.allowsNonContiguousLayout ?? false)\n"
            #endif
        }
        
        return info
    }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - TextKitBridge Factory

extension PlatformTextView {
    /// Create a TextKitBridge for this text view
    func createTextKitBridge() -> TextKitBridge {
        TextKitBridge(textView: self)
    }
}
