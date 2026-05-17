import CodeEditorCommon
import CodeEditorPlatform
import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - TextKitLineNumberHelper

/// Helper for calculating line numbers and positions through the TextKit2 surface.
@MainActor
public final class TextKitLineNumberHelper {
    // MARK: - Properties

    private weak var textView: CodeEditorView?
    private let textKitBridge: TextKitBridge

    // MARK: - Initialization

    /// Creates a new TextKit line number helper for the specified text view.
    /// - Parameter textView: The code editor view to provide line number support for
    public init(textView: CodeEditorView) {
        self.textView = textView
        self.textKitBridge = TextKitBridge(textView: textView)
    }

    // MARK: - Line Information

    /// Get visible line ranges without accessing layoutManager directly on iOS
    public func getVisibleLineRanges() -> [(lineNumber: Int, range: NSRange)] {
        guard textView != nil else {
            return []
        }

        // Use TextKitBridge to get visible range
        guard let visibleRange = textKitBridge.visibleRange else {
            return []
        }

        // Calculate line ranges from the text itself via the bridge.
        let text = textKitBridge.documentString
        guard !text.isEmpty else { return [] }

        return calculateLineRanges(in: text, visibleRange: visibleRange)
    }

    /// Get line fragment rect for a specific line range
    public func getLineFragmentRect(for lineRange: NSRange) -> CGRect? {
        guard let textView else { return nil }

        // For TextKit 2, we can use the text layout manager
        if let textLayoutManager = textView.textLayoutManager,
           let textRange = textKitBridge.textRangeFromNSRange(lineRange) {
            textLayoutManager.ensureLayout(for: textRange)

            var lineFragmentRect: CGRect?
            textLayoutManager.enumerateTextLayoutFragments(
                from: textRange.location,
                options: [.ensuresLayout]
            ) { fragment in
                guard let fragmentRange = self.textKitBridge.nsRangeFromTextRange(fragment.rangeInElement) else {
                    return false
                }

                guard Self.rangesIntersect(fragmentRange, lineRange) else {
                    return fragmentRange.upperBound < lineRange.location
                }

                lineFragmentRect = self.firstVisualLineFragmentRect(
                    in: fragment,
                    containing: textRange.location,
                    fallbackLineRange: lineRange
                ) ?? fragment.layoutFragmentFrame

                return false
            }
            return lineFragmentRect
        }

        let lineIndex = textView.lineGeometryStore.lineIndex(forUtf16Offset: lineRange.location)
        return textView.lineGeometryStore.estimatedRect(forLineAt: lineIndex, containerWidth: textView.bounds.width)
    }

    /// Get the visible rect for the text view (platform-agnostic)
    public func getVisibleRect() -> CGRect {
        guard let textView else { return .zero }

        #if canImport(AppKit)
        // macOS: Use the visible rect
        return textView.visibleRect
        #else
        // iOS: Calculate from content offset and bounds
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

        if textView.lineGeometryStore.lineCount > 0 {
            let lineIndex = textView.lineGeometryStore.lineIndex(at: adjustedPoint)
            return min(lineIndex + 1, textView.lineGeometryStore.lineCount)
        }

        // Defensive: textLayoutManager should always be present (TextKit2-only
        // since 0.2.0). Estimate by line height if it isn't.
        return estimateLineNumber(at: adjustedPoint, text: text)
    }

    // MARK: - Private Helpers

    /// Calculate line ranges from text without using layoutManager
    private func calculateLineRanges(in text: String, visibleRange: NSRange) -> [(lineNumber: Int, range: NSRange)] {
        // Use the line geometry store for O(log n) lookup
        if let textView {
            let store = textView.lineGeometryStore
            let geometries = store.lineGeometries(in: visibleRange)
            var result: [(lineNumber: Int, range: NSRange)] = []
            var lineIdx = store.lineIndex(forUtf16Offset: visibleRange.location)
            for geom in geometries {
                let offset = store.utf16Offset(forLineIndex: lineIdx)
                let range = NSRange(location: offset, length: geom.utf16Length)
                result.append((lineNumber: lineIdx + 1, range: range))
                lineIdx += 1
            }
            return result
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

        #if canImport(AppKit)
        // macOS: Point is already in the correct coordinate system
        return point
        #else
        // iOS: Account for text container inset and scroll offset
        let textContainerInset = textView.textContainerInset
        return CGPoint(
            x: point.x,
            y: point.y + textView.contentOffset.y - textContainerInset.top
        )
        #endif
    }

    private func firstVisualLineFragmentRect(
        in layoutFragment: NSTextLayoutFragment,
        containing location: NSTextLocation,
        fallbackLineRange: NSRange
    ) -> CGRect? {
        guard let textContentManager = layoutFragment.textLayoutManager?.textContentManager else {
            return nil
        }

        let lineFragment = layoutFragment.textLineFragment(at: location, in: textContentManager)
            ?? layoutFragment.textLineFragments.first { lineFragment in
                guard let lineRange = lineFragment.textRange(in: layoutFragment)
                    .flatMap(textKitBridge.nsRangeFromTextRange)
                else { return false }

                return Self.rangesIntersect(lineRange, fallbackLineRange)
            }
            ?? layoutFragment.textLineFragments.first { !$0.isExtraLineFragment }

        guard let lineFragment else { return nil }

        let bounds = lineFragment.typographicBounds
        let fragmentFrame = layoutFragment.layoutFragmentFrame
        return CGRect(
            x: fragmentFrame.minX + bounds.minX,
            y: fragmentFrame.minY + bounds.minY,
            width: bounds.width,
            height: bounds.height
        )
    }

    private static func rangesIntersect(_ first: NSRange, _ second: NSRange) -> Bool {
        first.location < second.upperBound && second.location < first.upperBound
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
                    // Calculate line number up to this fragment using geometry store
                    if let fragmentRange = self.textKitBridge.nsRangeFromTextRange(fragment.rangeInElement) {
                        let lineIdx = textView.lineGeometryStore.lineIndex(forUtf16Offset: fragmentRange.location)
                        foundLine = lineIdx + 1 // 1-based
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

    /// Estimate line number based on approximate line height
    private func estimateLineNumber(at point: CGPoint, text _: String) -> Int? {
        guard let textView else { return nil }

        // Get an approximate line height
        let font = textView.font ?? PlatformFonts.monospacedSystemFont(ofSize: 12, weight: .regular)
        let lineHeight = TextMetricsCalculator.calculateLineHeight(for: font)

        // Estimate line number
        let estimatedLine = Int(point.y / lineHeight) + 1

        // Clamp to valid range using geometry store
        let totalLines = textView.lineGeometryStore.lineCount
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
