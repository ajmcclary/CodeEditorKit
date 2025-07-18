import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Line Number Calculation Service

/// Service responsible for all line number calculations and text coordinate transformations
/// Extracts business logic from GutterView and related UI components
@MainActor
public final class LineNumberCalculationService {
    // MARK: - Types
    
    public struct LinePosition {
        public let lineNumber: Int
        public let yPosition: CGFloat
        public let lineHeight: CGFloat
        public let characterRange: NSRange
        
        public init(lineNumber: Int, yPosition: CGFloat, lineHeight: CGFloat, characterRange: NSRange) {
            self.lineNumber = lineNumber
            self.yPosition = yPosition
            self.lineHeight = lineHeight
            self.characterRange = characterRange
        }
    }
    
    public struct VisibleLineRange {
        public let startLine: Int
        public let endLine: Int
        public let positions: [LinePosition]
        
        public init(startLine: Int, endLine: Int, positions: [LinePosition]) {
            self.startLine = startLine
            self.endLine = endLine
            self.positions = positions
        }
    }
    
    public struct GutterMetrics {
        public let requiredWidth: CGFloat
        public let lineNumberDigits: Int
        public let characterWidth: CGFloat
        public let padding: CGFloat
        
        public init(requiredWidth: CGFloat, lineNumberDigits: Int, characterWidth: CGFloat, padding: CGFloat) {
            self.requiredWidth = requiredWidth
            self.lineNumberDigits = lineNumberDigits
            self.characterWidth = characterWidth
            self.padding = padding
        }
    }
    
    // MARK: - Properties
    
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "LineNumberCalculationService")
    
    // Cache for expensive calculations
    private var linePositionCache: [String: [LinePosition]] = [:]
    private var gutterMetricsCache: [String: GutterMetrics] = [:]
    private let maxCacheSize = 10
    
    // MARK: - Initialization
    
    public init() {
        // Service initialization
    }
    
    // MARK: - Public Interface
    
    /// Calculates the Y position for a specific line number in the text view
    public func calculateLinePosition(
        lineNumber: Int,
        in textView: CodeEditorView,
        configuration: EditorConfiguration
    ) -> CGFloat? {
        guard lineNumber > 0 else { return nil }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return calculateMacOSLinePosition(lineNumber: lineNumber, textView: textView, configuration: configuration)
        #elseif canImport(UIKit)
        return calculateiOSLinePosition(lineNumber: lineNumber, textView: textView, configuration: configuration)
        #endif
    }
    
    /// Calculates visible line ranges and their positions for the current viewport
    public func calculateVisibleLineRanges(
        for textView: CodeEditorView,
        configuration: EditorConfiguration
    ) -> VisibleLineRange {
        let cacheKey = generateCacheKey(for: textView, configuration: configuration)
        
        if let cached = linePositionCache[cacheKey] {
            return VisibleLineRange(
                startLine: cached.first?.lineNumber ?? 1,
                endLine: cached.last?.lineNumber ?? 1,
                positions: cached
            )
        }
        
        let positions = calculateAllLinePositions(textView: textView, configuration: configuration)
        let visiblePositions = filterVisiblePositions(positions, in: textView)
        
        // Cache the result
        cacheLinePositions(cacheKey: cacheKey, positions: visiblePositions)
        
        return VisibleLineRange(
            startLine: visiblePositions.first?.lineNumber ?? 1,
            endLine: visiblePositions.last?.lineNumber ?? 1,
            positions: visiblePositions
        )
    }
    
    /// Calculates required gutter width based on line count and font metrics
    public func calculateGutterMetrics(
        for lineCount: Int,
        font: PlatformFont,
        configuration: EditorConfiguration
    ) -> GutterMetrics {
        let cacheKey = generateGutterCacheKey(lineCount: lineCount, font: font, configuration: configuration)
        
        if let cached = gutterMetricsCache[cacheKey] {
            return cached
        }
        
        let digits = max(3, String(lineCount).count) // Minimum 3 digits for aesthetics
        let characterWidth = estimateCharacterWidth(for: font)
        let padding = calculateGutterPadding(configuration: configuration)
        let requiredWidth = CGFloat(digits) * characterWidth + padding
        
        let metrics = GutterMetrics(
            requiredWidth: requiredWidth,
            lineNumberDigits: digits,
            characterWidth: characterWidth,
            padding: padding
        )
        
        // Cache the result
        cacheGutterMetrics(cacheKey: cacheKey, metrics: metrics)
        
        return metrics
    }
    
    /// Finds the line number at a specific point in the text view
    public func lineNumber(at point: CGPoint, in textView: CodeEditorView) -> Int? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return findLineNumberMacOS(at: point, textView: textView)
        #elseif canImport(UIKit)
        return findLineNumberiOS(at: point, textView: textView)
        #endif
    }
    
    /// Converts a character index to a line number
    public func lineNumber(for characterIndex: Int, in textView: CodeEditorView) -> Int {
        let text = textView.text ?? ""
        guard characterIndex >= 0 && characterIndex <= text.count else { return 1 }
        
        let textUpToIndex = String(text.prefix(characterIndex))
        let lineNumber = textUpToIndex.components(separatedBy: .newlines).count
        return max(1, lineNumber)
    }
    
    /// Gets the character range for a specific line number
    public func characterRange(for lineNumber: Int, in textView: CodeEditorView) -> NSRange? {
        let text = textView.text ?? ""
        let lines = text.components(separatedBy: .newlines)
        
        guard lineNumber > 0 && lineNumber <= lines.count else { return nil }
        
        var currentIndex = 0
        for (index, line) in lines.enumerated() {
            if index + 1 == lineNumber {
                return NSRange(location: currentIndex, length: line.count)
            }
            currentIndex += line.count + 1 // +1 for newline character
        }
        
        return nil
    }
    
    // MARK: - Cache Management
    
    /// Clears the line position cache to free memory
    public func clearCache() {
        linePositionCache.removeAll()
        gutterMetricsCache.removeAll()
        logger.debug("Line number calculation cache cleared")
    }
    
    /// Invalidates cache for a specific text view
    public func invalidateCache(for textView: CodeEditorView) {
        let keysToRemove = linePositionCache.keys.filter { $0.contains(textView.description) }
        keysToRemove.forEach { linePositionCache.removeValue(forKey: $0) }
        
        let gutterKeysToRemove = gutterMetricsCache.keys.filter { $0.contains(textView.description) }
        gutterKeysToRemove.forEach { gutterMetricsCache.removeValue(forKey: $0) }
        
        logger.debug("Cache invalidated for text view")
    }
}

// MARK: - Private Implementation

extension LineNumberCalculationService {
    // MARK: - Platform-Specific Line Position Calculations
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    func calculateMacOSLinePosition(
        lineNumber: Int,
        textView: CodeEditorView,
        configuration _: EditorConfiguration
    ) -> CGFloat? {
        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager else { return nil }
        
        // Find the character range for the line
        guard let range = characterRange(for: lineNumber, in: textView) else { return nil }
        
        // Get the glyph range for this character range
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        guard glyphRange.location != NSNotFound else { return nil }
        
        // Calculate the bounding rect for the line
        let lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Apply text container insets and adjustments
        let textContainerInset = textView.textContainerInset
        return lineRect.minY + textContainerInset.height / 2
    }
    
    func findLineNumberMacOS(at point: CGPoint, textView: CodeEditorView) -> Int? {
        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager else { return nil }
        
        // Convert point to text container coordinates
        let textContainerInset = textView.textContainerInset
        let adjustedPoint = CGPoint(
            x: point.x - textContainerInset.width / 2,
            y: point.y - textContainerInset.height / 2
        )
        
        // Find the character index at this point
        let characterIndex = layoutManager.characterIndex(
            for: adjustedPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        
        return lineNumber(for: characterIndex, in: textView)
    }
    #endif
    
    #if canImport(UIKit)
    func calculateiOSLinePosition(
        lineNumber: Int,
        textView: CodeEditorView,
        configuration _: EditorConfiguration
    ) -> CGFloat? {
        #if targetEnvironment(macCatalyst)
        // Mac Catalyst: Use text position APIs to avoid triggering TextKit1 mode
        guard let text = textView.text,
              let range = characterRange(for: lineNumber, in: textView),
              let stringRange = Range(range, in: text) else { return nil }
        
        // Get the start position of the line
        let lineStartIndex = text.lineRange(for: stringRange).lowerBound
        let offset = text.distance(from: text.startIndex, to: lineStartIndex)
        
        guard let position = textView.position(from: textView.beginningOfDocument, offset: offset),
              let textRange = textView.textRange(from: position, to: position) else { return nil }
        
        // Get the rect for this position
        let lineRect = textView.firstRect(for: textRange)
        
        // Apply text container insets and adjustments
        let textContainerInset = textView.textContainerInset
        return lineRect.minY + (textContainerInset.top + textContainerInset.bottom) / 2
        
        #else
        // iOS: Access layoutManager directly
        let textContainer = textView.textContainer
        let layoutManager = textView.layoutManager
        
        // Find the character range for the line
        guard let range = characterRange(for: lineNumber, in: textView) else { return nil }
        
        // Get the glyph range for this character range
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        guard glyphRange.location != NSNotFound else { return nil }
        
        // Calculate the bounding rect for the line
        let lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Apply text container insets and adjustments
        let textContainerInset = textView.textContainerInset
        return lineRect.minY + (textContainerInset.top + textContainerInset.bottom) / 2
        #endif
    }
    
    func findLineNumberiOS(at point: CGPoint, textView: CodeEditorView) -> Int? {
        #if targetEnvironment(macCatalyst)
        // Mac Catalyst: Use text position APIs to avoid triggering TextKit1 mode
        guard let position = textView.closestPosition(to: point) else { return nil }
        
        let characterIndex = textView.offset(from: textView.beginningOfDocument, to: position)
        
        return lineNumber(for: characterIndex, in: textView)
        
        #else
        // iOS: Access layoutManager directly
        let textContainer = textView.textContainer
        let layoutManager = textView.layoutManager
        
        // Convert point to text container coordinates
        let textContainerInset = textView.textContainerInset
        let adjustedPoint = CGPoint(
            x: point.x - (textContainerInset.left + textContainerInset.right) / 2,
            y: point.y - (textContainerInset.top + textContainerInset.bottom) / 2
        )
        
        // Find the character index at this point
        let characterIndex = layoutManager.characterIndex(
            for: adjustedPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        
        return lineNumber(for: characterIndex, in: textView)
        #endif
    }
    #endif
    
    // MARK: - Helper Methods
    
    func calculateAllLinePositions(
        textView: CodeEditorView,
        configuration: EditorConfiguration
    ) -> [LinePosition] {
        let text = textView.text ?? ""
        let lines = text.components(separatedBy: .newlines)
        var positions: [LinePosition] = []
        
        for index in lines.indices {
            let lineNumber = index + 1
            
            if let yPosition = calculateLinePosition(lineNumber: lineNumber, in: textView, configuration: configuration),
               let characterRange = characterRange(for: lineNumber, in: textView) {
                let lineHeight = estimateLineHeight(for: configuration.display.fontSize)
                
                let position = LinePosition(
                    lineNumber: lineNumber,
                    yPosition: yPosition,
                    lineHeight: lineHeight,
                    characterRange: characterRange
                )
                positions.append(position)
            }
        }
        
        return positions
    }
    
    func filterVisiblePositions(_ positions: [LinePosition], in textView: CodeEditorView) -> [LinePosition] {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let visibleRect = textView.visibleRect
        #elseif canImport(UIKit)
        // On iOS, use bounds as the visible area or calculate based on scroll view if available
        let visibleRect = textView.bounds
        #endif
        
        return positions.filter { position in
            let lineBottom = position.yPosition + position.lineHeight
            return position.yPosition <= visibleRect.maxY && lineBottom >= visibleRect.minY
        }
    }
    
    func estimateCharacterWidth(for font: PlatformFont) -> CGFloat {
        // Use a representative character to estimate width
        let sampleString = "0"
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = sampleString.size(withAttributes: attributes)
        return size.width
    }
    
    func estimateLineHeight(for fontSize: CGFloat) -> CGFloat {
        fontSize * 1.2 // Standard line height multiplier
    }
    
    func calculateGutterPadding(configuration: EditorConfiguration) -> CGFloat {
        // Base padding plus any configuration-specific adjustments
        let basePadding: CGFloat = 16.0 // 8pt on each side
        
        if configuration.display.showInvisibleCharacters {
            return basePadding + 4.0 // Extra space for invisible character indicators
        }
        
        return basePadding
    }
    
    // MARK: - Cache Management Helpers
    
    func generateCacheKey(for textView: CodeEditorView, configuration: EditorConfiguration) -> String {
        let textViewId = ObjectIdentifier(textView).debugDescription
        let configHash = configuration.hashValue
        return "\(textViewId)_\(configHash)_\((textView.text ?? "").count)"
    }
    
    func generateGutterCacheKey(lineCount: Int, font: PlatformFont, configuration: EditorConfiguration) -> String {
        let fontKey = "\(font.fontName)_\(font.pointSize)"
        let configHash = configuration.hashValue
        return "\(lineCount)_\(fontKey)_\(configHash)"
    }
    
    func cacheLinePositions(cacheKey: String, positions: [LinePosition]) {
        if linePositionCache.count >= maxCacheSize,
           let oldestKey = linePositionCache.keys.first {
            // Remove oldest entry
            linePositionCache.removeValue(forKey: oldestKey)
        }
        linePositionCache[cacheKey] = positions
    }
    
    func cacheGutterMetrics(cacheKey: String, metrics: GutterMetrics) {
        if gutterMetricsCache.count >= maxCacheSize,
           let oldestKey = gutterMetricsCache.keys.first {
            // Remove oldest entry
            gutterMetricsCache.removeValue(forKey: oldestKey)
        }
        gutterMetricsCache[cacheKey] = metrics
    }
}

// MARK: - Configuration Extensions

extension EditorConfiguration: Hashable {
    /// Helper to generate a stable hash for caching purposes
    public func hash(into hasher: inout Hasher) {
        hasher.combine(display.fontSize)
        // hasher.combine(layout.lineHeight) // Property doesn't exist
        hasher.combine(display.isLineNumbersEnabled)
        hasher.combine(display.showInvisibleCharacters)
    }
}
