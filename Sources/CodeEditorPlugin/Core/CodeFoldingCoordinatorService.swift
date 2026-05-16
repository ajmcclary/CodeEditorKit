import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Code Folding Coordinator Service

/// Gutter-facing facade over `CodeFoldingEngine`. The engine is the single
/// source of truth for fold state and detection; this service only owns
/// fold-control layout/hit-test caching used while rendering the gutter.
@MainActor
public final class CodeFoldingCoordinatorService {
    // MARK: - Types

    /// Layout information for rendering fold controls in the gutter.
    public struct FoldControlLayout {
        /// The rectangle where the fold control should be drawn
        public let controlRect: CGRect
        /// The line number this control is associated with
        public let lineNumber: Int
        /// Whether the control is currently visible in the viewport
        public let isVisible: Bool
        /// The type of control to display
        public let controlType: FoldControlType

        /// Creates a new fold-control layout snapshot.
        public init(controlRect: CGRect, lineNumber: Int, isVisible: Bool, controlType: FoldControlType) {
            self.controlRect = controlRect
            self.lineNumber = lineNumber
            self.isVisible = isVisible
            self.controlType = controlType
        }
    }

    /// The type of fold control to display.
    public enum FoldControlType {
        /// Region can be folded (typically shown as down-pointing triangle)
        case expandable
        /// Region is currently folded (typically shown as right-pointing triangle)
        case collapsed
        /// No folding is available for this line
        case unavailable
    }

    // MARK: - Properties

    private let lineNumberCalculationService: LineNumberCalculationService
    private let codeFoldingEngine: CodeFoldingEngine

    /// Cached layouts produced by `calculateFoldControlPosition`, consulted by
    /// `isFoldControlHit` so click hit-tests don't have to recompute geometry.
    private var controlLayouts: [Int: FoldControlLayout] = [:]

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

    // MARK: - Public Interface (engine-backed state queries)

    /// Checks if a line starts a foldable region.
    public func isFoldable(at lineNumber: Int, in _: CodeEditorView) -> Bool {
        codeFoldingEngine.isStartOfFoldableRegion(lineNumber)
    }

    /// Checks if a line is currently folded.
    public func isFolded(at lineNumber: Int) -> Bool {
        codeFoldingEngine.isLineFolded(lineNumber)
    }

    /// Toggles fold state at a specific line number through the engine.
    public func toggleFold(at lineNumber: Int, in _: CodeEditorView) -> Bool {
        codeFoldingEngine.toggleFold(at: lineNumber)
    }

    /// Clears all folds via the engine and drops cached control layouts.
    public func clearAllFolds() {
        codeFoldingEngine.unfoldAll()
        controlLayouts.removeAll()
    }

    // MARK: - Public Interface (gutter layout)

    /// Calculates and caches the fold-control rect for a gutter line, if any.
    public func calculateFoldControlPosition(
        for lineNumber: Int,
        in gutterFrame: CGRect,
        textView: CodeEditorView,
        configuration: EditorConfiguration
    ) -> FoldControlLayout? {
        guard configuration.display.isCodeFoldingEnabled,
              configuration.display.areFoldingControlsVisible else {
            return nil
        }

        guard let linePosition = lineNumberCalculationService.calculateLinePosition(
            lineNumber: lineNumber,
            in: textView,
            configuration: configuration
        ) else {
            return nil
        }

        let controlType = determineFoldControlType(for: lineNumber)
        guard controlType != .unavailable else { return nil }

        let controlX = gutterFrame.maxX - controlSize - controlPadding
        let controlY = linePosition + (estimateLineHeight(configuration: configuration) - controlSize) / 2

        let controlRect = CGRect(x: controlX, y: controlY, width: controlSize, height: controlSize)

        let layout = FoldControlLayout(
            controlRect: controlRect,
            lineNumber: lineNumber,
            isVisible: gutterFrame.intersects(controlRect),
            controlType: controlType
        )

        controlLayouts[lineNumber] = layout
        return layout
    }

    /// Checks if a point hits a fold control previously laid out via
    /// `calculateFoldControlPosition`.
    public func isFoldControlHit(at point: CGPoint, for lineNumber: Int) -> Bool {
        guard let layout = controlLayouts[lineNumber] else { return false }
        return layout.controlRect.contains(point) && layout.isVisible
    }

    // MARK: - Private

    private func determineFoldControlType(for lineNumber: Int) -> FoldControlType {
        if codeFoldingEngine.isLineFolded(lineNumber) {
            return .collapsed
        } else if codeFoldingEngine.isStartOfFoldableRegion(lineNumber) {
            return .expandable
        } else {
            return .unavailable
        }
    }

    private func estimateLineHeight(configuration: EditorConfiguration) -> CGFloat {
        configuration.display.fontSize * 1.2
    }
}
