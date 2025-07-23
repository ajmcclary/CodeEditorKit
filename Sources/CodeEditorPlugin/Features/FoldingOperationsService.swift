import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Folding Operations Service

/// Service for managing fold/unfold operations
@MainActor
internal final class FoldingOperationsService {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "FoldingOperationsService")

    // MARK: - Properties

    private weak var textView: CodeEditorView?
    private var textStorage: NSTextStorage? { textView?.textStorage }

    // MARK: - Public Methods

    /// Attach to a text view
    internal func attach(to textView: CodeEditorView) {
        self.textView = textView
    }

    /// Toggle fold at line
    /// - Returns: `true` if fold state was changed, `false` if no foldable region exists
    internal func toggleFold(at line: Int, regions: [FoldableRegion], foldedRegions: inout Set<UUID>) -> Bool {
        guard let region = foldableRegion(at: line, from: regions) else { return false }

        if foldedRegions.contains(region.id) {
            unfold(region, foldedRegions: &foldedRegions)
        } else {
            fold(region, foldedRegions: &foldedRegions)
        }
        return true
    }

    /// Fold a specific region
    /// - Returns: `true` if the region was folded, `false` if it was already folded or textView is nil
    @discardableResult
    internal func fold(_ region: FoldableRegion, foldedRegions: inout Set<UUID>, configuration: CodeFoldingConfiguration = CodeFoldingConfiguration()) -> Bool {
        guard !foldedRegions.contains(region.id),
              let textView else { return false }

        foldedRegions.insert(region.id)

        // Apply folding visual changes
        applyFoldingVisuals(for: region, isFolded: true, configuration: configuration)

        // Hide the folded content
        if configuration.hidesFoldedContent {
            hideFoldedContent(region)
        }

        // Update gutter
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.setNeedsDisplay(textView.bounds)
        #else
        textView.setNeedsDisplay()
        #endif

        logger.debug("Folded region: \(region.title)")
        return true
    }

    /// Unfold a specific region
    /// - Returns: `true` if the region was unfolded, `false` if it wasn't folded or textView is nil
    @discardableResult
    internal func unfold(_ region: FoldableRegion, foldedRegions: inout Set<UUID>, configuration: CodeFoldingConfiguration = CodeFoldingConfiguration()) -> Bool {
        guard foldedRegions.contains(region.id),
              let textView else { return false }

        foldedRegions.remove(region.id)

        // Remove folding visual changes
        applyFoldingVisuals(for: region, isFolded: false, configuration: configuration)

        // Show the unfolded content
        if configuration.hidesFoldedContent {
            showUnfoldedContent(region)
        }

        // Update gutter
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.setNeedsDisplay(textView.bounds)
        #else
        textView.setNeedsDisplay()
        #endif

        logger.debug("Unfolded region: \(region.title)")
        return true
    }

    /// Fold all regions
    internal func foldAll(regions: [FoldableRegion], foldedRegions: inout Set<UUID>, configuration: CodeFoldingConfiguration = CodeFoldingConfiguration()) {
        for region in regions where !foldedRegions.contains(region.id) {
            fold(region, foldedRegions: &foldedRegions, configuration: configuration)
        }
    }

    /// Unfold all regions
    internal func unfoldAll(regions: [FoldableRegion], foldedRegions: inout Set<UUID>, configuration: CodeFoldingConfiguration = CodeFoldingConfiguration()) {
        let regionsToUnfold = regions.filter { foldedRegions.contains($0.id) }

        for region in regionsToUnfold {
            unfold(region, foldedRegions: &foldedRegions, configuration: configuration)
        }
    }

    /// Fold all regions at a specific level
    internal func foldLevel(_ level: Int, regions: [FoldableRegion], foldedRegions: inout Set<UUID>, configuration: CodeFoldingConfiguration = CodeFoldingConfiguration()) {
        for region in regions where region.level == level {
            if !foldedRegions.contains(region.id) {
                fold(region, foldedRegions: &foldedRegions, configuration: configuration)
            }
        }
    }

    /// Get foldable region at line
    internal func foldableRegion(at line: Int, from regions: [FoldableRegion]) -> FoldableRegion? {
        regions.first { region in
            let startLine = lineNumber(for: region.range.location)
            let endLine = lineNumber(for: NSMaxRange(region.range))
            return line >= startLine && line <= endLine
        }
    }

    /// Check if line is in a folded region
    internal func isLineFolded(_ line: Int, regions: [FoldableRegion], foldedRegions: Set<UUID>) -> Bool {
        guard let region = foldableRegion(at: line, from: regions) else { return false }
        return foldedRegions.contains(region.id)
    }

    /// Check if line is the start of a foldable region
    internal func isStartOfFoldableRegion(_ line: Int, regions: [FoldableRegion]) -> Bool {
        regions.contains { region in
            let startLine = lineNumber(for: region.range.location)
            return line == startLine
        }
    }

    // MARK: - Private Methods

    private func applyFoldingVisuals(for region: FoldableRegion, isFolded: Bool, configuration: CodeFoldingConfiguration) {
        guard let textStorage else { return }

        if isFolded {
            // Add fold indicator at the end of the first line
            let firstLineEnd = firstLineEndLocation(for: region.range)
            let indicatorRange = NSRange(location: firstLineEnd, length: 0)

            // Apply folding attributes
            textStorage.addAttributes([
                .foldingIndicator: true,
                .foregroundColor: configuration.indicatorColor
            ], range: indicatorRange)
        } else {
            // Remove fold indicator
            let firstLineEnd = firstLineEndLocation(for: region.range)
            let indicatorRange = NSRange(location: firstLineEnd, length: region.foldedText?.count ?? 0)

            textStorage.removeAttribute(.foldingIndicator, range: indicatorRange)
        }
    }

    private func hideFoldedContent(_ region: FoldableRegion) {
        guard let textStorage else { return }

        // Calculate content range (excluding first line)
        let firstLineEnd = firstLineEndLocation(for: region.range)
        let contentStart = min(firstLineEnd + 1, NSMaxRange(region.range))
        let contentLength = NSMaxRange(region.range) - contentStart

        guard contentLength > 0 else { return }

        let contentRange = NSRange(location: contentStart, length: contentLength)

        // Use cached hidden paragraph style instead of creating new one
        // Apply attributes to hide content
        textStorage.addAttributes([
            .paragraphStyle: ParagraphStyleCache.hiddenParagraphStyle,
            .font: PlatformFont.systemFont(ofSize: 0.1), // Nearly invisible font
            .foregroundColor: PlatformColors.clear,
            .foldedRegion: region.id
        ], range: contentRange)
    }

    private func showUnfoldedContent(_ region: FoldableRegion) {
        guard let textStorage else { return }

        // Calculate content range (excluding first line)
        let firstLineEnd = firstLineEndLocation(for: region.range)
        let contentStart = min(firstLineEnd + 1, NSMaxRange(region.range))
        let contentLength = NSMaxRange(region.range) - contentStart

        guard contentLength > 0 else { return }

        let contentRange = NSRange(location: contentStart, length: contentLength)

        // Remove folding attributes
        textStorage.removeAttribute(.paragraphStyle, range: contentRange)
        textStorage.removeAttribute(.font, range: contentRange)
        textStorage.removeAttribute(.foregroundColor, range: contentRange)
        textStorage.removeAttribute(.foldedRegion, range: contentRange)

        // Restore the configured font
        if let textView {
            let fontSize = textView.configuration.display.fontSize
            let font = PlatformFonts.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            textStorage.addAttribute(.font, value: font, range: contentRange)

            // Force layout update to properly display unfolded content
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textView.setNeedsDisplay(textView.bounds)
            textView.needsLayout = true
            textView.layoutSubtreeIfNeeded()
            #else
            textView.setNeedsDisplay()
            textView.setNeedsLayout()
            textView.layoutIfNeeded()
            #endif
        }
    }

    // MARK: - Utilities

    private func lineNumber(for location: Int) -> Int {
        guard let text = textStorage?.string else { return 0 }
        return RangeUtilities.lineNumber(for: location, in: text)
    }

    private func firstLineEndLocation(for range: NSRange) -> Int {
        guard let text = textStorage?.string else { return range.location }

        let lineRange = RangeUtilities.lineRange(containing: range.location, in: text)

        // Return end of line minus newline character
        let lineEnd = NSMaxRange(lineRange)
        if lineEnd > 0, let charIndex = text.utf16.index(text.utf16.startIndex, offsetBy: lineEnd - 1, limitedBy: text.utf16.endIndex),
           text.utf16[charIndex] == 10 { // \n
            return lineEnd - 1
        }
        return lineEnd
    }
}

// MARK: - NSAttributedString Keys

extension NSAttributedString.Key {
    static let foldingIndicator = NSAttributedString.Key("CodeEditor.foldingIndicator")
    static let foldedRegion = NSAttributedString.Key("CodeEditor.foldedRegion")
}
