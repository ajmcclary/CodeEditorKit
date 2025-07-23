import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Helper for managing cross-platform coordinate system differences
@MainActor
class CoordinateSystemHelper {
    // MARK: - Properties

    private let logger = CrossPlatformLogger.logger()

    /// Current coordinate system type
    var coordinateSystem: CoordinateSystemType {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return .macOS
        #else
        return .iOS
        #endif
    }

    // MARK: - Types

    /// Coordinate system types
    enum CoordinateSystemType {
        case macOS  // Origin at bottom-left, y increases upward
        case iOS    // Origin at top-left, y increases downward

        var isFlipped: Bool {
            switch self {
            case .macOS: return false
            case .iOS: return true
            }
        }
    }

    /// Unified point representation
    struct UnifiedPoint {
        let x: CGFloat
        let y: CGFloat
        let coordinateSystem: CoordinateSystemType

        init(x: CGFloat, y: CGFloat, in system: CoordinateSystemType) {
            self.x = x
            self.y = y
            self.coordinateSystem = system
        }

        /// Convert to CGPoint in specified coordinate system
        func cgPoint(in targetSystem: CoordinateSystemType, containerHeight: CGFloat) -> CGPoint {
            if coordinateSystem == targetSystem {
                return CGPoint(x: x, y: y)
            }

            // Need to flip Y coordinate
            let flippedY = containerHeight - y
            return CGPoint(x: x, y: flippedY)
        }

        /// Convert to platform-native point
        var platformPoint: CGPoint {
            CGPoint(x: x, y: y)
        }
    }

    /// Unified rect representation
    struct UnifiedRect {
        let origin: UnifiedPoint
        let size: CGSize

        var minX: CGFloat { origin.x }
        var minY: CGFloat { origin.y }
        var maxX: CGFloat { origin.x + size.width }
        var maxY: CGFloat { origin.y + size.height }

        init(origin: UnifiedPoint, size: CGSize) {
            self.origin = origin
            self.size = size
        }

        init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, in system: CoordinateSystemType) {
            self.origin = UnifiedPoint(x: x, y: y, in: system)
            self.size = CGSize(width: width, height: height)
        }

        /// Convert to CGRect in specified coordinate system
        func cgRect(in targetSystem: CoordinateSystemType, containerHeight: CGFloat) -> CGRect {
            let convertedOrigin = origin.cgPoint(in: targetSystem, containerHeight: containerHeight)

            // When flipping coordinate systems, we need to adjust the origin
            if origin.coordinateSystem != targetSystem {
                // The rect's origin needs to be at the top-left in the new system
                let adjustedY = convertedOrigin.y - size.height
                return CGRect(x: convertedOrigin.x, y: adjustedY, width: size.width, height: size.height)
            }

            return CGRect(origin: convertedOrigin, size: size)
        }

        /// Convert to platform-native rect
        var platformRect: CGRect {
            CGRect(origin: origin.platformPoint, size: size)
        }
    }

    // MARK: - Public Methods

    /// Convert point from one coordinate system to another
    func convertPoint(
        _ point: CGPoint,
        from sourceSystem: CoordinateSystemType,
        to targetSystem: CoordinateSystemType,
        containerHeight: CGFloat
    ) -> CGPoint {
        if sourceSystem == targetSystem {
            return point
        }

        // Flip Y coordinate
        return CGPoint(x: point.x, y: containerHeight - point.y)
    }

    /// Convert rect from one coordinate system to another
    func convertRect(
        _ rect: CGRect,
        from sourceSystem: CoordinateSystemType,
        to targetSystem: CoordinateSystemType,
        containerHeight: CGFloat
    ) -> CGRect {
        if sourceSystem == targetSystem {
            return rect
        }

        // Convert origin (bottom-left in source becomes top-left after flip)
        let flippedY = containerHeight - (rect.origin.y + rect.height)
        return CGRect(x: rect.origin.x, y: flippedY, width: rect.width, height: rect.height)
    }

    /// Convert text range to visual rect
    func textRangeToRect(
        range: NSRange,
        in textView: CodeEditorView
    ) -> UnifiedRect? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return nil
        }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // Add container origin offset
        let textOrigin = textView.textContainerInset
        let adjustedRect = boundingRect.offsetBy(dx: textOrigin.width, dy: textOrigin.height)
        #elseif targetEnvironment(macCatalyst)
        // Mac Catalyst: Use text position APIs to avoid triggering TextKit1 mode
        guard let text = textView.text,
              let stringRange = Range(range, in: text) else {
            return nil
        }

        // Get start and end positions
        let startOffset = text.distance(from: text.startIndex, to: stringRange.lowerBound)
        let endOffset = text.distance(from: text.startIndex, to: stringRange.upperBound)

        guard let startPosition = textView.position(from: textView.beginningOfDocument, offset: startOffset),
              let endPosition = textView.position(from: textView.beginningOfDocument, offset: endOffset),
              let textRange = textView.textRange(from: startPosition, to: endPosition) else {
            return nil
        }

        // Get the bounding rect
        let rects = textView.selectionRects(for: textRange)
        guard !rects.isEmpty else { return nil }

        // Combine all rects
        var boundingRect = rects[0].rect
        for rect in rects.dropFirst() {
            boundingRect = boundingRect.union(rect.rect)
        }

        // Already includes container inset
        let adjustedRect = boundingRect

        #else
        // iOS: Access layoutManager directly
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // Add container origin offset
        let textOrigin = textView.textContainerInset
        let adjustedRect = boundingRect.offsetBy(dx: textOrigin.left, dy: textOrigin.top)
        #endif

        return UnifiedRect(
            x: adjustedRect.minX,
            y: adjustedRect.minY,
            width: adjustedRect.width,
            height: adjustedRect.height,
            in: coordinateSystem
        )
    }

    /// Convert point to text position
    func pointToTextPosition(
        _ point: UnifiedPoint,
        in textView: CodeEditorView
    ) -> Int? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return nil
        }
        // Convert to view coordinates
        let viewPoint = point.cgPoint(in: coordinateSystem, containerHeight: textView.bounds.height)

        // Adjust for text container inset
        let textOrigin = textView.textContainerInset
        let adjustedPoint = CGPoint(
            x: viewPoint.x - textOrigin.width,
            y: viewPoint.y - textOrigin.height
        )

        // Find character index
        return layoutManager.characterIndex(
            for: adjustedPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        #elseif targetEnvironment(macCatalyst)
        // Mac Catalyst: Use text position APIs to avoid triggering TextKit1 mode
        let viewPoint = point.cgPoint(in: coordinateSystem, containerHeight: textView.bounds.height)

        // Use closestPosition to find character index
        guard let position = textView.closestPosition(to: viewPoint) else {
            return nil
        }

        return textView.offset(from: textView.beginningOfDocument, to: position)

        #else
        // iOS: Access layoutManager directly
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        // Convert to view coordinates
        let viewPoint = point.cgPoint(in: coordinateSystem, containerHeight: textView.bounds.height)

        // Adjust for text container inset
        let textOrigin = textView.textContainerInset
        let adjustedPoint = CGPoint(
            x: viewPoint.x - textOrigin.left,
            y: viewPoint.y - textOrigin.top
        )

        // Find character index
        return layoutManager.characterIndex(
            for: adjustedPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        #endif
    }

    /// Calculate visible rect in text coordinates
    func visibleTextRect(for scrollView: PlatformScrollView) -> UnifiedRect {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let visibleRect = scrollView.visibleRect
        #else
        let visibleRect = CGRect(
            origin: scrollView.contentOffset,
            size: scrollView.bounds.size
        )
        #endif

        return UnifiedRect(
            x: visibleRect.origin.x,
            y: visibleRect.origin.y,
            width: visibleRect.width,
            height: visibleRect.height,
            in: coordinateSystem
        )
    }

    /// Convert between view and window coordinates
    func convertToWindow(
        _ point: UnifiedPoint,
        from view: PlatformView
    ) -> UnifiedPoint? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let windowPoint = view.convert(point.platformPoint, to: nil)
        return UnifiedPoint(x: windowPoint.x, y: windowPoint.y, in: .macOS)
        #else
        guard let window = view.window else { return nil }
        let windowPoint = view.convert(point.platformPoint, to: window)
        return UnifiedPoint(x: windowPoint.x, y: windowPoint.y, in: .iOS)
        #endif
    }

    /// Convert between window and screen coordinates
    func convertToScreen(
        _ point: UnifiedPoint,
        from window: PlatformWindow
    ) -> UnifiedPoint? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let screenPoint = window.convertPoint(toScreen: point.platformPoint)
        return UnifiedPoint(x: screenPoint.x, y: screenPoint.y, in: .macOS)
        #else
        let screenPoint = window.convert(point.platformPoint, to: nil)
        return UnifiedPoint(x: screenPoint.x, y: screenPoint.y, in: .iOS)
        #endif
    }

    /// Calculate scroll offset to make rect visible
    func scrollOffsetToMakeVisible(
        _ rect: UnifiedRect,
        in scrollView: PlatformScrollView,
        withInsets insets: EdgeInsets = EdgeInsets()
    ) -> CGPoint {
        let visibleRect = visibleTextRect(for: scrollView)
        let containerHeight = scrollView.bounds.height

        // Convert rects to same coordinate system
        let targetRect = rect.cgRect(in: coordinateSystem, containerHeight: containerHeight)
        let currentVisible = visibleRect.cgRect(in: coordinateSystem, containerHeight: containerHeight)

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        var newOffset = scrollView.contentView.bounds.origin
        #else
        var newOffset = scrollView.contentOffset
        #endif

        // Horizontal adjustment
        if targetRect.minX < currentVisible.minX + insets.left {
            newOffset.x = targetRect.minX - insets.left
        } else if targetRect.maxX > currentVisible.maxX - insets.right {
            newOffset.x = targetRect.maxX - scrollView.bounds.width + insets.right
        }

        // Vertical adjustment
        if targetRect.minY < currentVisible.minY + insets.top {
            newOffset.y = targetRect.minY - insets.top
        } else if targetRect.maxY > currentVisible.maxY - insets.bottom {
            newOffset.y = targetRect.maxY - scrollView.bounds.height + insets.bottom
        }

        // Clamp to valid range
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let contentSize = scrollView.documentView?.bounds.size ?? CGSize.zero
        #else
        let contentSize = scrollView.contentSize
        #endif
        newOffset.x = max(0, min(newOffset.x, contentSize.width - scrollView.bounds.width))
        newOffset.y = max(0, min(newOffset.y, contentSize.height - scrollView.bounds.height))

        return newOffset
    }

    /// Convert mouse/touch event location
    func eventLocationInView(
        _ event: PlatformEvent,
        view: PlatformView
    ) -> UnifiedPoint {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let locationInWindow = event.locationInWindow
        let locationInView = view.convert(locationInWindow, from: nil)
        return UnifiedPoint(x: locationInView.x, y: locationInView.y, in: .macOS)
        #else
        // On iOS, we need to get location from the first touch
        if let touch = event.allTouches?.first {
            let locationInView = touch.location(in: view)
            return UnifiedPoint(x: locationInView.x, y: locationInView.y, in: .iOS)
        } else {
            // Fallback to center of view if no touches available
            return UnifiedPoint(x: view.bounds.midX, y: view.bounds.midY, in: .iOS)
        }
        #endif
    }

    /// Hit test for UI elements
    func hitTest(
        point: UnifiedPoint,
        in rects: [(id: String, rect: UnifiedRect)]
    ) -> String? {
        let containerHeight: CGFloat = 1_000 // Default height for comparison

        for (id, rect) in rects {
            let testRect = rect.cgRect(in: point.coordinateSystem, containerHeight: containerHeight)
            let testPoint = point.cgPoint(in: point.coordinateSystem, containerHeight: containerHeight)

            if testRect.contains(testPoint) {
                return id
            }
        }

        return nil
    }

    /// Calculate layout metrics
    func calculateLayoutMetrics(
        for textView: CodeEditorView,
        lineHeight: CGFloat
    ) -> LayoutMetrics {
        let bounds = textView.bounds
        let textInset = textView.textContainerInset

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let textAreaRect = UnifiedRect(
            x: textInset.width,
            y: textInset.height,
            width: bounds.width - textInset.width * 2,
            height: bounds.height - textInset.height * 2,
            in: coordinateSystem
        )
        #else
        let textAreaRect = UnifiedRect(
            x: textInset.left,
            y: textInset.top,
            width: bounds.width - textInset.left - textInset.right,
            height: bounds.height - textInset.top - textInset.bottom,
            in: coordinateSystem
        )
        #endif

        let visibleLines = Int(textAreaRect.size.height / lineHeight)
        let scrollView = textView.crossPlatformEnclosingScrollView
        let firstVisibleLine: Int
        if let scrollView {
            firstVisibleLine = Int(visibleTextRect(for: scrollView).origin.y / lineHeight)
        } else {
            // Fallback: assume we're looking at the top of the document
            firstVisibleLine = 0
        }

        return LayoutMetrics(
            textAreaRect: textAreaRect,
            lineHeight: lineHeight,
            visibleLines: visibleLines,
            firstVisibleLine: firstVisibleLine,
            contentHeight: textView.intrinsicContentSize.height
        )
    }

    /// Create drawing context with correct coordinate system
    func createDrawingContext(
        for view: PlatformView,
        in context: CGContext
    ) -> DrawingContext {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS contexts may need flipping
        if view.isFlipped {
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: 0, y: -view.bounds.height)
        }
        #else
        // iOS contexts are already flipped
        #endif

        return DrawingContext(
            cgContext: context,
            coordinateSystem: coordinateSystem,
            bounds: view.bounds
        )
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - Supporting Types

/// Edge insets
public struct EdgeInsets: Sendable, Equatable {
    public let top: CGFloat
    public let left: CGFloat
    public let bottom: CGFloat
    public let right: CGFloat

    public init(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public static let zero = Self()
}

/// Layout metrics
struct LayoutMetrics {
    let textAreaRect: CoordinateSystemHelper.UnifiedRect
    let lineHeight: CGFloat
    let visibleLines: Int
    let firstVisibleLine: Int
    let contentHeight: CGFloat
}

/// Drawing context wrapper
struct DrawingContext {
    let cgContext: CGContext
    let coordinateSystem: CoordinateSystemHelper.CoordinateSystemType
    let bounds: CGRect

    /// Draw line between two points
    func drawLine(from: CoordinateSystemHelper.UnifiedPoint, to: CoordinateSystemHelper.UnifiedPoint) {
        let fromPoint = from.cgPoint(in: coordinateSystem, containerHeight: bounds.height)
        let toPoint = to.cgPoint(in: coordinateSystem, containerHeight: bounds.height)

        cgContext.move(to: fromPoint)
        cgContext.addLine(to: toPoint)
        cgContext.strokePath()
    }

    /// Draw rect
    func drawRect(_ rect: CoordinateSystemHelper.UnifiedRect) {
        let cgRect = rect.cgRect(in: coordinateSystem, containerHeight: bounds.height)
        cgContext.addRect(cgRect)
        cgContext.strokePath()
    }

    /// Fill rect
    func fillRect(_ rect: CoordinateSystemHelper.UnifiedRect) {
        let cgRect = rect.cgRect(in: coordinateSystem, containerHeight: bounds.height)
        cgContext.fill(cgRect)
    }

    /// Draw text at point
    func drawText(
        _ text: String,
        at point: CoordinateSystemHelper.UnifiedPoint,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let drawPoint = point.cgPoint(in: coordinateSystem, containerHeight: bounds.height)

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // swiftlint:disable:next legacy_objc_type
        let nsText = NSString(string: text)
        nsText.draw(at: drawPoint, withAttributes: attributes)
        #else
        // swiftlint:disable:next legacy_objc_type
        let nsText = NSString(string: text)
        nsText.draw(at: drawPoint, withAttributes: attributes)
        #endif
    }
}

// MARK: - Platform Type Aliases

// Note: Platform type aliases are defined in PlatformImports.swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
public typealias PlatformWindow = NSWindow
#else
public typealias PlatformWindow = UIWindow
#endif

// MARK: - Geometry Extensions

extension CGRect {
    /// Offset rect by dx and dy
    func offsetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        CGRect(x: origin.x + dx, y: origin.y + dy, width: width, height: height)
    }
}

extension CodeEditorView {
    /// Get enclosing scroll view
    var crossPlatformEnclosingScrollView: PlatformScrollView? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return super.enclosingScrollView
        #else
        // On iOS, UITextView is itself a UIScrollView
        return self
        #endif
    }

    /// Platform-specific content offset
    var crossPlatformContentOffset: CGPoint {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return crossPlatformEnclosingScrollView?.contentView.bounds.origin ?? .zero
        #else
        return super.contentOffset
        #endif
    }
}
