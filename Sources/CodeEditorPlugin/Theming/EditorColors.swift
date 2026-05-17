import CodeEditorDesignTokens
import Foundation

/// Editor-surface colors mapped to Zed's `editor.*` keys.
/// Sixteen knobs covering background, gutter, line highlight, and
/// document-highlight regions.
public struct EditorColors: Hashable, Sendable, Codable {
    /// Editor canvas background.
    public let background: Tokens.Color
    /// Default text foreground.
    public let foreground: Tokens.Color
    /// Gutter background fill.
    public let gutterBackground: Tokens.Color
    /// Active-line highlight tint.
    public let activeLineBackground: Tokens.Color
    /// Highlighted-line tint (find-result, debugger stop, etc.).
    public let highlightedLineBackground: Tokens.Color
    /// Active line-number color.
    public let activeLineNumber: Tokens.Color
    /// Default line-number color.
    public let lineNumber: Tokens.Color
    /// Color used to render invisible glyphs.
    public let invisible: Tokens.Color
    /// Indent-guide vertical line color.
    public let indentGuide: Tokens.Color
    /// Indent-guide line color when on the active indentation level.
    public let indentGuideActive: Tokens.Color
    /// Wrap-guide line color.
    public let wrapGuide: Tokens.Color
    /// Wrap-guide line color when active.
    public let activeWrapGuide: Tokens.Color
    /// Sub-header band background (e.g., section divider).
    public let subheaderBackground: Tokens.Color
    /// Document-highlight read background.
    public let documentHighlightRead: Tokens.Color
    /// Document-highlight write background.
    public let documentHighlightWrite: Tokens.Color
    /// Document-highlight bracket-match background.
    public let documentHighlightBracket: Tokens.Color
    /// Unknown `editor.*` keys preserved on decode.
    public let extras: [String: Tokens.Color]

    /// Memberwise builder.
    public init(
        background: Tokens.Color,
        foreground: Tokens.Color,
        gutterBackground: Tokens.Color,
        activeLineBackground: Tokens.Color,
        highlightedLineBackground: Tokens.Color,
        activeLineNumber: Tokens.Color,
        lineNumber: Tokens.Color,
        invisible: Tokens.Color,
        indentGuide: Tokens.Color,
        indentGuideActive: Tokens.Color,
        wrapGuide: Tokens.Color,
        activeWrapGuide: Tokens.Color,
        subheaderBackground: Tokens.Color,
        documentHighlightRead: Tokens.Color,
        documentHighlightWrite: Tokens.Color,
        documentHighlightBracket: Tokens.Color,
        extras: [String: Tokens.Color] = [:]
    ) {
        self.background = background
        self.foreground = foreground
        self.gutterBackground = gutterBackground
        self.activeLineBackground = activeLineBackground
        self.highlightedLineBackground = highlightedLineBackground
        self.activeLineNumber = activeLineNumber
        self.lineNumber = lineNumber
        self.invisible = invisible
        self.indentGuide = indentGuide
        self.indentGuideActive = indentGuideActive
        self.wrapGuide = wrapGuide
        self.activeWrapGuide = activeWrapGuide
        self.subheaderBackground = subheaderBackground
        self.documentHighlightRead = documentHighlightRead
        self.documentHighlightWrite = documentHighlightWrite
        self.documentHighlightBracket = documentHighlightBracket
        self.extras = extras
    }

    /// Build from a flat dictionary keyed by Zed dotted names. `appearance`
    /// selects between light and dark fallback colors when a key is missing.
    init(
        flat: [String: Tokens.Color],
        warnings: WarningCollector,
        path: String,
        appearance: Theme.Appearance
    ) {
        let bgFallback = ThemeFallbackPalette.background(appearance)
        let textFallback = ThemeFallbackPalette.textBase(appearance)
        let mutedFallback = ThemeFallbackPalette.textMuted(appearance)
        let borderFallback = ThemeFallbackPalette.border(appearance)
        let accentFallback = ThemeFallbackPalette.textAccent(appearance)
        let lowAccent = Tokens.Color(red: accentFallback.red, green: accentFallback.green, blue: accentFallback.blue, alpha: 0.10)
        self.background = flat["editor.background"]
            ?? warnings.missing(path: path, key: "editor.background", fallback: bgFallback)
        self.foreground = flat["editor.foreground"]
            ?? warnings.missing(path: path, key: "editor.foreground", fallback: textFallback)
        self.gutterBackground = flat["editor.gutter.background"]
            ?? warnings.missing(path: path, key: "editor.gutter.background", fallback: bgFallback)
        self.activeLineBackground = flat["editor.active_line.background"]
            ?? warnings.missing(
                path: path, key: "editor.active_line.background", fallback: lowAccent
            )
        self.highlightedLineBackground = flat["editor.highlighted_line.background"]
            ?? warnings.missing(
                path: path, key: "editor.highlighted_line.background", fallback: lowAccent
            )
        self.activeLineNumber = flat["editor.active_line_number"]
            ?? warnings.missing(
                path: path, key: "editor.active_line_number", fallback: accentFallback
            )
        self.lineNumber = flat["editor.line_number"]
            ?? warnings.missing(path: path, key: "editor.line_number", fallback: mutedFallback)
        self.invisible = flat["editor.invisible"]
            ?? warnings.missing(path: path, key: "editor.invisible", fallback: borderFallback)
        self.indentGuide = flat["editor.indent_guide"]
            ?? warnings.missing(path: path, key: "editor.indent_guide", fallback: borderFallback)
        self.indentGuideActive = flat["editor.indent_guide_active"]
            ?? warnings.missing(
                path: path, key: "editor.indent_guide_active", fallback: accentFallback
            )
        self.wrapGuide = flat["editor.wrap_guide"]
            ?? warnings.missing(path: path, key: "editor.wrap_guide", fallback: borderFallback)
        self.activeWrapGuide = flat["editor.active_wrap_guide"]
            ?? warnings.missing(
                path: path, key: "editor.active_wrap_guide", fallback: accentFallback
            )
        self.subheaderBackground = flat["editor.subheader.background"]
            ?? warnings.missing(
                path: path, key: "editor.subheader.background", fallback: bgFallback
            )
        self.documentHighlightRead = flat["editor.document_highlight.read_background"]
            ?? warnings.missing(
                path: path, key: "editor.document_highlight.read_background", fallback: lowAccent
            )
        self.documentHighlightWrite = flat["editor.document_highlight.write_background"]
            ?? warnings.missing(
                path: path, key: "editor.document_highlight.write_background", fallback: lowAccent
            )
        self.documentHighlightBracket = flat["editor.document_highlight.bracket_background"]
            ?? warnings.missing(
                path: path,
                key: "editor.document_highlight.bracket_background",
                fallback: lowAccent
            )
        self.extras = Dictionary(uniqueKeysWithValues:
            flat.filter { $0.key.hasPrefix("editor.") && !Self.knownKeys.contains($0.key) }
                .map { ($0.key, $0.value) })
    }

    /// Emit own keys back into a flat dictionary.
    package func flatten(into dict: inout [String: Tokens.Color]) {
        dict["editor.background"] = background
        dict["editor.foreground"] = foreground
        dict["editor.gutter.background"] = gutterBackground
        dict["editor.active_line.background"] = activeLineBackground
        dict["editor.highlighted_line.background"] = highlightedLineBackground
        dict["editor.active_line_number"] = activeLineNumber
        dict["editor.line_number"] = lineNumber
        dict["editor.invisible"] = invisible
        dict["editor.indent_guide"] = indentGuide
        dict["editor.indent_guide_active"] = indentGuideActive
        dict["editor.wrap_guide"] = wrapGuide
        dict["editor.active_wrap_guide"] = activeWrapGuide
        dict["editor.subheader.background"] = subheaderBackground
        dict["editor.document_highlight.read_background"] = documentHighlightRead
        dict["editor.document_highlight.write_background"] = documentHighlightWrite
        dict["editor.document_highlight.bracket_background"] = documentHighlightBracket
        for (key, value) in extras { dict[key] = value }
    }

    static let knownKeys: Set<String> = [
        "editor.background",
        "editor.foreground",
        "editor.gutter.background",
        "editor.active_line.background",
        "editor.highlighted_line.background",
        "editor.active_line_number",
        "editor.line_number",
        "editor.invisible",
        "editor.indent_guide",
        "editor.indent_guide_active",
        "editor.wrap_guide",
        "editor.active_wrap_guide",
        "editor.subheader.background",
        "editor.document_highlight.read_background",
        "editor.document_highlight.write_background",
        "editor.document_highlight.bracket_background"
    ]
}
