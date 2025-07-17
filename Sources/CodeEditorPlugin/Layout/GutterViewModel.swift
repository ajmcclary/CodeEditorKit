import Foundation
import SwiftUI
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Gutter View Model

/// View model responsible for gutter-specific state management and rendering logic
/// Separates gutter UI concerns from business logic services
@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Observable
public final class GutterViewModel {
    // MARK: - Types
    
    public struct GutterDisplayState {
        public var currentWidth: CGFloat
        public var recommendedWidth: CGFloat
        public var shouldAnimate: Bool
        public var isVisible: Bool
        public var needsRedraw: Bool
        
        public init(
            currentWidth: CGFloat = 0,
            recommendedWidth: CGFloat = 0,
            shouldAnimate: Bool = false,
            isVisible: Bool = true,
            needsRedraw: Bool = true
        ) {
            self.currentWidth = currentWidth
            self.recommendedWidth = recommendedWidth
            self.shouldAnimate = shouldAnimate
            self.isVisible = isVisible
            self.needsRedraw = needsRedraw
        }
    }
    
    public struct LineNumberDisplayInfo {
        public let lineNumber: Int
        public let yPosition: CGFloat
        public let isVisible: Bool
        public let isSelected: Bool
        public let hasBreakpoint: Bool
        public let hasError: Bool
        public let foldControlLayout: CodeFoldingCoordinatorService.FoldControlLayout?
        
        public init(
            lineNumber: Int,
            yPosition: CGFloat,
            isVisible: Bool,
            isSelected: Bool = false,
            hasBreakpoint: Bool = false,
            hasError: Bool = false,
            foldControlLayout: CodeFoldingCoordinatorService.FoldControlLayout? = nil
        ) {
            self.lineNumber = lineNumber
            self.yPosition = yPosition
            self.isVisible = isVisible
            self.isSelected = isSelected
            self.hasBreakpoint = hasBreakpoint
            self.hasError = hasError
            self.foldControlLayout = foldControlLayout
        }
    }
    
    public struct GutterInteractionState {
        public var hoveredLineNumber: Int?
        public var selectedLineNumbers: Set<Int>
        public var isDragging: Bool
        public var lastClickLocation: CGPoint?
        
        public init(
            hoveredLineNumber: Int? = nil,
            selectedLineNumbers: Set<Int> = [],
            isDragging: Bool = false,
            lastClickLocation: CGPoint? = nil
        ) {
            self.hoveredLineNumber = hoveredLineNumber
            self.selectedLineNumbers = selectedLineNumbers
            self.isDragging = isDragging
            self.lastClickLocation = lastClickLocation
        }
    }
    
    // MARK: - Published Properties
    
    public var displayState: GutterDisplayState
    public var interactionState: GutterInteractionState
    public var visibleLineNumbers: [LineNumberDisplayInfo] = []
    public var configuration: EditorConfiguration
    public var frame: CGRect = .zero
    
    // MARK: - Private Properties
    
    private let businessLogicServices: BusinessLogicServiceRegistry
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "GutterViewModel")
    
    // Debugging and diagnostic support
    private var breakpoints: Set<Int> = []
    private var diagnosticLines: Set<Int> = []
    
    // Services
    private var lineNumberService: LineNumberCalculationService {
        businessLogicServices.lineNumberCalculationService
    }
    
    private var gutterSizingService: GutterSizingService {
        businessLogicServices.gutterSizingService
    }
    
    private var codeFoldingService: CodeFoldingCoordinatorService {
        businessLogicServices.codeFoldingCoordinatorService
    }
    
    // Text view reference (weak to avoid retain cycles)
    private weak var textView: CodeEditorView?
    
    // Cached state
    private var cachedLineCount: Int = 0
    private var cachedFont: PlatformFont?
    
    // Update throttling
    @available(iOS 17.0, macOS 14.0, *)
    @ObservationIgnored private var updateTask: Task<Void, Never>?
    private let updateThrottleInterval: TimeInterval = 0.05
    
    deinit {
        logger.debug("GutterViewModel deinitialized")
    }
    
    // MARK: - Initialization
    
    public init(
        configuration: EditorConfiguration,
        businessLogicServices: BusinessLogicServiceRegistry
    ) {
        self.configuration = configuration
        self.businessLogicServices = businessLogicServices
        self.displayState = GutterDisplayState()
        self.interactionState = GutterInteractionState()
        
        updateDisplayState()
        logger.debug("GutterViewModel initialized")
    }
    
    // MARK: - Public Interface
    
    /// Configures the view model with a text view
    public func configure(with textView: CodeEditorView) {
        self.textView = textView
        
        updateDisplayState()
        updateVisibleLineNumbers()
        
        logger.debug("GutterViewModel configured with text view")
    }
    
    /// Updates the configuration and refreshes display state
    public func updateConfiguration(_ newConfiguration: EditorConfiguration) {
        configuration = newConfiguration
        updateDisplayState()
        scheduleVisibleLineNumbersUpdate()
    }
    
    /// Updates the gutter frame and triggers layout recalculation
    public func updateFrame(_ newFrame: CGRect, animated: Bool) {
        let oldFrame = frame
        frame = newFrame
        
        displayState.currentWidth = newFrame.width
        displayState.shouldAnimate = animated && !oldFrame.isApproximatelyEqualTo(newFrame)
        
        if !oldFrame.isApproximatelyEqualTo(newFrame) {
            scheduleVisibleLineNumbersUpdate()
        }
    }
    
    /// Called when text content changes
    public func textDidChange(_ newText: String) {
        let newLineCount = newText.components(separatedBy: .newlines).count
        
        if newLineCount != cachedLineCount {
            cachedLineCount = newLineCount
            updateDisplayState()
        }
        
        scheduleVisibleLineNumbersUpdate()
    }
    
    /// Called when selection changes
    public func selectionDidChange(_ newRange: NSRange) {
        guard let textView else { return }
        
        let lineNumber = lineNumberService.lineNumber(for: newRange.location, in: textView)
        interactionState.selectedLineNumbers = [lineNumber]
        
        updateVisibleLineNumbers()
    }
    
    /// Called when scroll position changes
    public func scrollPositionDidChange(_: CGPoint) {
        scheduleVisibleLineNumbersUpdate()
    }
    
    // MARK: - Interaction Handling
    
    /// Handles mouse/touch down events in the gutter
    public func handlePointerDown(at location: CGPoint) -> Bool {
        guard displayState.isVisible else { return false }
        
        interactionState.lastClickLocation = location
        
        // Check if clicking on a fold control
        if let lineNumber = findLineNumber(at: location),
           codeFoldingService.isFoldControlHit(at: location, for: lineNumber) {
            if let textView {
                _ = codeFoldingService.toggleFold(at: lineNumber, in: textView)
                updateVisibleLineNumbers()
            }
            return true
        }
        
        // Handle line number selection
        if let lineNumber = findLineNumber(at: location) {
            selectLineNumber(lineNumber)
            return true
        }
        
        return false
    }
    
    /// Handles mouse/touch hover events
    public func handlePointerHover(at location: CGPoint) {
        guard displayState.isVisible else { return }
        
        let hoveredLine = findLineNumber(at: location)
        if hoveredLine != interactionState.hoveredLineNumber {
            interactionState.hoveredLineNumber = hoveredLine
            displayState.needsRedraw = true
        }
    }
    
    /// Handles context menu requests
    public func handleContextMenu(at location: CGPoint) -> [String] {
        guard let lineNumber = findLineNumber(at: location) else { return [] }
        
        var menuItems: [String] = []
        
        // Add folding options if available
        if let textView {
            if codeFoldingService.isFoldable(at: lineNumber, in: textView) {
                if codeFoldingService.isFolded(at: lineNumber) {
                    menuItems.append("Unfold")
                } else {
                    menuItems.append("Fold")
                }
            }
        }
        
        menuItems.append("Add Breakpoint")
        menuItems.append("Copy Line Number")
        
        return menuItems
    }
    
    /// Handles context menu item selection
    public func handleContextMenuAction(_ action: String, at location: CGPoint) {
        guard let lineNumber = findLineNumber(at: location),
              let textView else { return }
        
        switch action {
        case "Fold":
            _ = codeFoldingService.toggleFold(at: lineNumber, in: textView)
            updateVisibleLineNumbers()
            
        case "Unfold":
            _ = codeFoldingService.toggleFold(at: lineNumber, in: textView)
            updateVisibleLineNumbers()
            
        case "Add Breakpoint":
            // This would integrate with debugging services
            logger.debug("Breakpoint toggle requested for line \(lineNumber)")
            
        case "Copy Line Number":
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(String(lineNumber), forType: .string)
            #elseif canImport(UIKit)
            UIPasteboard.general.string = String(lineNumber)
            #endif
            
        default:
            break
        }
    }
    
    // MARK: - Display Information
    
    /// Gets styling information for a specific line number
    public func getLineNumberStyle(for lineNumber: Int) -> LineNumberStyle {
        let isSelected = interactionState.selectedLineNumbers.contains(lineNumber)
        let isHovered = interactionState.hoveredLineNumber == lineNumber
        
        return LineNumberStyle(
            font: PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize),
            textColor: getLineNumberTextColor(isSelected: isSelected, isHovered: isHovered),
            backgroundColor: getLineNumberBackgroundColor(isSelected: isSelected, isHovered: isHovered),
            alignment: .right
        )
    }
    
    /// Gets the recommended gutter width for current content
    public func getRecommendedWidth() -> CGFloat {
        displayState.recommendedWidth
    }
    
    /// Checks if the gutter needs to resize
    public func needsWidthUpdate() -> Bool {
        guard let textView else { return false }
        
        return gutterSizingService.needsWidthAdjustment(
            currentWidth: displayState.currentWidth,
            for: textView,
            configuration: configuration
        )
    }
    
    // MARK: - Cache Management
    
    /// Clears all cached data
    public func clearCache() {
        visibleLineNumbers.removeAll()
        cachedLineCount = 0
        cachedFont = nil
        displayState.needsRedraw = true
        logger.debug("Gutter cache cleared")
    }
}

// MARK: - Supporting Types

public struct LineNumberStyle {
    public let font: PlatformFont
    public let textColor: PlatformColor
    public let backgroundColor: PlatformColor
    public let alignment: NSTextAlignment
    
    public init(
        font: PlatformFont,
        textColor: PlatformColor,
        backgroundColor: PlatformColor,
        alignment: NSTextAlignment
    ) {
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.alignment = alignment
    }
}

// MARK: - Private Implementation

@available(iOS 17.0, macOS 14.0, *)
extension GutterViewModel {
    func updateDisplayState() {
        displayState.isVisible = configuration.display.isLineNumbersEnabled
        
        guard displayState.isVisible else {
            displayState.currentWidth = 0
            displayState.recommendedWidth = 0
            return
        }
        
        // Update recommended width
        let font = PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize)
        if textView != nil {
            let sizingResult = gutterSizingService.calculateOptimalWidth(
                lineCount: cachedLineCount > 0 ? cachedLineCount : 1_000,
                font: font,
                configuration: configuration
            )
            displayState.recommendedWidth = sizingResult.recommendedWidth
            
            // Update current width if this is the first calculation
            if displayState.currentWidth == 0 {
                displayState.currentWidth = displayState.recommendedWidth
            }
        }
        
        cachedFont = font
    }
    
    func updateVisibleLineNumbers() {
        guard let textView,
              displayState.isVisible,
              !frame.isEmpty else {
            visibleLineNumbers.removeAll()
            return
        }
        
        let visibleRange = lineNumberService.calculateVisibleLineRanges(
            for: textView,
            configuration: configuration
        )
        
        var newVisibleNumbers: [LineNumberDisplayInfo] = []
        
        for position in visibleRange.positions {
            let lineNumber = position.lineNumber
            let isSelected = interactionState.selectedLineNumbers.contains(lineNumber)
            
            // Calculate fold control layout if folding is enabled
            var foldControlLayout: CodeFoldingCoordinatorService.FoldControlLayout?
            if configuration.display.enableCodeFolding {
                foldControlLayout = codeFoldingService.calculateFoldControlPosition(
                    for: lineNumber,
                    in: frame,
                    textView: textView,
                    configuration: configuration
                )
            }
            
            let displayInfo = LineNumberDisplayInfo(
                lineNumber: lineNumber,
                yPosition: position.yPosition,
                isVisible: true,
                isSelected: isSelected,
                hasBreakpoint: breakpoints.contains(lineNumber),
                hasError: diagnosticLines.contains(lineNumber),
                foldControlLayout: foldControlLayout
            )
            
            newVisibleNumbers.append(displayInfo)
        }
        
        visibleLineNumbers = newVisibleNumbers
        displayState.needsRedraw = true
    }
    
    func scheduleVisibleLineNumbersUpdate() {
        updateTask?.cancel()
        
        updateTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(self?.updateThrottleInterval ?? 0.05))
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self?.updateVisibleLineNumbers()
                }
            } catch {
                // Task was cancelled
            }
        }
    }
    
    func findLineNumber(at location: CGPoint) -> Int? {
        guard let textView else { return nil }
        return lineNumberService.lineNumber(at: location, in: textView)
    }
    
    func selectLineNumber(_ lineNumber: Int) {
        interactionState.selectedLineNumbers = [lineNumber]
        
        // Integrate with text view selection - select the entire line
        if let textView,
           let lineRange = textView.lineRange(for: lineNumber) {
            // Convert Range<String.Index> to NSRange
            let nsRange = NSRange(lineRange, in: textView.text ?? "")
            textView.selectedRange = nsRange
        }
        
        updateVisibleLineNumbers()
    }
    
    // MARK: - Debugging Support
    
    /// Sets breakpoints for debugging integration
    public func setBreakpoints(_ lines: Set<Int>) {
        breakpoints = lines
        updateVisibleLineNumbers()
    }
    
    /// Adds a breakpoint at the specified line
    public func addBreakpoint(at line: Int) {
        breakpoints.insert(line)
        updateVisibleLineNumbers()
    }
    
    /// Removes a breakpoint from the specified line
    public func removeBreakpoint(at line: Int) {
        breakpoints.remove(line)
        updateVisibleLineNumbers()
    }
    
    /// Checks if a line has a breakpoint
    public func hasBreakpoint(at line: Int) -> Bool {
        breakpoints.contains(line)
    }
    
    // MARK: - Diagnostics Support
    
    /// Sets diagnostic lines for error/warning integration
    public func setDiagnosticLines(_ lines: Set<Int>) {
        diagnosticLines = lines
        updateVisibleLineNumbers()
    }
    
    /// Adds a diagnostic at the specified line
    public func addDiagnostic(at line: Int) {
        diagnosticLines.insert(line)
        updateVisibleLineNumbers()
    }
    
    /// Removes a diagnostic from the specified line
    public func removeDiagnostic(at line: Int) {
        diagnosticLines.remove(line)
        updateVisibleLineNumbers()
    }
    
    /// Checks if a line has a diagnostic
    public func hasDiagnostic(at line: Int) -> Bool {
        diagnosticLines.contains(line)
    }
    
    func getLineNumberTextColor(isSelected: Bool, isHovered: Bool) -> PlatformColor {
        if isSelected {
            return PlatformColors.selectedTextColor
        } else if isHovered {
            return PlatformColors.controlAccentColor
        } else {
            return PlatformColors.secondaryLabel
        }
    }
    
    func getLineNumberBackgroundColor(isSelected: Bool, isHovered: Bool) -> PlatformColor {
        if isSelected {
            return PlatformColors.selectedTextBackgroundColor
        } else if isHovered {
            return PlatformColors.systemGray
        } else {
            return PlatformColors.clear
        }
    }
}

// MARK: - SwiftUI Integration

@available(iOS 17.0, macOS 14.0, *)
extension GutterViewModel {
    /// Creates a binding for the gutter visibility
    public var visibilityBinding: Binding<Bool> {
        Binding(
            get: { self.displayState.isVisible },
            set: { newValue in
                self.configuration.display.isLineNumbersEnabled = newValue
                self.updateDisplayState()
            }
        )
    }
    
    /// Creates a binding for the gutter width
    public var widthBinding: Binding<CGFloat> {
        Binding(
            get: { self.displayState.currentWidth },
            set: { newValue in
                self.displayState.currentWidth = newValue
            }
        )
    }
}

// MARK: - Platform Extensions

extension CGRect {
    func isApproximatelyEqualTo(_ other: CGRect) -> Bool {
        abs(origin.x - other.origin.x) < 1.0 &&
        abs(origin.y - other.origin.y) < 1.0 &&
        abs(size.width - other.size.width) < 1.0 &&
        abs(size.height - other.size.height) < 1.0
    }
}
