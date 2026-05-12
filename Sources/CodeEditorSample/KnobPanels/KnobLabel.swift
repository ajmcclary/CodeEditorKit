import Foundation

/// Converts raw camelCase property names into human-readable labels and
/// supplies an optional SF Symbol icon per knob. Pure value-only types —
/// no state, no I/O.
enum KnobLabel {
    /// Humanize a camelCase identifier.
    ///
    /// Examples:
    /// - `"isSyntaxHighlightingEnabled"` (toggle)  → `"Syntax Highlighting"`
    /// - `"areFoldingControlsVisible"` (toggle)    → `"Folding Controls"`
    /// - `"minimumFoldableLines"` (stepper)        → `"Minimum Foldable Lines"`
    /// - `"renderingUpdateStrategy"` (picker)      → `"Rendering Update Strategy"`
    /// - `"animateCodeFolding (perf)"`             → `"Animate Code Folding"`
    static func humanize(_ raw: String, dropTrailingState: Bool = false) -> String {
        var working = raw

        if let parenRange = working.range(of: " (") {
            working = String(working[..<parenRange.lowerBound])
        }

        for prefix in ["is", "are", "has"] {
            if working.hasPrefix(prefix),
               working.count > prefix.count,
               let firstAfter = working.dropFirst(prefix.count).first,
               firstAfter.isUppercase {
                working = String(working.dropFirst(prefix.count))
                break
            }
        }

        if dropTrailingState {
            for suffix in ["Enabled", "Visible"] where working.hasSuffix(suffix) {
                working = String(working.dropLast(suffix.count))
                break
            }
        }

        return splitCamelCase(working)
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func splitCamelCase(_ input: String) -> [String] {
        var words: [String] = []
        var current = ""

        for char in input {
            if char.isUppercase, !current.isEmpty,
               let last = current.last, last.isLowercase || last.isNumber {
                words.append(current)
                current = String(char)
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }
}

/// Static lookup of SF Symbol icons keyed by raw property name.
/// Unknown keys return `nil`; rows render without an icon when nil.
enum KnobIcon {
    static func symbol(for rawLabel: String) -> String? {
        let key = rawLabel.range(of: " (").map { String(rawLabel[..<$0.lowerBound]) } ?? rawLabel
        return table[key]
    }

    private static let table: [String: String] = [
        "fontSize": "textformat.size",
        "isSyntaxHighlightingEnabled": "paintpalette",
        "isLineNumbersEnabled": "number",
        "areAnnotationsEnabled": "exclamationmark.bubble",
        "isSelectedLineHighlighted": "rectangle.fill.on.rectangle.fill",
        "selectedLineHighlightColor": "drop",
        "areInvisibleCharactersVisible": "eye",
        "isCodeFoldingEnabled": "chevron.right.square",
        "areFoldingControlsVisible": "chevron.compact.down",
        "minimumFoldableLines": "arrow.up.and.down.text.horizontal",
        "isMinimapVisible": "map",
        "visibleLines": "list.dash",
        "useRangeStoreHighlighting": "paintbrush.pointed",

        "tabWidth": "arrow.right.to.line",
        "insertSpacesForTabs": "space",
        "wrapLines": "arrow.turn.down.right",
        "gutterWidth": "ruler",
        "lineNumberPadding": "arrow.left.and.right",
        "lineHeightMultiple": "arrow.up.and.down",
        "characterSpacing": "arrow.left.and.right.righttriangle.left.righttriangle.right",
        "textContainerWidthFraction": "rectangle.compress.vertical",
        "annotationBadgeSize": "circle.dashed",
        "annotationBadgePadding": "circle.dotted",
        "minimapWidth": "rectangle.split.2x1",
        "foldingControlSize": "chevron.down.square",
        "foldingControlPadding": "square.dashed",

        "isEditable": "pencil",
        "isSelectable": "selection.pin.in.out",
        "isAutoIndentEnabled": "arrow.forward.to.line",
        "autoScrollToCursor": "scope",
        "isAutomaticLinkDetectionEnabled": "link",
        "isAutomaticQuoteSubstitutionEnabled": "quote.bubble",
        "isAutomaticDashSubstitutionEnabled": "minus",
        "autoCloseBrackets": "curlybraces",
        "autoCloseQuotes": "quote.opening",
        "isContinuousSpellCheckingEnabled": "abc",
        "isGrammarCheckingEnabled": "checkmark.bubble",
        "isAutomaticTextReplacementEnabled": "arrow.triangle.swap",
        "isAutomaticSpellingCorrectionEnabled": "wand.and.rays",
        "isCodeCompletionEnabled": "sparkles",
        "isAutomaticTextCompletionEnabled": "text.append",
        "showInlineCompletionSuggestions": "lightbulb",
        "useTreeSitterHighlighting": "tree",
        "completionTriggerCharacters": "keyboard",

        "maxSyntaxHighlightingLength": "ruler.fill",
        "maxVisibleLines": "list.number",
        "maxFileSize": "doc",
        "maxEventsPerSecond": "bolt",
        "useHardwareAcceleration": "cpu",
        "smoothScrolling": "scroll",
        "animateCodeFolding": "wand.and.stars.inverse",
        "usesRangeBasedHighlighting": "ruler",
        "renderingUpdateStrategy": "rectangle.stack",
        "highlightingDebounceInterval": "timer",
        "textChangeDebounceInterval": "hourglass",

        "enableIOSOptimizations": "iphone.gen3",
        "iOSLargeFileThreshold": "doc.badge.gearshape",
        "iOSMaxHighlightingChunk": "square.split.bottomrightquarter",

        "workspaceRoot": "folder"
    ]
}
