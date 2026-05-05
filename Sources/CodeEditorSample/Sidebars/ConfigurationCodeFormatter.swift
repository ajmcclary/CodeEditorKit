import CodeEditorPlugin
import Foundation

/// Renders an `EditorConfiguration` as Swift source — direct property
/// assignments grouped by section. Only fields that differ from the
/// default `EditorConfiguration()` are emitted, to keep the output
/// scannable.
///
/// Pure value-in / string-out — easy to inspect from the inspector
/// sidebar.
enum ConfigurationCodeFormatter {
    static func render(_ configuration: EditorConfiguration) -> String {
        let baseline = EditorConfiguration()
        let sections: [(title: String, lines: [String])] = [
            ("Display", displayLines(configuration, baseline: baseline)),
            ("Layout", layoutLines(configuration, baseline: baseline)),
            ("Behavior", behaviorLines(configuration, baseline: baseline)),
            ("Performance", performanceLines(configuration, baseline: baseline))
        ]

        var out = "var config = EditorConfiguration()\n"
        for (title, lines) in sections where !lines.isEmpty {
            out += "\n// \(title)\n"
            out += lines.joined(separator: "\n")
            out += "\n"
        }

        if sections.allSatisfy({ $0.lines.isEmpty }) {
            out += "\n// (every knob matches its default)\n"
        }

        return out
    }

    // MARK: - Display

    private static func displayLines(
        _ live: EditorConfiguration,
        baseline: EditorConfiguration
    ) -> [String] {
        var lines: [String] = []
        let prefix = "config.display"
        let live = live.display
        let base = baseline.display
        if live.fontSize != base.fontSize {
            lines.append("\(prefix).fontSize = \(formatCGFloat(live.fontSize))")
        }
        if live.enableSyntaxHighlighting != base.enableSyntaxHighlighting {
            lines.append("\(prefix).enableSyntaxHighlighting = \(live.enableSyntaxHighlighting)")
        }
        if live.isLineNumbersEnabled != base.isLineNumbersEnabled {
            lines.append("\(prefix).isLineNumbersEnabled = \(live.isLineNumbersEnabled)")
        }
        if live.enableAnnotations != base.enableAnnotations {
            lines.append("\(prefix).enableAnnotations = \(live.enableAnnotations)")
        }
        if live.highlightSelectedLine != base.highlightSelectedLine {
            lines.append("\(prefix).highlightSelectedLine = \(live.highlightSelectedLine)")
        }
        if live.showInvisibleCharacters != base.showInvisibleCharacters {
            lines.append("\(prefix).showInvisibleCharacters = \(live.showInvisibleCharacters)")
        }
        if live.enableCodeFolding != base.enableCodeFolding {
            lines.append("\(prefix).enableCodeFolding = \(live.enableCodeFolding)")
        }
        if live.showFoldingControls != base.showFoldingControls {
            lines.append("\(prefix).showFoldingControls = \(live.showFoldingControls)")
        }
        if live.minimumFoldableLines != base.minimumFoldableLines {
            lines.append("\(prefix).minimumFoldableLines = \(live.minimumFoldableLines)")
        }
        if live.animateCodeFolding != base.animateCodeFolding {
            lines.append("\(prefix).animateCodeFolding = \(live.animateCodeFolding)")
        }
        if live.showMinimap != base.showMinimap {
            lines.append("\(prefix).showMinimap = \(live.showMinimap)")
        }
        if live.selectedLineHighlightColor != base.selectedLineHighlightColor {
            lines.append("\(prefix).selectedLineHighlightColor = /* custom */")
        }
        return lines
    }

    // MARK: - Layout

    private static func layoutLines(
        _ live: EditorConfiguration,
        baseline: EditorConfiguration
    ) -> [String] {
        var lines: [String] = []
        let prefix = "config.layout"
        let live = live.layout
        let base = baseline.layout
        if live.tabWidth != base.tabWidth {
            lines.append("\(prefix).tabWidth = \(live.tabWidth)")
        }
        if live.insertSpacesForTabs != base.insertSpacesForTabs {
            lines.append("\(prefix).insertSpacesForTabs = \(live.insertSpacesForTabs)")
        }
        if live.wrapLines != base.wrapLines {
            lines.append("\(prefix).wrapLines = \(live.wrapLines)")
        }
        if live.gutterWidth != base.gutterWidth {
            lines.append("\(prefix).gutterWidth = \(formatCGFloat(live.gutterWidth))")
        }
        if live.lineNumberPadding != base.lineNumberPadding {
            lines.append("\(prefix).lineNumberPadding = \(formatCGFloat(live.lineNumberPadding))")
        }
        if live.lineHeightMultiple != base.lineHeightMultiple {
            lines.append("\(prefix).lineHeightMultiple = \(formatCGFloat(live.lineHeightMultiple))")
        }
        if live.characterSpacing != base.characterSpacing {
            lines.append("\(prefix).characterSpacing = \(formatCGFloat(live.characterSpacing))")
        }
        if live.textContainerWidthFraction != base.textContainerWidthFraction {
            lines.append("\(prefix).textContainerWidthFraction = \(formatCGFloat(live.textContainerWidthFraction))")
        }
        if live.annotationBadgeSize != base.annotationBadgeSize {
            lines.append("\(prefix).annotationBadgeSize = \(formatCGFloat(live.annotationBadgeSize))")
        }
        if live.annotationBadgePadding != base.annotationBadgePadding {
            lines.append("\(prefix).annotationBadgePadding = \(formatCGFloat(live.annotationBadgePadding))")
        }
        if live.minimapWidth != base.minimapWidth {
            lines.append("\(prefix).minimapWidth = \(formatCGFloat(live.minimapWidth))")
        }
        if live.foldingControlSize != base.foldingControlSize {
            lines.append("\(prefix).foldingControlSize = \(formatCGFloat(live.foldingControlSize))")
        }
        if live.foldingControlPadding != base.foldingControlPadding {
            lines.append("\(prefix).foldingControlPadding = \(formatCGFloat(live.foldingControlPadding))")
        }
        return lines
    }

    // MARK: - Behavior

    // swiftlint:disable:next function_body_length
    private static func behaviorLines(
        _ live: EditorConfiguration,
        baseline: EditorConfiguration
    ) -> [String] {
        var lines: [String] = []
        let prefix = "config.behavior"
        let live = live.behavior
        let base = baseline.behavior
        if live.isEditable != base.isEditable {
            lines.append("\(prefix).isEditable = \(live.isEditable)")
        }
        if live.isSelectable != base.isSelectable {
            lines.append("\(prefix).isSelectable = \(live.isSelectable)")
        }
        if live.autoIndent != base.autoIndent {
            lines.append("\(prefix).autoIndent = \(live.autoIndent)")
        }
        if live.enableCodeCompletion != base.enableCodeCompletion {
            lines.append("\(prefix).enableCodeCompletion = \(live.enableCodeCompletion)")
        }
        if live.isAutomaticLinkDetectionEnabled != base.isAutomaticLinkDetectionEnabled {
            lines.append("\(prefix).isAutomaticLinkDetectionEnabled = \(live.isAutomaticLinkDetectionEnabled)")
        }
        if live.isAutomaticQuoteSubstitutionEnabled != base.isAutomaticQuoteSubstitutionEnabled {
            lines.append("\(prefix).isAutomaticQuoteSubstitutionEnabled = \(live.isAutomaticQuoteSubstitutionEnabled)")
        }
        if live.isAutomaticDashSubstitutionEnabled != base.isAutomaticDashSubstitutionEnabled {
            lines.append("\(prefix).isAutomaticDashSubstitutionEnabled = \(live.isAutomaticDashSubstitutionEnabled)")
        }
        if live.autoCloseBrackets != base.autoCloseBrackets {
            lines.append("\(prefix).autoCloseBrackets = \(live.autoCloseBrackets)")
        }
        if live.autoCloseQuotes != base.autoCloseQuotes {
            lines.append("\(prefix).autoCloseQuotes = \(live.autoCloseQuotes)")
        }
        if live.isContinuousSpellCheckingEnabled != base.isContinuousSpellCheckingEnabled {
            lines.append("\(prefix).isContinuousSpellCheckingEnabled = \(live.isContinuousSpellCheckingEnabled)")
        }
        if live.isGrammarCheckingEnabled != base.isGrammarCheckingEnabled {
            lines.append("\(prefix).isGrammarCheckingEnabled = \(live.isGrammarCheckingEnabled)")
        }
        if live.isAutomaticTextReplacementEnabled != base.isAutomaticTextReplacementEnabled {
            lines.append("\(prefix).isAutomaticTextReplacementEnabled = \(live.isAutomaticTextReplacementEnabled)")
        }
        if live.isAutomaticSpellingCorrectionEnabled != base.isAutomaticSpellingCorrectionEnabled {
            lines.append("\(prefix).isAutomaticSpellingCorrectionEnabled = \(live.isAutomaticSpellingCorrectionEnabled)")
        }
        if live.isAutomaticTextCompletionEnabled != base.isAutomaticTextCompletionEnabled {
            lines.append("\(prefix).isAutomaticTextCompletionEnabled = \(live.isAutomaticTextCompletionEnabled)")
        }
        if live.showInlineCompletionSuggestions != base.showInlineCompletionSuggestions {
            lines.append("\(prefix).showInlineCompletionSuggestions = \(live.showInlineCompletionSuggestions)")
        }
        if live.completionTriggerCharacters != base.completionTriggerCharacters {
            let chars = live.completionTriggerCharacters.map { "\"\($0)\"" }.sorted().joined(separator: ", ")
            lines.append("\(prefix).completionTriggerCharacters = [\(chars)]")
        }
        if live.autoScrollToCursor != base.autoScrollToCursor {
            lines.append("\(prefix).autoScrollToCursor = \(live.autoScrollToCursor)")
        }
        return lines
    }

    // MARK: - Performance

    private static func performanceLines(
        _ live: EditorConfiguration,
        baseline: EditorConfiguration
    ) -> [String] {
        var lines: [String] = []
        let prefix = "config.performance"
        let live = live.performance
        let base = baseline.performance
        if live.maxSyntaxHighlightingLength != base.maxSyntaxHighlightingLength {
            lines.append("\(prefix).maxSyntaxHighlightingLength = \(live.maxSyntaxHighlightingLength)")
        }
        if live.useHardwareAcceleration != base.useHardwareAcceleration {
            lines.append("\(prefix).useHardwareAcceleration = \(live.useHardwareAcceleration)")
        }
        if live.renderingUpdateStrategy != base.renderingUpdateStrategy {
            lines.append("\(prefix).renderingUpdateStrategy = .\(live.renderingUpdateStrategy)")
        }
        if live.maxVisibleLines != base.maxVisibleLines {
            lines.append("\(prefix).maxVisibleLines = \(live.maxVisibleLines)")
        }
        if live.maxFileSize != base.maxFileSize {
            lines.append("\(prefix).maxFileSize = \(live.maxFileSize)")
        }
        if live.highlightingDebounceInterval != base.highlightingDebounceInterval {
            lines.append("\(prefix).highlightingDebounceInterval = .milliseconds(\(durationMilliseconds(live.highlightingDebounceInterval)))")
        }
        if live.smoothScrolling != base.smoothScrolling {
            lines.append("\(prefix).smoothScrolling = \(live.smoothScrolling)")
        }
        if live.textChangeDebounceInterval != base.textChangeDebounceInterval {
            lines.append("\(prefix).textChangeDebounceInterval = .milliseconds(\(durationMilliseconds(live.textChangeDebounceInterval)))")
        }
        if live.animateCodeFolding != base.animateCodeFolding {
            lines.append("\(prefix).animateCodeFolding = \(live.animateCodeFolding)")
        }
        if live.maxEventsPerSecond != base.maxEventsPerSecond {
            lines.append("\(prefix).maxEventsPerSecond = \(live.maxEventsPerSecond)")
        }
        return lines
    }

    // MARK: - Number formatting

    private static func formatCGFloat(_ value: CGFloat) -> String {
        let rounded = (Double(value) * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return "\(Int(rounded))"
        }
        return String(format: "%.2f", rounded)
    }

    private static func durationMilliseconds(_ duration: Duration) -> Int {
        let attos = duration.components.attoseconds
        let seconds = Double(duration.components.seconds)
        return Int(seconds * 1_000 + Double(attos) / 1_000_000_000_000_000)
    }
}
