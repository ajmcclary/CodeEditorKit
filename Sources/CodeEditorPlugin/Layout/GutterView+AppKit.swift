import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

// MARK: - GutterView AppKit Implementation Details

extension GutterView {
    /// Track text view changes
    func observeTextView() {
        guard let textView else { return }
        
        // Clear any existing observers first
        removeTextViewObservers()
        
        // Observe text changes
        let textObserver = NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setNeedsDisplayLineNumbers()
            }
        }
        observers.append(textObserver)
        
        // Observe scrolling
        if let scrollView = textView.enclosingScrollView {
            let scrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.setNeedsDisplayLineNumbers()
                }
            }
            observers.append(scrollObserver)
        }
    }
    
    /// Remove all text view observers
    func removeTextViewObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
    
    func drawLineNumbersAppKit(in _: CGRect, textView: CodeEditorView) {
        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage else { 
            return 
        }
        
        // Don't fill the entire background - keep it transparent
        // Only draw the line numbers themselves
        
        let text = textStorage.string
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        let visibleCharacterRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
        
        let font = PlatformFonts.monospacedSystemFont(ofSize: 12, weight: .regular)
        let textColor = PlatformColors.secondaryLabel
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        
        // Get line ranges for visible area
        let lineRanges = getLineRanges(for: text, in: visibleCharacterRange)
        
        for (lineNumber, lineRange) in lineRanges {
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: layoutManager.glyphIndexForCharacter(at: lineRange.location), effectiveRange: nil, withoutAdditionalLayout: true)
            
            let lineNumberString = "\(lineNumber)"
            let lineNumberSize = lineNumberString.size(withAttributes: attributes)
            
            let drawingPoint = NSPoint(
                x: bounds.width - lineNumberSize.width - 8,
                y: lineRect.minY + (lineRect.height - lineNumberSize.height) / 2
            )
            
            lineNumberString.draw(at: drawingPoint, withAttributes: attributes)
        }
    }
}
#endif
