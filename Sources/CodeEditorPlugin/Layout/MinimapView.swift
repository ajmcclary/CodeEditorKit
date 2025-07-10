import CoreGraphics
import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Cross-Platform Minimap Types

// Use centralized platform types from PlatformImports
// PlatformView, PlatformColor, and PlatformFont are imported from PlatformImports.swift
public typealias MinimapPlatformView = PlatformView
public typealias MinimapPlatformRect = CGRect
public typealias MinimapPlatformPoint = CGPoint

// MARK: - Minimap Configuration

/// Configuration for minimap appearance and behavior
public struct MinimapConfiguration: Sendable {
    /// Width of the minimap in points
    public var width: CGFloat = 120
    
    /// Font size for minimap text rendering
    public var fontSize: CGFloat = 2.0
    
    /// Line height multiplier for minimap
    public var lineHeight: CGFloat = 1.0
    
    /// Maximum number of lines to render in minimap for performance
    public var maxLines: Int = 10_000
    
    public init() {}
    
    // Default colors using consistent PlatformColors
    public static var defaultBackgroundColor: PlatformColor {
        PlatformColors.controlBackground
    }
    
    public static var defaultTextColor: PlatformColor {
        PlatformColors.secondaryLabel
    }
    
    public static var defaultViewportColor: PlatformColor {
        PlatformColors.systemBlue.withAlphaComponent(0.3)
    }
    
    public static var defaultViewportBorderColor: PlatformColor {
        PlatformColors.systemBlue
    }
}

// MARK: - Minimap Data Model

/// Represents the content and layout information for the minimap
public struct MinimapData: Sendable {
    /// Total number of lines in the document
    public let totalLines: Int
    
    /// Currently visible line range in the main editor
    public let visibleLineRange: Range<Int>
    
    /// Lines of text to display (may be subset for performance)
    public let displayLines: [String]
    
    /// Starting line number for the display lines
    public let displayStartLine: Int
    
    /// Character width in the minimap font
    public let characterWidth: CGFloat
    
    /// Line height in the minimap font
    public let lineHeight: CGFloat
    
    public init(
        totalLines: Int,
        visibleLineRange: Range<Int>,
        displayLines: [String],
        displayStartLine: Int,
        characterWidth: CGFloat,
        lineHeight: CGFloat
    ) {
        self.totalLines = totalLines
        self.visibleLineRange = visibleLineRange
        self.displayLines = displayLines
        self.displayStartLine = displayStartLine
        self.characterWidth = characterWidth
        self.lineHeight = lineHeight
    }
}

// MARK: - Minimap View Protocol

/// Protocol defining minimap functionality across platforms
@MainActor public protocol MinimapViewProtocol: AnyObject {
    /// Configuration for the minimap
    var configuration: MinimapConfiguration { get set }
    
    /// Current minimap data
    var data: MinimapData? { get set }
    
    /// Callback when user taps/clicks on minimap to navigate
    var onNavigate: ((Int) -> Void)? { get set }
    
    /// Update the minimap with new data
    func updateData(_ data: MinimapData?)
    
    /// Get the line number at a given point
    func lineNumber(at point: MinimapPlatformPoint) -> Int?
}

// MARK: - Base Minimap Implementation

/// Shared minimap rendering logic
public enum MinimapRenderer {
    @MainActor
    public static func calculateCharacterMetrics(font: PlatformFont) -> (width: CGFloat, height: CGFloat) {
        let metrics = font.metrics
        return (metrics.averageCharacterWidth, metrics.lineHeight)
    }
    
    public static func calculateContentHeight(lineCount: Int, lineHeight: CGFloat) -> CGFloat {
        CGFloat(lineCount) * lineHeight
    }
    
    public static func viewportRect(
        for visibleRange: Range<Int>,
        lineHeight: CGFloat,
        minimapWidth: CGFloat,
        totalLines _: Int,
        minimapHeight: CGFloat
    ) -> MinimapPlatformRect {
        let startY = CGFloat(visibleRange.lowerBound) * lineHeight
        let height = CGFloat(visibleRange.count) * lineHeight
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // On macOS, coordinate system is flipped
        let adjustedY = minimapHeight - startY - height
        return NSRect(x: 0, y: adjustedY, width: minimapWidth, height: height)
        #else
        return CGRect(x: 0, y: startY, width: minimapWidth, height: height)
        #endif
    }
    
    public static func lineNumber(
        at point: MinimapPlatformPoint,
        lineHeight: CGFloat,
        totalLines: Int,
        minimapHeight: CGFloat
    ) -> Int {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // On macOS, coordinate system is flipped
        let adjustedY = minimapHeight - point.y
        let line = Int(adjustedY / lineHeight)
        #else
        let line = Int(point.y / lineHeight)
        #endif
        
        return max(0, min(line, totalLines - 1))
    }
}

// MARK: - Platform-Specific Implementations

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
/// AppKit implementation of minimap view
@MainActor
public final class AppKitMinimapView: NSView, MinimapViewProtocol {
    public var configuration = MinimapConfiguration() {
        didSet { needsDisplay = true }
    }
    
    public var data: MinimapData? {
        didSet { needsDisplay = true }
    }
    
    public var onNavigate: ((Int) -> Void)?
    
    private var trackingArea: NSTrackingArea?
    
    // Mark view as opaque for proper rendering
    override public var isOpaque: Bool {
        true
    }
    
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = MinimapConfiguration.defaultBackgroundColor.cgColor
        layer?.borderWidth = 1.0
        layer?.borderColor = PlatformColors.separator.cgColor
        
        // Set view properties
        alphaValue = 1.0
        autoresizingMask = [.minXMargin, .height]
        
        // Ensure the view is opaque and draws its background
        layer?.isOpaque = true
        layer?.needsDisplayOnBoundsChange = true
        
        // Don't clip - allow drawing outside bounds if needed
        clipsToBounds = false
        
        // Enable mouse tracking
        updateTrackingAreas()
    }
    
    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Always fill the entire background first
        MinimapConfiguration.defaultBackgroundColor.setFill()
        bounds.fill()
        
        // Draw a subtle border to make the minimap visible even without content
        PlatformColors.separator.setStroke()
        let borderPath = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        borderPath.lineWidth = 1.0
        borderPath.stroke()
        
        guard let data else {
            // Draw placeholder text when no data
            let placeholderText = "No content"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: PlatformFonts.systemFont(ofSize: 10),
                .foregroundColor: PlatformColors.tertiaryLabel
            ]
            let textSize = placeholderText.size(withAttributes: attributes)
            let textPoint = NSPoint(
                x: (bounds.width - textSize.width) / 2,
                y: (bounds.height - textSize.height) / 2
            )
            placeholderText.draw(at: textPoint, withAttributes: attributes)
            return
        }
        
        // Draw text lines
        drawTextLines(data: data)
        
        // Draw viewport indicator
        drawViewportIndicator(data: data)
    }
    
    private func drawTextLines(data: MinimapData) {
        let font = PlatformFonts.monospacedSystemFont(ofSize: configuration.fontSize, weight: .regular)
        let textColor = MinimapConfiguration.defaultTextColor
        
        for (index, line) in data.displayLines.enumerated() {
            let lineNumber = data.displayStartLine + index
            let y = CGFloat(lineNumber) * data.lineHeight
            
            // Skip lines outside visible area for performance
            if y + data.lineHeight < 0 || y > bounds.height { continue }
            
            let point = NSPoint(x: 2, y: bounds.height - y - data.lineHeight)
            
            // Use UnifiedDrawingCoordinator for text drawing
            UnifiedDrawingCoordinator.drawMinimapLine(
                line,
                at: point,
                font: font,
                color: textColor,
                maxWidth: bounds.width - 4
            )
        }
    }
    
    private func drawViewportIndicator(data: MinimapData) {
        let viewportRect = MinimapRenderer.viewportRect(
            for: data.visibleLineRange,
            lineHeight: data.lineHeight,
            minimapWidth: bounds.width,
            totalLines: data.totalLines,
            minimapHeight: bounds.height
        )
        
        // Use UnifiedDrawingCoordinator for viewport indicator
        UnifiedDrawingCoordinator.drawViewportIndicator(
            in: viewportRect,
            backgroundColor: MinimapConfiguration.defaultViewportColor,
            borderColor: MinimapConfiguration.defaultViewportBorderColor,
            borderWidth: 1.0
        )
    }
    
    override public func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let line = lineNumber(at: point) {
            onNavigate?(line)
        }
    }
    
    public func updateData(_ data: MinimapData?) {
        self.data = data
    }
    
    public func lineNumber(at point: NSPoint) -> Int? {
        guard let data else { return nil }
        
        return MinimapRenderer.lineNumber(
            at: point,
            lineHeight: data.lineHeight,
            totalLines: data.totalLines,
            minimapHeight: bounds.height
        )
    }
}

public typealias MinimapView = AppKitMinimapView

#elseif canImport(UIKit)
/// UIKit implementation of minimap view
@MainActor
public final class UIKitMinimapView: UIView, MinimapViewProtocol {
    public var configuration = MinimapConfiguration() {
        didSet { setNeedsDisplay() }
    }
    
    public var data: MinimapData? {
        didSet { setNeedsDisplay() }
    }
    
    public var onNavigate: ((Int) -> Void)?
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = MinimapConfiguration.defaultBackgroundColor
        isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        if let line = lineNumber(at: point) {
            onNavigate?(line)
        }
    }
    
    override public func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Always fill the entire background first
        context.setFillColor(MinimapConfiguration.defaultBackgroundColor.cgColor)
        context.fill(bounds)
        
        // Draw a subtle border to make the minimap visible even without content
        context.setStrokeColor(PlatformColors.separator.cgColor)
        context.setLineWidth(1.0)
        context.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))
        
        guard let data else {
            // Draw placeholder text when no data
            let placeholderText = "No content"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: PlatformFonts.systemFont(ofSize: 10),
                .foregroundColor: PlatformColors.tertiaryLabel
            ]
            let textSize = placeholderText.size(withAttributes: attributes)
            let textPoint = CGPoint(
                x: (bounds.width - textSize.width) / 2,
                y: (bounds.height - textSize.height) / 2
            )
            placeholderText.draw(at: textPoint, withAttributes: attributes)
            return
        }
        
        // Draw text lines
        drawTextLines(data: data)
        
        // Draw viewport indicator
        drawViewportIndicator(data: data)
    }
    
    private func drawTextLines(data: MinimapData) {
        let font = PlatformFonts.monospacedSystemFont(ofSize: configuration.fontSize, weight: .regular)
        let textColor = MinimapConfiguration.defaultTextColor
        
        for (index, line) in data.displayLines.enumerated() {
            let lineNumber = data.displayStartLine + index
            let y = CGFloat(lineNumber) * data.lineHeight
            
            // Skip lines outside visible area for performance
            if y + data.lineHeight < 0 || y > bounds.height { continue }
            
            let point = CGPoint(x: 2, y: y)
            
            // Use UnifiedDrawingCoordinator for text drawing
            UnifiedDrawingCoordinator.drawMinimapLine(
                line,
                at: point,
                font: font,
                color: textColor,
                maxWidth: bounds.width - 4
            )
        }
    }
    
    private func drawViewportIndicator(data: MinimapData) {
        let viewportRect = MinimapRenderer.viewportRect(
            for: data.visibleLineRange,
            lineHeight: data.lineHeight,
            minimapWidth: bounds.width,
            totalLines: data.totalLines,
            minimapHeight: bounds.height
        )
        
        // Use UnifiedDrawingCoordinator for viewport indicator
        UnifiedDrawingCoordinator.drawViewportIndicator(
            in: viewportRect,
            backgroundColor: MinimapConfiguration.defaultViewportColor,
            borderColor: MinimapConfiguration.defaultViewportBorderColor,
            borderWidth: 1.0
        )
    }
    
    public func updateData(_ data: MinimapData?) {
        self.data = data
    }
    
    public func lineNumber(at point: CGPoint) -> Int? {
        guard let data else { return nil }
        
        return MinimapRenderer.lineNumber(
            at: point,
            lineHeight: data.lineHeight,
            totalLines: data.totalLines,
            minimapHeight: bounds.height
        )
    }
}

public typealias MinimapView = UIKitMinimapView

#endif

// MARK: - Minimap Data Provider

/// Provides data for minimap from a text view
@MainActor public final class MinimapDataProvider {
    private weak var textView: CodeEditorView?
    private let configuration: MinimapConfiguration
    
    public init(textView: CodeEditorView, configuration: MinimapConfiguration = MinimapConfiguration()) {
        self.textView = textView
        self.configuration = configuration
    }
    
    /// Generate minimap data from current text view state
    public func generateData() -> MinimapData? {
        guard let textView else { return nil }
        
        let text = textView.text ?? ""
        let lines = text.components(separatedBy: .newlines)
        
        // Calculate font metrics using TextMetricsCalculator
        let font = PlatformFont.monospacedSystemFont(ofSize: configuration.fontSize, weight: .regular)
        let metrics = font.metrics
        let lineHeight = metrics.lineHeight * configuration.lineHeight
        
        // Determine visible line range (simplified for now)
        let visibleRange = getVisibleLineRange(textView: textView, totalLines: lines.count)
        
        // For performance, limit the number of lines we render
        let displayLines: [String]
        let displayStartLine: Int
        
        if lines.count <= configuration.maxLines {
            displayLines = lines
            displayStartLine = 0
        } else {
            // Show lines around the visible area
            let contextLines = configuration.maxLines / 2
            let startLine = max(0, visibleRange.lowerBound - contextLines)
            let endLine = min(lines.count, startLine + configuration.maxLines)
            
            displayLines = Array(lines[startLine..<endLine])
            displayStartLine = startLine
        }
        
        // Truncate long lines for performance
        let truncatedLines = displayLines.map { line in
            line.count > 100 ? String(line.prefix(100)) : line
        }
        
        return MinimapData(
            totalLines: lines.count,
            visibleLineRange: visibleRange,
            displayLines: truncatedLines,
            displayStartLine: displayStartLine,
            characterWidth: metrics.averageCharacterWidth,
            lineHeight: lineHeight
        )
    }
    
    private func getVisibleLineRange(textView: CodeEditorView, totalLines: Int) -> Range<Int> {
        // Use UnifiedDrawingCoordinator to calculate visible text area
        let visibleRect = UnifiedDrawingCoordinator.calculateVisibleTextRect(for: textView)
        let lineHeight = textView.font?.pointSize ?? 16.0
        
        // Calculate visible lines using TextMetricsCalculator
        return TextMetricsCalculator.calculateVisibleLines(
            in: visibleRect,
            lineHeight: lineHeight,
            totalLines: totalLines,
            contentOffset: visibleRect.origin
        )
    }
}
