import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - GutterView

/// View for displaying line numbers and other gutter information
public class GutterView: NSView {
    weak var textView: CodeEditorView?

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Ensure the view clips to its bounds
        layer?.masksToBounds = true
    }

    /// Text views need a flipped coordinate system on macOS
    override public var isFlipped: Bool {
        true
    }

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let textView else {
            return
        }

        // Clear background - only fill the gutter's bounds, not the dirty rect
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        // Set up text attributes for line numbers
        let font = NSFont.monospacedSystemFont(
            ofSize: (textView.font?.pointSize ?? NSFont.systemFontSize) * 0.9,
            weight: .regular
        )
        let textColor = NSColor.secondaryLabelColor
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        // Calculate line numbers to draw
        let rightPadding: CGFloat = 8
        let drawingWidth: CGFloat = bounds.width - rightPadding

        // Get visible range and calculate line numbers
        let visibleRange = textView.visibleRange()
        let text = textView.string
        let lineRanges = getLineRanges(for: text, in: visibleRange)

        for (lineNumber, lineRange) in lineRanges {
            // Calculate the line rect using layout manager
            if let layoutManager = textView.layoutManager,
               let textContainer = textView.textContainer {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
                let lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

                // Adjust for text container inset and scroll position
                var drawingRect = lineRect
                drawingRect.origin.y += textView.textContainerInset.height
                drawingRect.origin.x = 0
                drawingRect.size.width = drawingWidth

                // Only draw if the line intersects with the dirty rect
                if drawingRect.intersects(dirtyRect) {
                    let lineNumberString = "\(lineNumber)"
                    lineNumberString.draw(in: drawingRect, withAttributes: attributes)
                }
            }
        }
    }

    private func getLineRanges(for text: String, in visibleRange: NSRange) -> [(Int, NSRange)] {
        var lineRanges: [(Int, NSRange)] = []
        var lineNumber = 1

        // Convert to String.Index for Swift native operations
        let visibleStartIndex = String.Index(utf16Offset: visibleRange.location, in: text)
        let visibleEndIndex = String.Index(
            utf16Offset: visibleRange.location + visibleRange.length,
            in: text
        )

        // Count lines before visible range
        var currentIndex = text.startIndex
        while currentIndex < visibleStartIndex {
            // Find the end of the current line
            let lineEnd = text[currentIndex...].firstIndex(of: "\n") ?? text.endIndex
            if lineEnd <= visibleStartIndex {
                lineNumber += 1
                currentIndex = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
            } else {
                break
            }
        }

        // Process visible lines
        currentIndex = visibleStartIndex
        while currentIndex < visibleEndIndex, currentIndex < text.endIndex {
            // Find start of current line
            var lineStart = currentIndex
            if lineStart > text.startIndex {
                // Search backwards for the previous newline
                let searchRange = text.startIndex ..< lineStart
                if let lastNewline = text[searchRange].lastIndex(of: "\n") {
                    lineStart = text.index(after: lastNewline)
                } else {
                    lineStart = text.startIndex
                }
            }

            // Find end of current line
            let lineEnd = text[lineStart...].firstIndex(of: "\n") ?? text.endIndex
            let nextLineStart = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex

            // Convert to NSRange
            let startOffset = text.utf16.distance(from: text.startIndex, to: lineStart)
            let endOffset = text.utf16.distance(from: text.startIndex, to: nextLineStart)
            let lineRange = NSRange(location: startOffset, length: endOffset - startOffset)

            lineRanges.append((lineNumber, lineRange))
            lineNumber += 1
            currentIndex = nextLineStart
        }

        return lineRanges
    }

    deinit {
        // Cleanup if needed
    }
}
