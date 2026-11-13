import CodeEditorCommon
import CodeEditorLanguages
import CodeEditorPlatform
import CodeEditorTextModel
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Folding Operations Service

/// Service for managing fold/unfold operations
@MainActor
internal final class FoldingOperationsService {
    private let logger = CodeEditorLog.logger(category: "FoldingOperationsService")

    // MARK: - Properties

    private weak var textView: CodeEditorView?

    // MARK: - Public Methods

    /// Attach to a text view
    internal func attach(to textView: CodeEditorView) {
        guard self.textView !== textView else { return }
        self.textView = textView
    }

    /// Releases the attached editor view.
    internal func detach() {
        textView = nil
    }

    /// Toggle a region's fold state.
    /// - Returns: `true` if fold state was changed
    internal func toggleFold(
        _ region: FoldableRegion,
        foldedRegions: inout Set<UUID>,
        configuration: CodeFoldingConfiguration = CodeFoldingConfiguration()
    ) -> Bool {
        if foldedRegions.contains(region.id) {
            return unfold(region, foldedRegions: &foldedRegions, configuration: configuration)
        }
        return fold(region, foldedRegions: &foldedRegions, configuration: configuration)
    }

    /// Show a folded region's text again without touching fold bookkeeping —
    /// for a fold whose region disappeared on re-detection.
    internal func revealContent(of region: FoldableRegion, configuration: CodeFoldingConfiguration) {
        applyFoldingVisuals(for: region, isFolded: false, configuration: configuration)
        if configuration.hidesFoldedContent {
            showUnfoldedContent(region)
        }
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
        #if canImport(AppKit)
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
        #if canImport(AppKit)
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

    // MARK: - Private Methods

    private func applyFoldingVisuals(for region: FoldableRegion, isFolded: Bool, configuration: CodeFoldingConfiguration) {
        guard let textView else { return }
        let bridge = textView.textKitBridge

        if isFolded {
            // Add fold indicator at the end of the first line
            let firstLineEnd = firstLineEndLocation(for: region.range)
            let indicatorRange = NSRange(location: firstLineEnd, length: 0)

            // Apply folding attributes (persistent — gutter reads .foldingIndicator).
            bridge.addPersistentAttributes([
                .foldingIndicator: true,
                .foregroundColor: configuration.indicatorColor
            ], range: indicatorRange)
        } else {
            // Remove fold indicator
            let firstLineEnd = firstLineEndLocation(for: region.range)
            let documentLength = textView.textKitBridge.documentLength
            let indicatorStart = min(firstLineEnd, documentLength)
            let indicatorRange = NSRange(
                location: indicatorStart,
                length: min(region.foldedText?.utf16.count ?? 0, documentLength - indicatorStart)
            )

            bridge.removePersistentAttribute(.foldingIndicator, range: indicatorRange)
        }
    }

    private func hideFoldedContent(_ region: FoldableRegion) {
        guard let textView else { return }
        let bridge = textView.textKitBridge
        guard let contentRange = contentRange(of: region) else { return }

        // Apply attributes to hide content (persistent — layout attributes).
        bridge.addPersistentAttributes([
            .paragraphStyle: ParagraphStyleCache.hiddenParagraphStyle,
            .font: PlatformFont.systemFont(ofSize: 0.1), // Nearly invisible font
            .foregroundColor: PlatformColors.clear,
            .foldedRegion: region.id
        ], range: contentRange)
    }

    private func showUnfoldedContent(_ region: FoldableRegion) {
        guard let textView else { return }
        let bridge = textView.textKitBridge
        guard let contentRange = contentRange(of: region) else { return }

        // Remove folding attributes (persistent).
        bridge.removePersistentAttributes(
            [.paragraphStyle, .font, .foregroundColor, .foldedRegion],
            range: contentRange
        )

        // Put back every attribute hiding overwrote, as the editor stamps
        // them on the rest of the document: paragraph style (tab stops, line
        // height), font and the theme foreground.
        bridge.addPersistentAttributes(textView.baseTextAttributes(), range: contentRange)

        // Force layout update to properly display unfolded content
        #if canImport(AppKit)
        textView.setNeedsDisplay(textView.bounds)
        textView.needsLayout = true
        textView.layoutSubtreeIfNeeded()
        #else
        textView.setNeedsDisplay()
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        #endif
    }

    // MARK: - Utilities

    /// The region's text after its first line, clamped to the storage: the
    /// region's range can be stale between an edit and re-detection.
    private func contentRange(of region: FoldableRegion) -> NSRange? {
        guard let textView else { return nil }
        let length = textView.textKitBridge.documentLength
        let regionStart = max(0, min(region.range.location, length))
        let regionEnd = max(regionStart, min(NSMaxRange(region.range), length))
        let clampedRegion = NSRange(location: regionStart, length: regionEnd - regionStart)
        let firstLineEnd = firstLineEndLocation(for: clampedRegion)
        let contentStart = min(firstLineEnd + 1, regionEnd)
        let contentLength = regionEnd - contentStart
        guard contentLength > 0 else { return nil }
        return NSRange(location: contentStart, length: contentLength)
    }

    private func firstLineEndLocation(for range: NSRange) -> Int {
        let text = textView?.textKitBridge.documentString ?? ""
        guard !text.isEmpty else { return range.location }

        let lineRange = TextRangeUtilities.lineRange(containing: range.location, in: text)

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
