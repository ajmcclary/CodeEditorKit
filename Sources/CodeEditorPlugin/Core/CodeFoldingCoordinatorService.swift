import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Code Folding Coordinator Service

/// Service responsible for code folding state management and UI coordination
/// Extracts business logic from CodeFoldingEngine and UI interaction handlers
@MainActor
public final class CodeFoldingCoordinatorService {
    // MARK: - Types
    
    public struct FoldingRegion {
        public let startLine: Int
        public let endLine: Int
        public let level: Int
        public let isFolded: Bool
        public let canBeFolded: Bool
        public let foldingRange: NSRange
        
        public init(
            startLine: Int,
            endLine: Int,
            level: Int,
            isFolded: Bool,
            canBeFolded: Bool,
            foldingRange: NSRange
        ) {
            self.startLine = startLine
            self.endLine = endLine
            self.level = level
            self.isFolded = isFolded
            self.canBeFolded = canBeFolded
            self.foldingRange = foldingRange
        }
    }
    
    public struct FoldControlLayout {
        public let controlRect: CGRect
        public let lineNumber: Int
        public let isVisible: Bool
        public let controlType: FoldControlType
        
        public init(controlRect: CGRect, lineNumber: Int, isVisible: Bool, controlType: FoldControlType) {
            self.controlRect = controlRect
            self.lineNumber = lineNumber
            self.isVisible = isVisible
            self.controlType = controlType
        }
    }
    
    public enum FoldControlType {
        case expandable    // Can be folded (triangle pointing down)
        case collapsed     // Is folded (triangle pointing right)
        case unavailable   // No folding available
    }
    
    public struct FoldingState {
        public let regions: [FoldingRegion]
        public let controlLayouts: [FoldControlLayout]
        public let totalFoldedLines: Int
        
        public init(regions: [FoldingRegion], controlLayouts: [FoldControlLayout], totalFoldedLines: Int) {
            self.regions = regions
            self.controlLayouts = controlLayouts
            self.totalFoldedLines = totalFoldedLines
        }
    }
    
    // MARK: - Properties
    
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "CodeFoldingCoordinatorService")
    private let lineNumberCalculationService: LineNumberCalculationService
    private let codeFoldingEngine: CodeFoldingEngine
    
    // Folding state management
    private var foldedRegions: [Int: FoldingRegion] = [:] // lineNumber: region
    private var foldableRegions: [Int: FoldingRegion] = [:] // lineNumber: region
    private var controlLayouts: [Int: FoldControlLayout] = [:] // lineNumber: layout
    
    // Configuration
    private let controlSize: CGFloat = 12.0
    private let controlPadding: CGFloat = 4.0
    
    // MARK: - Initialization
    
    internal init(
        lineNumberCalculationService: LineNumberCalculationService,
        codeFoldingEngine: CodeFoldingEngine
    ) {
        self.lineNumberCalculationService = lineNumberCalculationService
        self.codeFoldingEngine = codeFoldingEngine
    }
    
    // MARK: - Public Interface
    
    /// Checks if a line can be folded
    public func isFoldable(at lineNumber: Int, in textView: CodeEditorView) -> Bool {
        if let region = foldableRegions[lineNumber] {
            return region.canBeFolded
        }
        
        // Check if this line starts a foldable region
        return detectFoldableRegion(at: lineNumber, in: textView) != nil
    }
    
    /// Checks if a line is currently folded
    public func isFolded(at lineNumber: Int) -> Bool {
        foldedRegions[lineNumber]?.isFolded ?? false
    }
    
    /// Toggles fold state at a specific line number
    public func toggleFold(at lineNumber: Int, in textView: CodeEditorView) -> Bool {
        guard isFoldable(at: lineNumber, in: textView) else { return false }
        
        if isFolded(at: lineNumber) {
            return unfoldRegion(at: lineNumber, in: textView)
        } else {
            return foldRegion(at: lineNumber, in: textView)
        }
    }
    
    /// Calculates the position of fold control for a given line
    public func calculateFoldControlPosition(
        for lineNumber: Int,
        in gutterFrame: CGRect,
        textView: CodeEditorView,
        configuration: EditorConfiguration
    ) -> FoldControlLayout? {
        guard configuration.display.enableCodeFolding && configuration.display.showFoldingControls else {
            return nil
        }
        
        guard let linePosition = lineNumberCalculationService.calculateLinePosition(
            lineNumber: lineNumber,
            in: textView,
            configuration: configuration
        ) else {
            return nil
        }
        
        let controlType = determineFoldControlType(for: lineNumber, in: textView)
        guard controlType != .unavailable else { return nil }
        
        let controlX = gutterFrame.maxX - controlSize - controlPadding
        let controlY = linePosition + (estimateLineHeight(configuration: configuration) - controlSize) / 2
        
        let controlRect = CGRect(
            x: controlX,
            y: controlY,
            width: controlSize,
            height: controlSize
        )
        
        let layout = FoldControlLayout(
            controlRect: controlRect,
            lineNumber: lineNumber,
            isVisible: isControlVisible(for: lineNumber, in: gutterFrame),
            controlType: controlType
        )
        
        // Cache the layout
        controlLayouts[lineNumber] = layout
        
        return layout
    }
    
    /// Checks if a point hits a fold control
    public func isFoldControlHit(at point: CGPoint, for lineNumber: Int) -> Bool {
        guard let layout = controlLayouts[lineNumber] else { return false }
        return layout.controlRect.contains(point) && layout.isVisible
    }
    
    /// Gets current fold state for all regions
    public func getCurrentFoldState() -> FoldingState {
        let allRegions = Array(foldableRegions.values) + Array(foldedRegions.values)
        let allLayouts = Array(controlLayouts.values)
        let totalFoldedLines = foldedRegions.values.reduce(0) { total, region in
            total + (region.endLine - region.startLine)
        }
        
        return FoldingState(
            regions: allRegions,
            controlLayouts: allLayouts,
            totalFoldedLines: totalFoldedLines
        )
    }
    
    /// Updates folding state based on text changes
    public func updateFoldingState(for textView: CodeEditorView, configuration: EditorConfiguration) {
        guard configuration.display.enableCodeFolding else {
            clearAllFolds()
            return
        }
        
        // Recalculate foldable regions
        recalculateFoldableRegions(in: textView, configuration: configuration)
        
        // Validate existing folds
        validateExistingFolds(in: textView)
        
        // Update control layouts
        updateControlLayouts(in: textView, configuration: configuration)
    }
    
    /// Expands all folded regions
    public func expandAll(in textView: CodeEditorView) {
        for lineNumber in foldedRegions.keys {
            _ = unfoldRegion(at: lineNumber, in: textView)
        }
    }
    
    /// Folds all foldable regions
    public func foldAll(in textView: CodeEditorView) {
        for lineNumber in foldableRegions.keys where !isFolded(at: lineNumber) {
            _ = foldRegion(at: lineNumber, in: textView)
        }
    }
    
    /// Gets visible line numbers accounting for folded regions
    public func getVisibleLineNumbers(for textView: CodeEditorView) -> [Int] {
        let totalLines = (textView.text ?? "").components(separatedBy: .newlines).count
        var visibleLines: [Int] = []
        
        for lineNumber in 1...totalLines where !isLineHiddenByFolding(lineNumber) {
            visibleLines.append(lineNumber)
        }
        
        return visibleLines
    }
    
    // MARK: - Cache and State Management
    
    /// Clears all folding state
    public func clearAllFolds() {
        foldedRegions.removeAll()
        foldableRegions.removeAll()
        controlLayouts.removeAll()
        logger.debug("All folding state cleared")
    }
    
    /// Saves folding state for persistence
    public func saveFoldingState() -> [String: Any] {
        let foldedLines = Array(foldedRegions.keys)
        return ["foldedLines": foldedLines]
    }
    
    /// Restores folding state from saved data
    public func restoreFoldingState(from data: [String: Any], in textView: CodeEditorView) {
        guard let foldedLines = data["foldedLines"] as? [Int] else { return }
        
        for lineNumber in foldedLines where isFoldable(at: lineNumber, in: textView) {
            _ = foldRegion(at: lineNumber, in: textView)
        }
        
        logger.debug("Folding state restored for \(foldedLines.count) lines")
    }
}

// MARK: - Private Implementation

extension CodeFoldingCoordinatorService {
    func detectFoldableRegion(at lineNumber: Int, in textView: CodeEditorView) -> FoldingRegion? {
        let text = textView.text ?? ""
        let lines = text.components(separatedBy: .newlines)
        
        guard lineNumber > 0 && lineNumber <= lines.count else { return nil }
        
        _ = lines[lineNumber - 1]
        
        // Detect common folding patterns
        if let region = detectBraceFoldingRegion(startingAt: lineNumber, lines: lines) {
            return region
        }
        
        if let region = detectIndentationFoldingRegion(startingAt: lineNumber, lines: lines) {
            return region
        }
        
        return nil
    }
    
    func detectBraceFoldingRegion(startingAt lineNumber: Int, lines: [String]) -> FoldingRegion? {
        guard lineNumber > 0 && lineNumber <= lines.count else { return nil }
        
        let startLine = lines[lineNumber - 1]
        guard startLine.contains("{") else { return nil }
        
        // Find matching closing brace
        var braceCount = 0
        var endLineNumber = lineNumber
        
        for (index, line) in lines.enumerated() {
            guard index >= lineNumber - 1 else { continue }
            
            for char in line {
                if char == "{" {
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                    if braceCount == 0 {
                        endLineNumber = index + 1
                        break
                    }
                }
            }
            
            if braceCount == 0 {
                break
            }
        }
        
        // Must have at least minimum foldable lines
        guard endLineNumber - lineNumber >= 2 else { return nil }
        
        let characterRange = calculateCharacterRange(
            startLine: lineNumber,
            endLine: endLineNumber,
            lines: lines
        )
        
        return FoldingRegion(
            startLine: lineNumber,
            endLine: endLineNumber,
            level: 0,
            isFolded: false,
            canBeFolded: true,
            foldingRange: characterRange
        )
    }
    
    func detectIndentationFoldingRegion(startingAt lineNumber: Int, lines: [String]) -> FoldingRegion? {
        guard lineNumber > 0 && lineNumber <= lines.count else { return nil }
        
        let startLine = lines[lineNumber - 1]
        let startIndentation = getIndentationLevel(startLine)
        
        // Find end of indented block
        var endLineNumber = lineNumber
        
        for index in lineNumber..<lines.count {
            let line = lines[index]
            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                let indentation = getIndentationLevel(line)
                if indentation <= startIndentation {
                    break
                }
            }
            endLineNumber = index + 1
        }
        
        // Must have at least minimum foldable lines
        guard endLineNumber - lineNumber >= 2 else { return nil }
        
        let characterRange = calculateCharacterRange(
            startLine: lineNumber,
            endLine: endLineNumber,
            lines: lines
        )
        
        return FoldingRegion(
            startLine: lineNumber,
            endLine: endLineNumber,
            level: startIndentation,
            isFolded: false,
            canBeFolded: true,
            foldingRange: characterRange
        )
    }
    
    func getIndentationLevel(_ line: String) -> Int {
        var level = 0
        for char in line {
            if char == " " {
                level += 1
            } else if char == "\t" {
                level += 4 // Tab = 4 spaces
            } else {
                break
            }
        }
        return level
    }
    
    func calculateCharacterRange(startLine: Int, endLine: Int, lines: [String]) -> NSRange {
        var startIndex = 0
        var endIndex = 0
        
        // Calculate start index
        for lineIndex in 0..<(startLine - 1) {
            startIndex += lines[lineIndex].count + 1 // +1 for newline
        }
        
        // Calculate end index
        endIndex = startIndex
        for lineIndex in (startLine - 1)..<min(endLine, lines.count) {
            endIndex += lines[lineIndex].count + 1 // +1 for newline
        }
        
        return NSRange(location: startIndex, length: endIndex - startIndex)
    }
    
    func determineFoldControlType(for lineNumber: Int, in textView: CodeEditorView) -> FoldControlType {
        if isFolded(at: lineNumber) {
            return .collapsed
        } else if isFoldable(at: lineNumber, in: textView) {
            return .expandable
        } else {
            return .unavailable
        }
    }
    
    func isControlVisible(for lineNumber: Int, in gutterFrame: CGRect) -> Bool {
        // Check if control would be visible within gutter bounds
        guard let layout = controlLayouts[lineNumber] else { return false }
        return gutterFrame.intersects(layout.controlRect)
    }
    
    func foldRegion(at lineNumber: Int, in textView: CodeEditorView) -> Bool {
        guard let region = detectFoldableRegion(at: lineNumber, in: textView) else { return false }
        
        // Create folded version of the region
        let foldedRegion = FoldingRegion(
            startLine: region.startLine,
            endLine: region.endLine,
            level: region.level,
            isFolded: true,
            canBeFolded: true,
            foldingRange: region.foldingRange
        )
        
        foldedRegions[lineNumber] = foldedRegion
        
        // Apply folding to the text view via CodeFoldingEngine
        // Note: CodeFoldingEngine integration to be implemented
        
        logger.debug("Folded region at line \(lineNumber) (lines \(region.startLine)-\(region.endLine))")
        return true
    }
    
    func unfoldRegion(at lineNumber: Int, in _: CodeEditorView) -> Bool {
        guard let region = foldedRegions[lineNumber] else { return false }
        
        // Remove from folded regions
        foldedRegions.removeValue(forKey: lineNumber)
        
        // Apply unfolding to the text view via CodeFoldingEngine
        // Note: CodeFoldingEngine integration to be implemented
        
        logger.debug("Unfolded region at line \(lineNumber) (lines \(region.startLine)-\(region.endLine))")
        return true
    }
    
    func isLineHiddenByFolding(_ lineNumber: Int) -> Bool {
        for region in foldedRegions.values {
            if region.isFolded && lineNumber > region.startLine && lineNumber <= region.endLine {
                return true
            }
        }
        return false
    }
    
    func recalculateFoldableRegions(in textView: CodeEditorView, configuration _: EditorConfiguration) {
        foldableRegions.removeAll()
        
        let lines = (textView.text ?? "").components(separatedBy: .newlines)
        
        for index in lines.indices {
            let lineNumber = index + 1
            
            if let region = detectFoldableRegion(at: lineNumber, in: textView) {
                foldableRegions[lineNumber] = region
            }
        }
    }
    
    func validateExistingFolds(in textView: CodeEditorView) {
        var invalidFolds: [Int] = []
        
        for (lineNumber, region) in foldedRegions {
            // Check if the folded region is still valid
            if let currentRegion = detectFoldableRegion(at: lineNumber, in: textView) {
                // Update the region if it changed
                if currentRegion.endLine != region.endLine {
                    let updatedRegion = FoldingRegion(
                        startLine: currentRegion.startLine,
                        endLine: currentRegion.endLine,
                        level: currentRegion.level,
                        isFolded: true,
                        canBeFolded: true,
                        foldingRange: currentRegion.foldingRange
                    )
                    foldedRegions[lineNumber] = updatedRegion
                }
            } else {
                invalidFolds.append(lineNumber)
            }
        }
        
        // Remove invalid folds
        for lineNumber in invalidFolds {
            _ = unfoldRegion(at: lineNumber, in: textView)
        }
    }
    
    func updateControlLayouts(in _: CodeEditorView, configuration _: EditorConfiguration) {
        controlLayouts.removeAll()
        
        // This would be called by the UI layer to get updated layouts
        // The actual layout calculation is done in calculateFoldControlPosition
    }
    
    func estimateLineHeight(configuration: EditorConfiguration) -> CGFloat {
        configuration.display.fontSize * 1.2
    }
}
