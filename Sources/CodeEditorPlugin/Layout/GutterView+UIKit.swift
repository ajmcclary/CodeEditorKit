import Foundation

#if canImport(UIKit)
import UIKit

// MARK: - GutterView UIKit Implementation Details

extension GutterView {
    
    func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.add(to: .main, forMode: .common)
        displayLink?.isPaused = true
    }
    
    @objc private func displayLinkFired() {
        guard let textView = textView as? UITextView else { return }
        
        let currentOffset = textView.contentOffset
        if !currentOffset.equalTo(lastContentOffset) {
            lastContentOffset = currentOffset
            setNeedsDisplayLineNumbers()
        }
        
        displayLink?.isPaused = true
    }
    
    /// Track text view changes
    func observeTextView() {
        guard let textView else { return }
        
        // Observe text changes
        NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setNeedsDisplayLineNumbers()
            }
        }
        
        // Observe scrolling via display link
        if let scrollView = textView as? UIScrollView {
            scrollView.delegate = self
        }
    }
    
    func drawLineNumbers(in rect: CGRect) {
        guard let textView = textView as? UITextView,
              let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage else { return }
        
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(PlatformColors.controlBackground.cgColor)
        context?.fill(rect)
        
        let text = textStorage.string
        let visibleRange = layoutManager.glyphRange(forBoundingRect: textView.bounds, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: visibleRange, actualGlyphRange: nil)
        
        let font = PlatformFonts.monospacedSystemFont(ofSize: 12, weight: .regular)
        let textColor = PlatformColors.secondaryLabel
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        
        // Get line ranges for visible area
        let lineRanges = getLineRanges(for: text, in: characterRange)
        
        for (lineNumber, lineRange) in lineRanges {
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: layoutManager.glyphIndexForCharacter(at: lineRange.location), effectiveRange: nil, withoutAdditionalLayout: true)
            
            let lineNumberString = "\(lineNumber)"
            let lineNumberSize = lineNumberString.size(withAttributes: attributes)
            
            let drawingPoint = CGPoint(
                x: bounds.width - lineNumberSize.width - 8,
                y: lineRect.minY + (lineRect.height - lineNumberSize.height) / 2
            )
            
            lineNumberString.draw(at: drawingPoint, withAttributes: attributes)
        }
    }
    
    private func getLineRanges(for text: String, in range: NSRange) -> [(Int, NSRange)] {
        var lineRanges: [(Int, NSRange)] = []
        var lineNumber = 1
        var currentIndex = text.startIndex
        
        // Count lines before the visible range
        let beforeRange = NSRange(location: 0, length: range.location)
        let beforeText = String(text[..<text.index(text.startIndex, offsetBy: beforeRange.upperBound)])
        lineNumber += beforeText.components(separatedBy: .newlines).count - 1
        
        // Move to start of visible range
        currentIndex = text.index(text.startIndex, offsetBy: range.location)
        
        while currentIndex < text.endIndex {
            let lineEnd = text.lineRange(for: currentIndex..<currentIndex).upperBound
            let nextLineStart = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
            
            // Convert to NSRange
            let startOffset = text.utf16.distance(from: text.startIndex, to: currentIndex)
            let endOffset = text.utf16.distance(from: text.startIndex, to: nextLineStart)
            let lineRange = NSRange(location: startOffset, length: endOffset - startOffset)
            
            lineRanges.append((lineNumber, lineRange))
            lineNumber += 1
            currentIndex = nextLineStart
        }
        
        // Add final empty line if text ends with newline
        if text.hasSuffix("\n") {
            let finalOffset = text.utf16.count
            lineRanges.append((lineNumber, NSRange(location: finalOffset, length: 0)))
        }
        
        return lineRanges
    }
    
}

// MARK: - UIScrollViewDelegate

extension GutterView: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        displayLink?.isPaused = false
    }
}

#endif