import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#else
import UIKit
#endif

/// Modern TextKit2-only implementation without TextKit1 fallbacks
@MainActor
public class ModernTextKit2Bridge: NSObject {
    // MARK: - Properties
    
    private weak var textView: PlatformTextView?
    private var textLayoutManager: NSTextLayoutManager? { textView?.textLayoutManager }
    private var textContentManager: NSTextContentManager? { textLayoutManager?.textContentManager }
    
    // MARK: - Initialization
    
    public init(textView: PlatformTextView) {
        self.textView = textView
        super.init()
        ensureTextKit2Configuration()
    }
    
    // MARK: - Configuration
    
    private func ensureTextKit2Configuration() {
        guard let textView else { return }
        
        // Ensure TextKit2 is properly configured
        // Note: TextKit2 initialization happens automatically in modern systems
        
        // Configure text layout manager
        textLayoutManager?.delegate = self
        textLayoutManager?.textViewportLayoutController.delegate = self
        
        // Enable advanced features
        textLayoutManager?.limitsLayoutForSuspiciousContents = true
        textLayoutManager?.usesFontLeading = true
    }
    
    // MARK: - Range Conversion
    
    /// Convert NSRange to NSTextRange
    public func textRange(from nsRange: NSRange) -> NSTextRange? {
        guard let textContentManager else { return nil }
        let documentRange = textContentManager.documentRange
        
        guard let startLocation = textContentManager.location(
            documentRange.location,
            offsetBy: nsRange.location
        ) else { return nil }
        
        guard let endLocation = textContentManager.location(
            startLocation,
            offsetBy: nsRange.length
        ) else { return nil }
        
        return NSTextRange(location: startLocation, end: endLocation)
    }
    
    /// Convert NSTextRange to NSRange
    public func nsRange(from textRange: NSTextRange) -> NSRange? {
        guard let textContentManager else { return nil }
        let documentRange = textContentManager.documentRange
        
        let startOffset = textContentManager.offset(
            from: documentRange.location,
            to: textRange.location
        )
        
        let endOffset = textContentManager.offset(
            from: documentRange.location,
            to: textRange.endLocation
        )
        
        guard startOffset != NSNotFound, endOffset != NSNotFound else { return nil }
        
        return NSRange(location: startOffset, length: endOffset - startOffset)
    }
    
    // MARK: - Layout Operations
    
    /// Ensure layout for a specific range
    public func ensureLayout(for textRange: NSTextRange) {
        textLayoutManager?.ensureLayout(for: textRange)
    }
    
    /// Ensure layout for NSRange
    public func ensureLayout(for nsRange: NSRange) {
        guard let textRange = textRange(from: nsRange) else { return }
        ensureLayout(for: textRange)
    }
    
    /// Get bounding rect for text range
    public func boundingRect(for textRange: NSTextRange) -> CGRect {
        var rect = CGRect.zero
        
        textLayoutManager?.enumerateTextSegments(
            in: textRange,
            type: .standard,
            options: [.rangeNotRequired]
        ) { _, segmentFrame, _, _ in
            rect = rect.union(segmentFrame)
            return true
        }
        
        return rect
    }
    
    // MARK: - Fragment Operations
    
    /// Enumerate text layout fragments in range
    public func enumerateFragments(
        in textRange: NSTextRange,
        using block: (NSTextLayoutFragment) -> Bool
    ) {
        textLayoutManager?.enumerateTextLayoutFragments(
            from: textRange.location,
            options: [.ensuresLayout, .ensuresExtraLineFragment]
        ) { fragment in
            let fragmentRange = fragment.rangeInElement
            
            // Check if fragment intersects with our range
            if fragmentRange.location.compare(textRange.endLocation) == .orderedAscending &&
               fragmentRange.endLocation.compare(textRange.location) == .orderedDescending {
                return block(fragment)
            }
            
            // Continue if we haven't reached the range yet
            if fragmentRange.endLocation.compare(textRange.location) == .orderedAscending {
                return true
            }
            
            // Stop if we've passed the range
            return false
        }
    }
    
    /// Get line fragments for range
    public func lineFragments(for textRange: NSTextRange) -> [LineFragment] {
        var fragments: [LineFragment] = []
        
        enumerateFragments(in: textRange) { layoutFragment in
            let fragmentRange = layoutFragment.rangeInElement
            let lineFragment = LineFragment(
                range: fragmentRange,
                bounds: layoutFragment.layoutFragmentFrame,
                usageBounds: layoutFragment.renderingSurfaceBounds,
                textLineFragments: layoutFragment.textLineFragments
            )
            fragments.append(lineFragment)
            return true
        }
        
        return fragments
    }
    
    // MARK: - Rendering Attributes
    
    /// Set rendering attributes (non-layout affecting)
    public func setRenderingAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        for textRange: NSTextRange
    ) {
        textLayoutManager?.setRenderingAttributes(attributes, for: textRange)
    }
    
    /// Remove rendering attributes
    public func removeRenderingAttributes(
        for textRange: NSTextRange
    ) {
        textLayoutManager?.setRenderingAttributes([:], for: textRange)
    }
    
    /// Add temporary attributes using rendering attributes
    public func addTemporaryAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        for nsRange: NSRange
    ) {
        guard let textRange = textRange(from: nsRange) else { return }
        setRenderingAttributes(attributes, for: textRange)
    }
    
    // MARK: - Viewport Management
    
    /// Get current viewport range
    public var viewportRange: NSTextRange? {
        textLayoutManager?.textViewportLayoutController.viewportRange
    }
    
    /// Get visible text ranges
    public var visibleRanges: [NSTextRange] {
        guard let viewportRange else { return [] }
        
        var ranges: [NSTextRange] = []
        
        textLayoutManager?.enumerateTextLayoutFragments(
            from: viewportRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            let fragmentRange = fragment.rangeInElement
            
            // Check if fragment is visible
            if fragment.layoutFragmentFrame.intersects(self.textView?.visibleRect ?? .zero) {
                ranges.append(fragmentRange)
            }
            
            // Stop if we've passed the viewport
            return fragmentRange.location.compare(viewportRange.endLocation) == .orderedAscending
        }
        
        return ranges
    }
    
    // MARK: - Performance Optimization
    
    /// Invalidate layout for range
    public func invalidateLayout(for textRange: NSTextRange) {
        textLayoutManager?.invalidateLayout(for: textRange)
    }
    
    /// Invalidate rendering attributes
    public func invalidateRenderingAttributes(for textRange: NSTextRange) {
        textLayoutManager?.invalidateRenderingAttributes(for: textRange)
    }
    
    /// Batch layout updates
    public func performBatchUpdates(_ updates: () -> Void) {
        textLayoutManager?.textViewportLayoutController.layoutViewport()
        updates()
        if let range = viewportRange ?? textContentManager?.documentRange {
            textLayoutManager?.ensureLayout(for: range)
        }
    }
    
    // MARK: - Text Selection
    
    /// Get text selections as text ranges
    public var textSelections: [NSTextRange] {
        textLayoutManager?.textSelections.flatMap { selection in
            selection.textRanges
        } ?? []
    }
    
    /// Convert point to text location
    public func textLocation(at point: CGPoint) -> NSTextLocation? {
        guard let textLayoutManager else { return nil }
        
        var location: NSTextLocation?
        
        textLayoutManager.enumerateTextLayoutFragments(
            from: textLayoutManager.documentRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            if fragment.layoutFragmentFrame.contains(point) {
                // Find the exact location within the fragment
                for lineFragment in fragment.textLineFragments where lineFragment.typographicBounds.contains(point) {
                    let relativePoint = CGPoint(
                            x: point.x - lineFragment.typographicBounds.minX,
                            y: point.y - lineFragment.typographicBounds.minY
                        )
                        
                        let characterIndex = lineFragment.characterIndex(for: relativePoint)
                        location = fragment.rangeInElement.location
                        
                        if let loc = location,
                           let textContentManager = self.textContentManager {
                            location = textContentManager.location(loc, offsetBy: characterIndex)
                        }
                        
                        return false // Stop enumeration
                }
            }
            return true
        }
        
        return location
    }
    
    // MARK: - Line Information
    
    /// Get line number for text location
    public func lineNumber(for location: NSTextLocation) -> Int {
        var lineNumber = 0
        
        textLayoutManager?.enumerateTextLayoutFragments(
            from: textLayoutManager?.documentRange.location ?? location,
            options: [.ensuresLayout]
        ) { fragment in
            let fragmentRange = fragment.rangeInElement
            if fragmentRange.contains(location) {
                return false
            }
            
            // Count line breaks in fragment
            if let textContentManager = self.textContentManager,
                   let nsRange = self.nsRange(from: fragmentRange),
                   let textStorage = self.textView?.textStorage {
                    let text = textStorage.attributedSubstring(from: nsRange).string
                    lineNumber += text.components(separatedBy: .newlines).count - 1
                }
            
            return true
        }
        
        return lineNumber + 1 // 1-based line numbers
    }
    
    /// Get character index in line
    public func characterIndexInLine(for location: NSTextLocation) -> Int {
        var characterIndex = 0
        
        textLayoutManager?.enumerateTextLayoutFragments(
            from: location,
            options: [.reverse, .ensuresLayout]
        ) { fragment in
            let fragmentRange = fragment.rangeInElement
            if let textContentManager = self.textContentManager {
                let offset = textContentManager.offset(
                    from: fragmentRange.location,
                    to: location
                )
                
                if offset != NSNotFound {
                    // Check for line break before location
                    if let nsRange = self.nsRange(from: fragmentRange),
                       let textStorage = self.textView?.textStorage {
                        let text = textStorage.attributedSubstring(from: nsRange).string
                        let beforeLocation = String(text.prefix(offset))
                        
                        if let lastNewline = beforeLocation.lastIndex(of: "\n") {
                            characterIndex = beforeLocation.distance(from: beforeLocation.index(after: lastNewline), to: beforeLocation.endIndex)
                            return false
                        } else {
                            characterIndex += offset
                        }
                    }
                }
            }
            return true
        }
        
        return characterIndex
    }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - NSTextLayoutManagerDelegate

extension ModernTextKit2Bridge: @preconcurrency NSTextLayoutManagerDelegate {
    public func textLayoutManager(
        _: NSTextLayoutManager,
        textLayoutFragmentFor _: NSTextLocation,
        in textElement: NSTextElement
    ) -> NSTextLayoutFragment {
        // Create custom layout fragment if needed
        NSTextLayoutFragment(textElement: textElement, range: textElement.elementRange)
    }
}

// MARK: - NSTextViewportLayoutControllerDelegate

extension ModernTextKit2Bridge: @preconcurrency NSTextViewportLayoutControllerDelegate {
    public func viewportBounds(for _: NSTextViewportLayoutController) -> CGRect {
        textView?.visibleRect ?? .zero
    }
    
    public func textViewportLayoutController(
        _: NSTextViewportLayoutController,
        configureRenderingSurfaceFor _: NSTextLayoutFragment
    ) {
        // Configure rendering surface if needed
    }
}

// MARK: - Supporting Types

public struct LineFragment {
    public let range: NSTextRange
    public let bounds: CGRect
    public let usageBounds: CGRect
    public let textLineFragments: [NSTextLineFragment]
    
    public var lineHeight: CGFloat {
        bounds.height
    }
    
    public var baselineOffset: CGFloat {
        textLineFragments.first?.typographicBounds.minY ?? 0
    }
}

// MARK: - Extensions

extension NSTextRange {
    /// Check if this range contains a location
    func contains(_ location: NSTextLocation) -> Bool {
        location.compare(self.location) != .orderedAscending &&
        location.compare(self.endLocation) == .orderedAscending
    }
}

extension NSTextLineFragment {
    /// Get character index for point within line
    func characterIndex(for point: CGPoint) -> Int {
        // This is a simplified implementation
        // In practice, you'd use Core Text or TextKit2's more advanced APIs
        let glyphOrigin = typographicBounds.origin
        let relativeX = point.x - glyphOrigin.x
        
        // Estimate based on average character width
        let averageCharWidth = typographicBounds.width / CGFloat(max(1, characterRange.length))
        return min(characterRange.length - 1, max(0, Int(relativeX / averageCharWidth)))
    }
}
