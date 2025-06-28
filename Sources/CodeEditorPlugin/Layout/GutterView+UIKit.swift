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
        
        // Clear any existing observers first
        removeTextViewObservers()
        
        // Observe text changes
        let textObserver = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setNeedsDisplayLineNumbers()
            }
        }
        observers.append(textObserver)
        
        // Observe scrolling via display link
        if let scrollView = textView as? UIScrollView {
            scrollView.delegate = self
        }
    }
    
    /// Remove all text view observers
    func removeTextViewObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
    
    func drawLineNumbersUIKit(in rect: CGRect, textView: CodeEditorView) {
        guard let textContainer = textView.textContainer,
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
}

// MARK: - UIScrollViewDelegate

extension GutterView: UIScrollViewDelegate {
    public func scrollViewDidScroll(_: UIScrollView) {
        displayLink?.isPaused = false
    }
}

#endif
