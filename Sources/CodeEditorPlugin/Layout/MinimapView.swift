import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Cross-Platform Minimap Types

#if canImport(AppKit)
public typealias MinimapPlatformView = NSView
public typealias MinimapPlatformColor = NSColor
public typealias MinimapPlatformFont = NSFont
public typealias MinimapPlatformRect = NSRect
public typealias MinimapPlatformSize = NSSize
public typealias MinimapPlatformPoint = NSPoint
#elseif canImport(UIKit)
public typealias MinimapPlatformView = UIView
public typealias MinimapPlatformColor = UIColor
public typealias MinimapPlatformFont = UIFont
public typealias MinimapPlatformRect = CGRect
public typealias MinimapPlatformSize = CGSize
public typealias MinimapPlatformPoint = CGPoint
#endif

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
    
    // Default colors
    public static var defaultBackgroundColor: MinimapPlatformColor {
        #if canImport(AppKit)
        return NSColor.controlBackgroundColor
        #else
        return UIColor.systemBackground
        #endif
    }
    
    public static var defaultTextColor: MinimapPlatformColor {
        #if canImport(AppKit)
        return NSColor.secondaryLabelColor
        #else
        return UIColor.secondaryLabel
        #endif
    }
    
    public static var defaultViewportColor: MinimapPlatformColor {
        #if canImport(AppKit)
        return NSColor.selectedControlColor.withAlphaComponent(0.3)
        #else
        return UIColor.systemBlue.withAlphaComponent(0.3)
        #endif
    }
    
    public static var defaultViewportBorderColor: MinimapPlatformColor {
        #if canImport(AppKit)
        return NSColor.selectedControlColor
        #else
        return UIColor.systemBlue
        #endif
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
    func updateData(_ data: MinimapData)
    
    /// Get the line number at a given point
    func lineNumber(at point: MinimapPlatformPoint) -> Int?
}

// MARK: - Base Minimap Implementation

/// Shared minimap rendering logic
public enum MinimapRenderer {
    public static func calculateCharacterMetrics(font: MinimapPlatformFont) -> (width: CGFloat, height: CGFloat) {
        #if canImport(AppKit)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = ("M" as String).size(withAttributes: attributes)
        return (size.width, size.height)
        #else
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = ("M" as String).size(withAttributes: attributes)
        return (size.width, size.height)
        #endif
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
        
        #if canImport(AppKit)
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
        #if canImport(AppKit)
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

#if canImport(AppKit)
/// AppKit implementation of minimap view
@MainActor
public final class AppKitMinimapView: NSView, MinimapViewProtocol {
    deinit {}
    
    public var configuration = MinimapConfiguration() {
        didSet { needsDisplay = true }
    }
    
    public var data: MinimapData? {
        didSet { needsDisplay = true }
    }
    
    public var onNavigate: ((Int) -> Void)?
    
    private var trackingArea: NSTrackingArea?
    
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
        
        guard let data, let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Clear background
        MinimapConfiguration.defaultBackgroundColor.setFill()
        dirtyRect.fill()
        
        // Draw text lines
        drawTextLines(data: data, context: context)
        
        // Draw viewport indicator
        drawViewportIndicator(data: data, context: context)
    }
    
    private func drawTextLines(data: MinimapData, context _: CGContext) {
        let font = NSFont.monospacedSystemFont(ofSize: configuration.fontSize, weight: .regular)
        let textColor = MinimapConfiguration.defaultTextColor
        
        for (index, line) in data.displayLines.enumerated() {
            let lineNumber = data.displayStartLine + index
            let y = CGFloat(lineNumber) * data.lineHeight
            
            // Skip lines outside visible area for performance
            if y + data.lineHeight < 0 || y > bounds.height { continue }
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            
            let attributedString = NSAttributedString(string: line, attributes: attributes)
            let point = NSPoint(x: 2, y: bounds.height - y - data.lineHeight)
            attributedString.draw(at: point)
        }
    }
    
    private func drawViewportIndicator(data: MinimapData, context: CGContext) {
        let viewportRect = MinimapRenderer.viewportRect(
            for: data.visibleLineRange,
            lineHeight: data.lineHeight,
            minimapWidth: bounds.width,
            totalLines: data.totalLines,
            minimapHeight: bounds.height
        )
        
        // Fill viewport area
        context.setFillColor(MinimapConfiguration.defaultViewportColor.cgColor)
        context.fill(viewportRect)
        
        // Draw viewport border
        context.setStrokeColor(MinimapConfiguration.defaultViewportBorderColor.cgColor)
        context.setLineWidth(1.0)
        context.stroke(viewportRect)
    }
    
    override public func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let line = lineNumber(at: point) {
            onNavigate?(line)
        }
    }
    
    public func updateData(_ data: MinimapData) {
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
    deinit {}
    
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
        
        guard let data, let context = UIGraphicsGetCurrentContext() else { return }
        
        // Clear background
        MinimapConfiguration.defaultBackgroundColor.setFill()
        rect.fill()
        
        // Draw text lines
        drawTextLines(data: data, context: context)
        
        // Draw viewport indicator
        drawViewportIndicator(data: data, context: context)
    }
    
    private func drawTextLines(data: MinimapData, context _: CGContext) {
        let font = UIFont.monospacedSystemFont(ofSize: configuration.fontSize, weight: .regular)
        let textColor = MinimapConfiguration.defaultTextColor
        
        for (index, line) in data.displayLines.enumerated() {
            let lineNumber = data.displayStartLine + index
            let y = CGFloat(lineNumber) * data.lineHeight
            
            // Skip lines outside visible area for performance
            if y + data.lineHeight < 0 || y > bounds.height { continue }
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            
            let attributedString = NSAttributedString(string: line, attributes: attributes)
            let point = CGPoint(x: 2, y: y)
            attributedString.draw(at: point)
        }
    }
    
    private func drawViewportIndicator(data: MinimapData, context: CGContext) {
        let viewportRect = MinimapRenderer.viewportRect(
            for: data.visibleLineRange,
            lineHeight: data.lineHeight,
            minimapWidth: bounds.width,
            totalLines: data.totalLines,
            minimapHeight: bounds.height
        )
        
        // Fill viewport area
        context.setFillColor(MinimapConfiguration.defaultViewportColor.cgColor)
        context.fill(viewportRect)
        
        // Draw viewport border
        context.setStrokeColor(MinimapConfiguration.defaultViewportBorderColor.cgColor)
        context.setLineWidth(1.0)
        context.stroke(viewportRect)
    }
    
    public func updateData(_ data: MinimapData) {
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
    deinit {}
    
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
        
        // Calculate font metrics
        let font = MinimapPlatformFont.monospacedSystemFont(ofSize: configuration.fontSize, weight: .regular)
        let metrics = MinimapRenderer.calculateCharacterMetrics(font: font)
        let lineHeight = metrics.height * configuration.lineHeight
        
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
            characterWidth: metrics.width,
            lineHeight: lineHeight
        )
    }
    
    private func getVisibleLineRange(textView: CodeEditorView, totalLines: Int) -> Range<Int> {
        // This is a simplified implementation
        // In a real implementation, you would calculate based on scroll position and view height
        #if canImport(AppKit)
        if let scrollView = textView.enclosingScrollView {
            let visibleRect = scrollView.documentVisibleRect
            let lineHeight = textView.font?.pointSize ?? 16.0
            
            let startLine = max(0, Int(visibleRect.origin.y / lineHeight))
            let visibleLines = Int(visibleRect.height / lineHeight) + 1
            let endLine = min(totalLines, startLine + visibleLines)
            
            return startLine..<endLine
        }
        #elseif canImport(UIKit)
        let visibleRect = textView.bounds
        let lineHeight = textView.font?.pointSize ?? 16.0
        
        let startLine = max(0, Int(textView.contentOffset.y / lineHeight))
        let visibleLines = Int(visibleRect.height / lineHeight) + 1
        let endLine = min(totalLines, startLine + visibleLines)
        
        return startLine..<endLine
        #endif
        
        // Fallback to first 20 lines
        return 0..<min(20, totalLines)
    }
}
