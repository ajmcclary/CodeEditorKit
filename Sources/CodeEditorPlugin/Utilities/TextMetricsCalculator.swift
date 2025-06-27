import Foundation
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

/// Calculator for text-related metrics and measurements
@MainActor
public enum TextMetricsCalculator {
    // MARK: - Line Height Calculations
    
    /// Calculate the line height for a given font
    public static func calculateLineHeight(for font: PlatformFont) -> CGFloat {
        #if canImport(AppKit)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer()
        let textStorage = NSTextStorage(string: "M")
        
        textStorage.addAttribute(.font, value: font, range: NSRange(location: 0, length: 1))
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        return layoutManager.defaultLineHeight(for: font)
        #else
        return font.lineHeight
        #endif
    }
    
    /// Calculate line height with spacing
    public static func calculateLineHeight(
        for font: PlatformFont,
        lineSpacing: CGFloat,
        paragraphSpacing: CGFloat = 0
    ) -> CGFloat {
        let baseHeight = calculateLineHeight(for: font)
        return baseHeight + lineSpacing + paragraphSpacing
    }
    
    // MARK: - Text Measurement
    
    /// Measure the size of text with given attributes
    public static func measureText(
        _ text: String,
        attributes: [NSAttributedString.Key: Any],
        constrainingSize: CGSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    ) -> CGSize {
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        #if canImport(AppKit)
        let size = attributedString.boundingRect(
            with: constrainingSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        #else
        let size = attributedString.boundingRect(
            with: constrainingSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        #endif
        
        return CGSize(
            width: ceil(size.width),
            height: ceil(size.height)
        )
    }
    
    /// Measure text width for a single line
    public static func measureTextWidth(
        _ text: String,
        font: PlatformFont
    ) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = measureText(
            text,
            attributes: attributes,
            constrainingSize: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )
        return size.width
    }
    
    // MARK: - Memory Usage Estimation
    
    /// Estimate memory usage for a text string
    public static func estimateMemoryUsage(for text: String) -> Int {
        // Base string memory
        let stringMemory = text.utf8.count
        
        // Estimate overhead for NSString/NSAttributedString
        let overheadFactor = 2.5 // Empirically determined
        
        // Account for potential attributes storage
        let attributesOverhead = text.count * 8 // Rough estimate per character
        
        return Int(Double(stringMemory) * overheadFactor) + attributesOverhead
    }
    
    /// Estimate memory usage for syntax highlighting
    public static func estimateSyntaxHighlightingMemory(
        for text: String,
        averageTokensPerLine: Int = 10
    ) -> Int {
        let lineCount = text.components(separatedBy: .newlines).count
        let estimatedTokens = lineCount * averageTokensPerLine
        
        // Each token stores range + attributes
        let bytesPerToken = 32 // NSRange (16) + attribute pointer (8) + overhead
        
        return estimatedTokens * bytesPerToken
    }
    
    // MARK: - Visible Lines Calculation
    
    /// Calculate which lines are visible in a given bounds
    public static func calculateVisibleLines(
        in bounds: CGRect,
        lineHeight: CGFloat,
        totalLines: Int,
        contentOffset: CGPoint = .zero
    ) -> Range<Int> {
        let adjustedBounds = CGRect(
            x: bounds.origin.x,
            y: bounds.origin.y + contentOffset.y,
            width: bounds.width,
            height: bounds.height
        )
        
        let firstVisibleLine = max(0, Int(floor(adjustedBounds.minY / lineHeight)))
        let lastVisibleLine = min(totalLines - 1, Int(ceil(adjustedBounds.maxY / lineHeight)))
        
        return firstVisibleLine..<(lastVisibleLine + 1)
    }
    
    /// Calculate the number of visible lines that fit in bounds
    public static func calculateVisibleLineCount(
        in bounds: CGRect,
        lineHeight: CGFloat
    ) -> Int {
        max(1, Int(floor(bounds.height / lineHeight)))
    }
    
    // MARK: - Character Metrics
    
    /// Calculate average character width for a font
    public static func calculateAverageCharacterWidth(for font: PlatformFont) -> CGFloat {
        // Use a representative string
        let sampleText = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        let width = measureTextWidth(sampleText, font: font)
        return width / CGFloat(sampleText.count)
    }
    
    /// Calculate monospace character width
    public static func calculateMonospaceCharacterWidth(for font: PlatformFont) -> CGFloat? {
        // Check if font is monospace by comparing widths
        let narrowChar = measureTextWidth("i", font: font)
        let wideChar = measureTextWidth("W", font: font)
        
        // If widths are equal, it's monospace
        if abs(narrowChar - wideChar) < 0.01 {
            return narrowChar
        }
        
        return nil
    }
    
    // MARK: - Tab Width Calculation
    
    /// Calculate the width of a tab character
    public static func calculateTabWidth(
        font: PlatformFont,
        tabSize: Int = 4
    ) -> CGFloat {
        let spaceWidth = measureTextWidth(" ", font: font)
        return spaceWidth * CGFloat(tabSize)
    }
    
    // MARK: - Line Number Width
    
    /// Calculate the width needed for line numbers
    public static func calculateLineNumberWidth(
        lineCount: Int,
        font: PlatformFont,
        padding: CGFloat = 10
    ) -> CGFloat {
        let digits = String(lineCount).count
        let sampleNumber = String(repeating: "8", count: digits)
        let textWidth = measureTextWidth(sampleNumber, font: font)
        return textWidth + padding * 2
    }
    
    // MARK: - Scroll Metrics
    
    /// Calculate content size for scrolling
    public static func calculateContentSize(
        lineCount: Int,
        lineHeight: CGFloat,
        width: CGFloat,
        bottomPadding: CGFloat = 0
    ) -> CGSize {
        let height = CGFloat(lineCount) * lineHeight + bottomPadding
        return CGSize(width: width, height: height)
    }
    
    /// Calculate line at point
    public static func lineIndex(
        at point: CGPoint,
        lineHeight: CGFloat
    ) -> Int {
        max(0, Int(floor(point.y / lineHeight)))
    }
    
    /// Calculate character index at point
    public static func characterIndex(
        at point: CGPoint,
        in line: String,
        font: PlatformFont,
        lineOrigin: CGPoint
    ) -> Int {
        let relativeX = point.x - lineOrigin.x
        
        // Binary search for character position
        var low = 0
        var high = line.count
        
        while low < high {
            let mid = (low + high) / 2
            let substring = String(line.prefix(mid))
            let width = measureTextWidth(substring, font: font)
            
            if width < relativeX {
                low = mid + 1
            } else {
                high = mid
            }
        }
        
        return low
    }
    
    // MARK: - Performance Metrics
    
    /// Estimate rendering complexity
    public static func estimateRenderingComplexity(
        text _: String,
        visibleRange: NSRange,
        attributeRuns: Int
    ) -> RenderingComplexity {
        let visibleCharacters = visibleRange.length
        let complexity = visibleCharacters * attributeRuns
        
        if complexity < 10_000 {
            return .low
        } else if complexity < 100_000 {
            return .medium
        } else {
            return .high
        }
    }
    
    /// Calculate optimal batch size for processing
    public static func calculateOptimalBatchSize(
        totalCharacters: Int,
        availableMemory: Int = Int(ProcessInfo.processInfo.physicalMemory / 4)
    ) -> Int {
        let bytesPerCharacter = 100 // Rough estimate including overhead
        let maxCharactersInMemory = availableMemory / bytesPerCharacter
        
        // Use 1/10th of available memory for each batch
        let batchSize = min(maxCharactersInMemory / 10, totalCharacters)
        
        // Clamp to reasonable range
        return max(1_000, min(100_000, batchSize))
    }
    
    // MARK: - Layout Metrics
    
    /// Calculate wrapped line breaks
    public static func calculateWrappedLineBreaks(
        text: String,
        font: PlatformFont,
        width: CGFloat
    ) -> [Int] {
        var breaks: [Int] = [0]
        
        var currentLineStart = 0
        var currentLineWidth: CGFloat = 0
        
        for index in 0..<text.count {
            guard let charIndex = text.index(text.startIndex, offsetBy: index, limitedBy: text.endIndex),
                  let nextIndex = text.index(charIndex, offsetBy: 1, limitedBy: text.endIndex) else { continue }
            
            let char = String(text[charIndex..<nextIndex])
            
            // Check for hard line break
            if char == "\n" {
                breaks.append(index + 1)
                currentLineStart = index + 1
                currentLineWidth = 0
                continue
            }
            
            // Measure character width
            let charWidth = measureTextWidth(char, font: font)
            currentLineWidth += charWidth
            
            // Check if we need to wrap
            if currentLineWidth > width && index > currentLineStart {
                // Find word boundary
                var wrapPoint = index
                for innerIndex in stride(from: index, to: currentLineStart, by: -1) {
                    let character = text.utf16[text.utf16.index(text.utf16.startIndex, offsetBy: innerIndex)]
                    if CharacterSet.whitespacesAndNewlines.contains(UnicodeScalar(character)!) {
                        wrapPoint = innerIndex + 1
                        break
                    }
                }
                
                breaks.append(wrapPoint)
                currentLineStart = wrapPoint
                
                // Recalculate width from wrap point
                guard let wrapStartIndex = text.index(text.startIndex, offsetBy: wrapPoint, limitedBy: text.endIndex),
                      let wrapEndIndex = text.index(text.startIndex, offsetBy: index + 1, limitedBy: text.endIndex) else { continue }
                let remainingText = String(text[wrapStartIndex..<wrapEndIndex])
                currentLineWidth = measureTextWidth(remainingText, font: font)
            }
        }
        
        return breaks
    }
}

// MARK: - Supporting Types

public enum RenderingComplexity {
    case low
    case medium
    case high
}

// MARK: - Convenience Extensions

extension NSAttributedString {
    /// Calculate size using TextMetricsCalculator
    @MainActor
    public func calculatedSize(constrainingSize: CGSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)) -> CGSize {
        var attributes: [NSAttributedString.Key: Any] = [:]
        
        if length > 0 {
            attributes = self.attributes(at: 0, effectiveRange: nil)
        }
        
        return TextMetricsCalculator.measureText(
            string,
            attributes: attributes,
            constrainingSize: constrainingSize
        )
    }
}

extension PlatformFont {
    /// Get metrics for this font
    @MainActor
    public var metrics: FontMetrics {
        FontMetrics(
            lineHeight: TextMetricsCalculator.calculateLineHeight(for: self),
            averageCharacterWidth: TextMetricsCalculator.calculateAverageCharacterWidth(for: self),
            isMonospace: TextMetricsCalculator.calculateMonospaceCharacterWidth(for: self) != nil
        )
    }
}

public struct FontMetrics {
    public let lineHeight: CGFloat
    public let averageCharacterWidth: CGFloat
    public let isMonospace: Bool
}
