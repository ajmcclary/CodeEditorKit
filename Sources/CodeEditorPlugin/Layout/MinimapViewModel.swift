import Foundation
import SwiftUI
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Minimap View Model

/// View model responsible for minimap state management and rendering coordination
/// Manages minimap visualization, scrolling, and interaction states
@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Observable
public final class MinimapViewModel {
    // MARK: - Types
    
    public struct MinimapState {
        public var isVisible: Bool
        public var frame: CGRect
        public var contentSize: CGSize
        public var visibleRange: NSRange
        public var scrollPosition: CGFloat
        public var needsRedraw: Bool
        public var scale: CGFloat
        
        public init(
            isVisible: Bool = false,
            frame: CGRect = .zero,
            contentSize: CGSize = .zero,
            visibleRange: NSRange = NSRange(location: 0, length: 0),
            scrollPosition: CGFloat = 0,
            needsRedraw: Bool = true,
            scale: CGFloat = 0.1
        ) {
            self.isVisible = isVisible
            self.frame = frame
            self.contentSize = contentSize
            self.visibleRange = visibleRange
            self.scrollPosition = scrollPosition
            self.needsRedraw = needsRedraw
            self.scale = scale
        }
    }
    
    public struct MinimapRenderInfo {
        public let lineNumber: Int
        public let yPosition: CGFloat
        public let height: CGFloat
        public let content: String
        public let highlightColor: PlatformColor?
        public let isVisible: Bool
        
        public init(
            lineNumber: Int,
            yPosition: CGFloat,
            height: CGFloat,
            content: String,
            highlightColor: PlatformColor? = nil,
            isVisible: Bool = true
        ) {
            self.lineNumber = lineNumber
            self.yPosition = yPosition
            self.height = height
            self.content = content
            self.highlightColor = highlightColor
            self.isVisible = isVisible
        }
    }
    
    public struct MinimapInteraction {
        public var isDragging: Bool
        public var dragStartPosition: CGPoint?
        public var hoveredPosition: CGFloat?
        public var isHovered: Bool
        
        public init(
            isDragging: Bool = false,
            dragStartPosition: CGPoint? = nil,
            hoveredPosition: CGFloat? = nil,
            isHovered: Bool = false
        ) {
            self.isDragging = isDragging
            self.dragStartPosition = dragStartPosition
            self.hoveredPosition = hoveredPosition
            self.isHovered = isHovered
        }
    }
    
    public struct ViewportIndicator {
        public let frame: CGRect
        public let isVisible: Bool
        public let opacity: CGFloat
        
        public init(frame: CGRect, isVisible: Bool = true, opacity: CGFloat = 0.3) {
            self.frame = frame
            self.isVisible = isVisible
            self.opacity = opacity
        }
    }
    
    // MARK: - Published Properties
    
    public var minimapState: MinimapState
    public var interaction: MinimapInteraction
    public var renderInfo: [MinimapRenderInfo] = []
    public var viewportIndicator: ViewportIndicator?
    public var configuration: EditorConfiguration
    
    // Rendering preferences
    public var showSyntaxHighlighting: Bool = true
    public var showViewportIndicator: Bool = true
    public var animateScrolling: Bool = true
    
    // MARK: - Private Properties
    
    private let businessLogicServices: BusinessLogicServiceRegistry
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "MinimapViewModel")
    
    // Services
    private var lineNumberService: LineNumberCalculationService {
        businessLogicServices.lineNumberCalculationService
    }
    
    // Text view reference (weak to avoid retain cycles)
    private weak var textView: CodeEditorView?
    
    // Rendering state
    private var cachedContent: String = ""
    private var cachedLineCount: Int = 0
    private var lastUpdateTime = Date()
    
    // Update throttling
    @available(iOS 17.0, macOS 14.0, *)
    @ObservationIgnored private var renderTask: Task<Void, Never>?
    @available(iOS 17.0, macOS 14.0, *)
    @ObservationIgnored private var scrollTask: Task<Void, Never>?
    private let renderThrottleInterval: TimeInterval = 0.1
    private let scrollThrottleInterval: TimeInterval = 0.05
    
    // Layout constants
    private let minLineHeight: CGFloat = 1.0
    private let maxLineHeight: CGFloat = 3.0
    private let viewportBorderWidth: CGFloat = 1.0
    
    // MARK: - Initialization
    
    public init(
        configuration: EditorConfiguration,
        businessLogicServices: BusinessLogicServiceRegistry = BusinessLogicServiceRegistry.shared
    ) {
        self.configuration = configuration
        self.businessLogicServices = businessLogicServices
        self.minimapState = MinimapState()
        self.interaction = MinimapInteraction()
        
        updateVisibilityState()
        logger.debug("MinimapViewModel initialized")
    }
    
    // MARK: - Public Interface
    
    /// Configures the view model with a text view
    public func configure(with textView: CodeEditorView) {
        self.textView = textView
        updateContentSize()
        scheduleRenderUpdate()
        logger.debug("MinimapViewModel configured with text view")
    }
    
    /// Updates the configuration
    public func updateConfiguration(_ newConfiguration: EditorConfiguration) {
        configuration = newConfiguration
        updateVisibilityState()
        updateScale()
        scheduleRenderUpdate()
    }
    
    /// Updates the minimap frame
    public func updateFrame(_ newFrame: CGRect, animated _: Bool = false) {
        let oldFrame = minimapState.frame
        minimapState.frame = newFrame
        
        if !oldFrame.isCloselyEqualTo(newFrame) {
            updateContentSize()
            updateViewportIndicator()
            scheduleRenderUpdate()
        }
    }
    
    /// Called when text content changes
    public func textDidChange(_ newText: String) {
        if newText != cachedContent {
            cachedContent = newText
            cachedLineCount = newText.components(separatedBy: .newlines).count
            
            updateContentSize()
            scheduleRenderUpdate()
        }
    }
    
    /// Called when scroll position changes
    public func scrollPositionDidChange(_ newPosition: CGPoint) {
        minimapState.scrollPosition = newPosition.y
        updateViewportIndicator()
        
        if animateScrolling {
            scheduleScrollUpdate()
        } else {
            minimapState.needsRedraw = true
        }
    }
    
    // MARK: - Interaction Handling
    
    /// Handles pointer down events in the minimap
    public func handlePointerDown(at location: CGPoint) -> Bool {
        guard minimapState.isVisible else { return false }
        
        interaction.isDragging = true
        interaction.dragStartPosition = location
        
        // Calculate corresponding scroll position
        let relativeY = location.y / minimapState.frame.height
        let targetScrollPosition = relativeY * minimapState.contentSize.height
        
        // Scroll to the clicked position
        scrollToPosition(targetScrollPosition)
        
        return true
    }
    
    /// Handles pointer drag events
    public func handlePointerDrag(to location: CGPoint) {
        guard interaction.isDragging,
              let startPosition = interaction.dragStartPosition else { return }
        
        let deltaY = location.y - startPosition.y
        let scrollDelta = deltaY * (minimapState.contentSize.height / minimapState.frame.height)
        
        let newScrollPosition = minimapState.scrollPosition + scrollDelta
        scrollToPosition(newScrollPosition)
        
        interaction.dragStartPosition = location
    }
    
    /// Handles pointer up events
    public func handlePointerUp() {
        interaction.isDragging = false
        interaction.dragStartPosition = nil
    }
    
    /// Handles hover events
    public func handlePointerHover(at location: CGPoint?) {
        if let location {
            interaction.isHovered = true
            interaction.hoveredPosition = location.y
        } else {
            interaction.isHovered = false
            interaction.hoveredPosition = nil
        }
        
        minimapState.needsRedraw = true
    }
    
    // MARK: - Rendering Control
    
    /// Forces a complete redraw of the minimap
    public func forceRedraw() {
        minimapState.needsRedraw = true
        scheduleRenderUpdate()
    }
    
    /// Updates the scale factor
    public func updateScale(_ newScale: CGFloat? = nil) {
        if let newScale {
            minimapState.scale = max(0.05, min(0.3, newScale))
        } else {
            // Auto-calculate based on content and frame size
            calculateOptimalScale()
        }
        
        updateContentSize()
        scheduleRenderUpdate()
    }
    
    /// Gets the line number at a specific point in the minimap
    public func getLineNumber(at point: CGPoint) -> Int? {
        guard minimapState.isVisible && !minimapState.frame.isEmpty else { return nil }
        
        let relativeY = point.y / minimapState.frame.height
        let totalLines = cachedLineCount
        let lineNumber = Int(relativeY * CGFloat(totalLines)) + 1
        
        return min(max(1, lineNumber), totalLines)
    }
    
    /// Gets the minimap position for a specific line number
    public func getPosition(for lineNumber: Int) -> CGFloat? {
        guard minimapState.isVisible && cachedLineCount > 0 else { return nil }
        
        let relativePosition = CGFloat(lineNumber - 1) / CGFloat(cachedLineCount)
        return relativePosition * minimapState.frame.height
    }
    
    // MARK: - Cache Management
    
    /// Clears all cached rendering data
    public func clearCache() {
        renderInfo.removeAll()
        cachedContent = ""
        cachedLineCount = 0
        minimapState.needsRedraw = true
        logger.debug("Minimap cache cleared")
    }
    
    deinit {
        logger.debug("MinimapViewModel deinitialized")
    }
}

// MARK: - Private Implementation

@available(iOS 17.0, macOS 14.0, *)
extension MinimapViewModel {
    func updateVisibilityState() {
        minimapState.isVisible = configuration.display.showMinimap
        
        if !minimapState.isVisible {
            // Clear state when hidden
            renderInfo.removeAll()
            viewportIndicator = nil
        }
    }
    
    func updateContentSize() {
        guard textView != nil else { return }
        
        let lineHeight = calculateLineHeight()
        let totalHeight = CGFloat(cachedLineCount) * lineHeight
        
        minimapState.contentSize = CGSize(
            width: minimapState.frame.width,
            height: totalHeight
        )
    }
    
    func calculateLineHeight() -> CGFloat {
        let availableHeight = minimapState.frame.height
        let lineCount = max(1, cachedLineCount)
        
        let calculatedHeight = availableHeight / CGFloat(lineCount)
        return max(minLineHeight, min(maxLineHeight, calculatedHeight))
    }
    
    func calculateOptimalScale() {
        guard textView != nil else { return }
        
        let availableWidth = minimapState.frame.width
        let fontSize = configuration.display.fontSize
        
        // Calculate scale based on desired character count per line
        let targetCharsPerLine: CGFloat = 80
        let charWidth = fontSize * 0.6 // Approximate monospace character width
        let desiredTextWidth = targetCharsPerLine * charWidth
        
        minimapState.scale = max(0.05, min(0.3, availableWidth / desiredTextWidth))
    }
    
    func scheduleRenderUpdate() {
        renderTask?.cancel()
        
        renderTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(self?.renderThrottleInterval ?? 0.1))
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self?.updateRenderInfo()
                }
            } catch {
                // Task was cancelled
            }
        }
    }
    
    func scheduleScrollUpdate() {
        scrollTask?.cancel()
        
        scrollTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(self?.scrollThrottleInterval ?? 0.05))
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self?.updateViewportIndicator()
                    self?.minimapState.needsRedraw = true
                }
            } catch {
                // Task was cancelled
            }
        }
    }
    
    func updateRenderInfo() {
        guard minimapState.isVisible,
              textView != nil else {
            renderInfo.removeAll()
            return
        }
        
        let lines = cachedContent.components(separatedBy: .newlines)
        let lineHeight = calculateLineHeight()
        var newRenderInfo: [MinimapRenderInfo] = []
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let yPosition = CGFloat(index) * lineHeight
            
            // Determine if line should be visible (basic culling)
            let isVisible = yPosition >= -lineHeight && yPosition <= minimapState.frame.height + lineHeight
            
            // Determine highlight color based on content
            let highlightColor = getHighlightColor(for: line, lineNumber: lineNumber)
            
            let renderItem = MinimapRenderInfo(
                lineNumber: lineNumber,
                yPosition: yPosition,
                height: lineHeight,
                content: line,
                highlightColor: highlightColor,
                isVisible: isVisible
            )
            
            newRenderInfo.append(renderItem)
        }
        
        renderInfo = newRenderInfo
        updateViewportIndicator()
        minimapState.needsRedraw = true
        
        lastUpdateTime = Date()
    }
    
    func getHighlightColor(for line: String, lineNumber _: Int) -> PlatformColor? {
        guard showSyntaxHighlighting else { return nil }
        
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // Basic syntax highlighting based on line content
        if trimmedLine.hasPrefix("//") || trimmedLine.hasPrefix("#") {
            return PlatformColors.systemGreen.withAlpha(0.6)
        } else if trimmedLine.contains("func ") || trimmedLine.contains("class ") || trimmedLine.contains("struct ") {
            return PlatformColors.systemBlue.withAlpha(0.8)
        } else if trimmedLine.contains("import ") {
            return PlatformColors.systemPurple.withAlpha(0.7)
        } else if !trimmedLine.isEmpty {
            return PlatformColors.label.withAlpha(0.4)
        }
        
        return nil
    }
    
    func updateViewportIndicator() {
        guard showViewportIndicator,
              minimapState.isVisible,
              let textView else {
            viewportIndicator = nil
            return
        }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let visibleRect = textView.visibleRect
        #elseif canImport(UIKit)
        let visibleRect = textView.bounds
        #endif
        let contentHeight = minimapState.contentSize.height
        
        if contentHeight > 0 {
            // Calculate viewport position and size in minimap coordinates
            let topRatio = minimapState.scrollPosition / contentHeight
            let bottomRatio = (minimapState.scrollPosition + visibleRect.height) / contentHeight
            
            let indicatorTop = topRatio * minimapState.frame.height
            let indicatorBottom = bottomRatio * minimapState.frame.height
            let indicatorHeight = max(10, indicatorBottom - indicatorTop)
            
            let indicatorFrame = CGRect(
                x: 0,
                y: indicatorTop,
                width: minimapState.frame.width,
                height: indicatorHeight
            )
            
            viewportIndicator = ViewportIndicator(
                frame: indicatorFrame,
                isVisible: true,
                opacity: interaction.isHovered ? 0.5 : 0.3
            )
        } else {
            viewportIndicator = nil
        }
    }
    
    func scrollToPosition(_ position: CGFloat) {
        guard let textView else { return }
        
        let clampedPosition = max(0, min(position, minimapState.contentSize.height))
        
        // Convert minimap position to text view scroll position
        let scrollRatio = minimapState.contentSize.height > 0 ? clampedPosition / minimapState.contentSize.height : 0
        
        // Calculate target line number based on scroll ratio
        let totalLines = (textView.text ?? "").components(separatedBy: .newlines).count
        let targetLine = max(1, Int(scrollRatio * CGFloat(totalLines)))
        
        // Scroll text view to the calculated line
        textView.scrollToLine(targetLine)
        
        minimapState.scrollPosition = clampedPosition
        updateViewportIndicator()
    }
}

// MARK: - SwiftUI Integration

@available(iOS 17.0, macOS 14.0, *)
extension MinimapViewModel {
    /// Creates a binding for minimap visibility
    public var visibilityBinding: Binding<Bool> {
        Binding(
            get: { self.minimapState.isVisible },
            set: { newValue in
                self.configuration.display.showMinimap = newValue
                self.updateVisibilityState()
            }
        )
    }
    
    /// Creates a binding for syntax highlighting
    public var syntaxHighlightingBinding: Binding<Bool> {
        Binding(
            get: { self.showSyntaxHighlighting },
            set: { newValue in
                self.showSyntaxHighlighting = newValue
                self.scheduleRenderUpdate()
            }
        )
    }
    
    /// Creates a binding for viewport indicator visibility
    public var viewportIndicatorBinding: Binding<Bool> {
        Binding(
            get: { self.showViewportIndicator },
            set: { newValue in
                self.showViewportIndicator = newValue
                self.updateViewportIndicator()
            }
        )
    }
}

// MARK: - Extensions

extension CGRect {
    func isCloselyEqualTo(_ other: CGRect) -> Bool {
        abs(origin.x - other.origin.x) < 1.0 &&
        abs(origin.y - other.origin.y) < 1.0 &&
        abs(size.width - other.size.width) < 1.0 &&
        abs(size.height - other.size.height) < 1.0
    }
}
