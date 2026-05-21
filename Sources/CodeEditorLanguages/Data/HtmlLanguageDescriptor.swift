import Foundation

extension LanguageDescriptor {
    // ── HTML ───────────────────────────────────────────────────────
    static let htmlDescriptor = Self(
            language: .html,
            displayName: "HTML",
            fileExtensions: ["html", "htm", "xhtml"],
            lspIdentifier: "html",
            usesRegexHighlighter: true,
            lineComment: nil,
            blockCommentStart: "<!--",
            blockCommentEnd: "-->",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_-]*",
            stringDelimiters: ["\"", "'"],
            highlightingRules: [
                .init(#"<!--[\s\S]*?-->"#, .comment, priority: 10),
                .init(#"</?[a-zA-Z][a-zA-Z0-9]*\b[^>]*>"#, .keyword, priority: 8),
                .init(#"\b[a-zA-Z-]+(?==)"#, .property, priority: 7)
            ],
            keywords: [
                "html", "head", "body", "title", "meta", "link", "script", "style", "div", "span",
                "p", "a", "img", "ul", "ol", "li", "table", "tr", "td", "th", "form", "input",
                "button", "select", "option", "textarea", "label", "header", "footer", "nav",
                "main", "section", "article", "aside", "h1", "h2", "h3", "h4", "h5", "h6"
            ],
            types: [],
            functions: [],
            literals: [],
            triggerCharacters: ["<", " ", "=", "\"", "'"],
            snippets: DescriptorSnippetData.html,
            memberCompletions: nil,
            commonModules: [],
            parserName: "html",
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
