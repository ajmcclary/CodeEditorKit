import CoreGraphics
import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - TextKitLineNumberHelper

/// Helper for calculating line numbers and positions without forcing TextKit 1 compatibility mode
@MainActor
public final class TextKitLineNumberHelper {
    // MARK: - Properties
    
    private weak var textView: CodeEditorView?
    private let textKitBridge: TextKitBridge
    
    // MARK: - Initialization
    
    public init(textView: CodeEditorView) {
        self.textView = textView
        self.textKitBridge = TextKitBridge(textView: textView)
    }
    
    // MARK: - Line Information
    
    /// Get visible line ranges without accessing layoutManager directly on iOS/Catalyst
    public func getVisibleLineRanges() -> [(lineNumber: Int, range: NSRange)] {
        guard let textView else {
            return []
        }
        
        // Use TextKitBridge to get visible range
        guard let visibleRange = textKitBridge.visibleRange else {
            return []
        }
        
        // Calculate line ranges from the text itself
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textStorage = textView.textStorage else {
            return []
        }
        let text = textStorage.string
        #else
        let text = textView.textStorage.string
        #endif
        
        return calculateLineRanges(in: text, visibleRange: visibleRange)
    }
    
    /// Get line fragment rect for a specific line range
    public func getLineFragmentRect(for lineRange: NSRange) -> CGRect? {
        guard let textView else { return nil }
        
        // For TextKit 2, we can use the text layout manager
        if let textLayoutManager = textView.textLayoutManager,
           let textRange = textKitBridge.textRangeFromNSRange(lineRange) {
            // Find the layout fragment for this range
            var fragmentRect: CGRect?
            textLayoutManager.enumerateTextLayoutFragments(from: textRange.location) { fragment in
                fragmentRect = fragment.layoutFragmentFrame
                return false // Stop after first fragment
            }
            return fragmentRect
        }
        
        // For TextKit 1 (macOS only), we can safely use layoutManager
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let layoutManager = textView.layoutManager {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            return layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        }
        #endif
        
        // Fallback: calculate approximate position based on line height
        return calculateApproximateLineRect(for: lineRange)
    }
    
    /// Get the visible rect for the text view (platform-agnostic)
    public func getVisibleRect() -> CGRect {
        guard let textView else { return .zero }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS: Use the visible rect
        return textView.visibleRect
        #else
        // iOS/Catalyst: Calculate from content offset and bounds
        return CGRect(
            origin: textView.contentOffset,
            size: textView.bounds.size
        )
        #endif
    }
    
    /// Convert a point to the corresponding line number
    public func lineNumber(at point: CGPoint) -> Int? {
        guard let textView,
              let text = textView.text else {
            return nil
        }
        
        // Adjust point for text container inset
        let adjustedPoint = adjustPoint(point)
        
        // For TextKit 2, use text layout manager
        if let textLayoutManager = textView.textLayoutManager {
            return lineNumberTextKit2(at: adjustedPoint, textLayoutManager: textLayoutManager, text: text)
        }
        
        // For TextKit 1 (macOS only)
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {
            return lineNumberTextKit1(at: adjustedPoint, layoutManager: layoutManager, textContainer: textContainer, text: text)
        }
        #endif
        
        // Fallback: estimate based on line height
        return estimateLineNumber(at: adjustedPoint, text: text)
    }
    
    // MARK: - Private Helpers
    
    /// Calculate line ranges from text without using layoutManager
    private func calculateLineRanges(in text: String, visibleRange: NSRange) -> [(lineNumber: Int, range: NSRange)] {
        // Use the line index cache if available through the text view
        if let textView {
            return textView.lineIndexCache.visibleLineInfo(in: text, visibleRange: visibleRange)
        }
        
        // Fallback to the original implementation if not using CodeEditorView
        var lineRanges: [(Int, NSRange)] = []
        var lineNumber = 1
        
        // Count lines before the visible range
        if visibleRange.location > 0 {
            let beforeRange = NSRange(location: 0, length: visibleRange.location)
            if let beforeText = text.substring(with: beforeRange) {
                lineNumber += beforeText.components(separatedBy: .newlines).count - 1
            }
        }
        
        // Process visible range
        var currentLocation = visibleRange.location
        let endLocation = min(visibleRange.location + visibleRange.length, text.utf16.count)
        
        while currentLocation < endLocation {
            // Find the end of the current line
            var lineEndLocation = currentLocation
            
            if let substring = text.substring(from: currentLocation) {
                if let lineEndRange = substring.range(of: "\n") {
                    let distance = substring.distance(from: substring.startIndex, to: lineEndRange.lowerBound)
                    lineEndLocation = currentLocation + distance + 1
                } else {
                    lineEndLocation = text.utf16.count
                }
            }
            
            let lineRange = NSRange(location: currentLocation, length: lineEndLocation - currentLocation)
            lineRanges.append((lineNumber, lineRange))
            
            lineNumber += 1
            currentLocation = lineEndLocation
        }
        
        return lineRanges
    }
    
    /// Adjust point for platform-specific text container insets
    private func adjustPoint(_ point: CGPoint) -> CGPoint {
        guard let textView else { return point }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS: Point is already in the correct coordinate system
        return point
        #else
        // iOS/Catalyst: Account for text container inset and scroll offset
        let textContainerInset = textView.textContainerInset
        return CGPoint(
            x: point.x,
            y: point.y + textView.contentOffset.y - textContainerInset.top
        )
        #endif
    }
    
    /// Calculate line number using TextKit 2
    private func lineNumberTextKit2(at point: CGPoint, textLayoutManager: NSTextLayoutManager, text: String) -> Int? {
        // Use the line index cache if available through the text view
        if let textView {
            var foundLine: Int?
            
            textLayoutManager.enumerateTextLayoutFragments(from: textLayoutManager.documentRange.location) { fragment in
                let frame = fragment.layoutFragmentFrame
                
                // Check if point is within this fragment
                if point.y >= frame.minY && point.y <= frame.maxY {
                    // Calculate line number up to this fragment using cache
                    if let fragmentRange = self.textKitBridge.nsRangeFromTextRange(fragment.rangeInElement) {
                        foundLine = textView.lineIndexCache.lineNumber(at: fragmentRange.location, in: text)
                    }
                    return false // Stop enumeration
                }
                
                return frame.maxY < point.y // Continue if we haven't reached the point yet
            }
            
            return foundLine
        }
        
        // Fallback to original implementation
        var lineNumber = 1
        var foundLine: Int?
        
        textLayoutManager.enumerateTextLayoutFragments(from: textLayoutManager.documentRange.location) { fragment in
            let frame = fragment.layoutFragmentFrame
            
            // Check if point is within this fragment
            if point.y >= frame.minY && point.y <= frame.maxY {
                // Calculate line number up to this fragment
                if let fragmentRange = self.textKitBridge.nsRangeFromTextRange(fragment.rangeInElement) {
                    let textUpToFragment = String(text.prefix(fragmentRange.location))
                    lineNumber = textUpToFragment.components(separatedBy: .newlines).count
                    foundLine = lineNumber
                }
                return false // Stop enumeration
            }
            
            // Count lines in this fragment for future fragments
            if let fragmentRange = self.textKitBridge.nsRangeFromTextRange(fragment.rangeInElement),
               let fragmentText = text.substring(with: fragmentRange) {
                let linesInFragment = fragmentText.components(separatedBy: .newlines).count - 1
                lineNumber += linesInFragment
            }
            
            return frame.maxY < point.y // Continue if we haven't reached the point yet
        }
        
        return foundLine
    }
    
    /// Calculate line number using TextKit 1 (macOS only)
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private func lineNumberTextKit1(at point: CGPoint, layoutManager: NSLayoutManager, textContainer: NSTextContainer, text: String) -> Int? {
        // Find the glyph at this point
        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        
        // Use the line index cache if available through the text view
        if let textView {
            return textView.lineIndexCache.lineNumber(at: characterIndex, in: text)
        }
        
        // Fallback: Count lines up to this character
        let textUpToPoint = String(text.prefix(characterIndex))
        return textUpToPoint.components(separatedBy: .newlines).count
    }
    #endif
    
    /// Estimate line number based on approximate line height
    private func estimateLineNumber(at point: CGPoint, text: String) -> Int? {
        guard let textView else { return nil }
        
        // Get an approximate line height
        let font = textView.font ?? PlatformFonts.monospacedSystemFont(ofSize: 12, weight: .regular)
        let lineHeight = TextMetricsCalculator.calculateLineHeight(for: font)
        
        // Estimate line number
        let estimatedLine = Int(point.y / lineHeight) + 1
        
        // Clamp to valid range using cache if available
        let totalLines = textView.lineIndexCache.lineCount(in: text)
        return min(max(1, estimatedLine), totalLines)
    }
    
    /// Calculate approximate line rect when layout information is not available
    private func calculateApproximateLineRect(for lineRange: NSRange) -> CGRect {
        guard let textView,
              let text = textView.text else {
            return .zero
        }
        
        // Count lines before this range
        let textBeforeRange = String(text.prefix(lineRange.location))
        let linesBefore = textBeforeRange.components(separatedBy: .newlines).count - 1
        
        // Get line metrics
        let font = textView.font ?? PlatformFonts.monospacedSystemFont(ofSize: 12, weight: .regular)
        let lineHeight = TextMetricsCalculator.calculateLineHeight(for: font)
        
        // Calculate approximate Y position
        let yPosition = CGFloat(linesBefore) * lineHeight
        
        // Adjust for text container inset
        #if canImport(UIKit)
        let textContainerInset = textView.textContainerInset
        let adjustedY = yPosition + textContainerInset.top
        #else
        let adjustedY = yPosition
        #endif
        
        return CGRect(
            x: 0,
            y: adjustedY,
            width: textView.bounds.width,
            height: lineHeight
        )
    }
}

// MARK: - String Helpers

extension String {
    /// Safe substring extraction using NSRange
    func substring(with range: NSRange) -> String? {
        guard let rangeInString = Range(range, in: self) else { return nil }
        return String(self[rangeInString])
    }
    
    /// Safe substring extraction from a given offset
    func substring(from offset: Int) -> String? {
        guard offset < utf16.count else { return nil }
        let startIndex = index(self.startIndex, offsetBy: offset, limitedBy: endIndex) ?? endIndex
        return String(self[startIndex...])
    }
}
