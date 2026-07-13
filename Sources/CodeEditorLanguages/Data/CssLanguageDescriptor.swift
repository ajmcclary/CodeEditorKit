import Foundation

extension LanguageDescriptor {
    // ── CSS ────────────────────────────────────────────────────────
    static let cssDescriptor = Self(
            language: .css,
            fileExtensions: ["css", "scss", "sass", "less"],
            usesRegexHighlighter: true,
            lineComment: nil,
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_-][a-zA-Z0-9_-]*",
            stringDelimiters: ["\"", "'"],
            highlightingRules: [
                .init(#"#[a-fA-F0-9]{3,6}\b"#, .number, priority: 8),
                .init(#"\b\d+\.?\d*(px|em|rem|%|vh|vw|pt|pc|in|cm|mm|ex|ch|vmin|vmax|deg|rad|grad|turn|s|ms|Hz|kHz|dpi|dpcm|dppx)?\b"#, .number, priority: 8),
                .init(#"[.#]?[a-zA-Z_][\w-]*(?=\s*\{)"#, .type, priority: 7),
                .init(#"[a-zA-Z-]+(?=\s*:)"#, .property, priority: 6)
            ],
            keywords: [
                "color", "background", "background-color", "margin", "padding", "border", "width",
                "height", "font", "font-size", "font-family", "font-weight", "display", "position",
                "top", "right", "bottom", "left", "flex", "grid", "align-items", "justify-content",
                "z-index", "opacity", "visibility", "overflow", "text-align", "text-decoration",
                "line-height", "box-shadow", "border-radius", "transition", "transform", "animation"
            ],
            types: [],
            functions: [
                "rgb", "rgba", "hsl", "hsla", "url", "var", "calc", "min", "max", "clamp",
                "linear-gradient", "radial-gradient", "translate", "rotate", "scale"
            ],
            literals: [
                "inherit", "initial", "unset", "none", "auto", "normal", "bold", "italic",
                "underline", "solid", "dashed", "dotted", "block", "inline", "inline-block",
                "flex", "grid", "absolute", "relative", "fixed", "sticky"
            ],
            triggerCharacters: [":", " ", ";", "{"],
            snippets: DescriptorSnippetData.css,
            memberCompletions: nil,
            commonModules: [],
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
