import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - TextKitBridge

/// Unified interface for TextKit1 and TextKit2 operations
@MainActor
public final class TextKitBridge {
    // MARK: - Properties
    
    private weak var textView: PlatformTextView?
    private let isUsingTextKit2: Bool
    
    /// Current TextKit version being used
    public enum Version {
        case textKit1
        case textKit2
        
        var description: String {
            switch self {
            case .textKit1: return "TextKit 1"
            case .textKit2: return "TextKit 2"
            }
        }
    }
    
    public var version: Version {
        isUsingTextKit2 ? .textKit2 : .textKit1
    }
    
    // MARK: - Initialization
    
    public init(textView: PlatformTextView) {
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
    public var textStorage: NSTextStorage? {
        textView?.textStorage
    }
    
    /// Get the text content storage for TextKit2
    public var textContentStorage: NSTextContentStorage? {
        textView?.textContentStorage
    }
    
    // MARK: - Layout Management
    
    /// Perform layout for a specific range
    public func ensureLayout(for range: NSRange) {
        guard let textView else { return }
        
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
        guard let textLayoutManager = textView?.textLayoutManager,
              let textContentManager = textLayoutManager.textContentManager else { return }
        
        // Convert NSRange to NSTextRange for TextKit2
        if let textRange = textRangeFromNSRange(range) {
            textLayoutManager.ensureLayout(for: textRange)
        }
    }
    
    // MARK: - Range Conversion
    
    /// Convert NSRange to NSTextRange for TextKit2
    public func textRangeFromNSRange(_ nsRange: NSRange) -> NSTextRange? {
        guard isUsingTextKit2,
              let textLayoutManager = textView?.textLayoutManager,
              let textContentManager = textLayoutManager.textContentManager else {
            return nil
        }
        
        let startLocation = textContentManager.location(textContentManager.documentRange.location, offsetBy: nsRange.location)
        let endLocation = textContentManager.location(startLocation!, offsetBy: nsRange.length)
        
        if let start = startLocation, let end = endLocation {
            return NSTextRange(location: start, end: end)
        }
        return nil
    }
    
    /// Convert NSTextRange to NSRange for TextKit1 compatibility
    public func nsRangeFromTextRange(_ textRange: NSTextRange) -> NSRange? {
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
    public func addAttributes(_ attributes: [NSAttributedString.Key: Any], range: NSRange) {
        guard let textStorage else { return }
        
        textStorage.beginEditing()
        textStorage.addAttributes(attributes, range: range)
        textStorage.endEditing()
        
        // Ensure layout is updated
        ensureLayout(for: range)
    }
    
    /// Remove attributes from a range
    public func removeAttributes(_ attributeKeys: [NSAttributedString.Key], range: NSRange) {
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
    public func enumerateLineFragments(in range: NSRange, using block: @escaping (CGRect, NSRange) -> Void) {
        if isUsingTextKit2 {
            enumerateLineFragmentsTextKit2(in: range, using: block)
        } else {
            enumerateLineFragmentsTextKit1(in: range, using: block)
        }
    }
    
    private func enumerateLineFragmentsTextKit1(in range: NSRange, using block: @escaping (CGRect, NSRange) -> Void) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let layoutManager = textView?.layoutManager else { return }
        
        layoutManager.enumerateLineFragments(forGlyphRange: range) { rect, _, _, glyphRange, _ in
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            block(rect, characterRange)
        }
        #elseif canImport(UIKit)
        guard let layoutManager = textView?.layoutManager else { return }
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, _, _, glyphRange, _ in
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            block(rect, characterRange)
        }
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
    public var visibleRange: NSRange? {
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
              let textContainer = textView?.textContainer else { return nil }
        
        let visibleRect = textView?.bounds ?? .zero
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        #endif
    }
    
    private func visibleRangeTextKit2() -> NSRange? {
        guard let textLayoutManager = textView?.textLayoutManager else { return nil }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let visibleRect = textView?.visibleRect ?? .zero
        #elseif canImport(UIKit)
        let visibleRect = textView?.bounds ?? .zero
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
    
    // MARK: - Performance Optimization
    
    /// Optimize for a specific file size
    public func optimizeForFileSize(_ characterCount: Int) {
        let capabilities = PlatformCapabilities.shared
        
        if characterCount > 50_000 { // Use a reasonable threshold
            // For large files, enable TextKit2 if available
            if capabilities.supportsTextKit2 && !isUsingTextKit2 {
                if let textView {
                    ModernTextKitHelper.ensureTextKit2(for: textView)
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
    public var debugInfo: String {
        var info = "TextKit Configuration:\n"
        info += "  Version: \(version.description)\n"
        info += "  Text Length: \(textStorage?.length ?? 0) characters\n"
        
        if isUsingTextKit2 {
            info += "  TextKit2 Features:\n"
            info += "    - TextLayoutManager: \(textView?.textLayoutManager != nil)\n"
            info += "    - TextContentStorage: \(textView?.textContentStorage != nil)\n"
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
    public func createTextKitBridge() -> TextKitBridge {
        TextKitBridge(textView: self)
    }
}
