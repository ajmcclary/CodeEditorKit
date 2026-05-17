import CodeEditorPlatform
import Foundation

// MARK: - Code Folding Configuration

/// Configuration for code folding behavior
internal struct CodeFoldingConfiguration {
    internal var enabled = true
    internal var showGutterControls = true
    internal var hidesFoldedContent = true
    internal var minimumLineCount = 3
    internal var foldedIndicator = " ⋯ "

    internal var indicatorColor = PlatformColors.secondaryLabel

    internal var animatesFolding = true
    internal var saveFoldState = true
    internal var enableIncrementalUpdates = true
}
