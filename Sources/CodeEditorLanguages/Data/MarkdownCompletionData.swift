import Foundation

// MARK: - Markdown Completion Data

/// Static data constants for Markdown completion provider
public enum MarkdownCompletionData {
    // MARK: - Markdown Syntax Elements

    static let markdownSyntax = [
        "**bold**", "*italic*", "_italic_", "__bold__", "~~strikethrough~~",
        "`inline code`", "```code block```", "[link](url)", "![image](url)",
        "# heading 1", "## heading 2", "### heading 3", "#### heading 4",
        "##### heading 5", "###### heading 6", "---", "***", "___",
        "> blockquote", "- list item", "+ list item", "* list item",
        "1. numbered list", "| table |", "<!-- comment -->", "<br>", "<hr>"
    ]

    // MARK: - Common Markdown Elements

    static let elements = [
        "heading", "paragraph", "blockquote", "list", "table", "code", "link",
        "image", "emphasis", "strong", "strikethrough", "horizontal-rule",
        "line-break", "comment", "footnote", "definition-list", "task-list"
    ]

    // MARK: - HTML Tags

    static let htmlTags = [
        "div", "span", "p", "br", "hr", "h1", "h2", "h3", "h4", "h5", "h6",
        "strong", "em", "b", "i", "u", "s", "del", "ins", "mark", "sub", "sup",
        "code", "pre", "kbd", "samp", "var", "small", "big", "abbr", "cite",
        "blockquote", "q", "ul", "ol", "li", "dl", "dt", "dd", "table", "thead",
        "tbody", "tfoot", "tr", "th", "td", "caption", "colgroup", "col",
        "a", "img", "figure", "figcaption", "picture", "source", "video", "audio",
        "iframe", "embed", "object", "param", "details", "summary", "dialog"
    ]

    // MARK: - HTML Attributes

    static let htmlAttributes = [
        "id", "class", "style", "title", "lang", "dir", "hidden", "tabindex",
        "accesskey", "contenteditable", "draggable", "spellcheck", "translate",
        "href", "target", "rel", "download", "hreflang", "type", "media",
        "src", "alt", "width", "height", "loading", "sizes", "srcset",
        "colspan", "rowspan", "headers", "scope", "data-*", "aria-*"
    ]

    // MARK: - Emoji Shortcuts

    static let emojiShortcuts = [
        ":smile:", ":grin:", ":laughing:", ":wink:", ":smirk:", ":heart_eyes:",
        ":kissing_heart:", ":relaxed:", ":satisfied:", ":grinning:", ":innocent:",
        ":winking:", ":blush:", ":slight_smile:", ":upside_down:", ":relieved:",
        ":heart:", ":yellow_heart:", ":green_heart:", ":blue_heart:", ":purple_heart:",
        ":broken_heart:", ":heartbeat:", ":heartpulse:", ":two_hearts:", ":revolving_hearts:",
        ":thumbsup:", ":thumbsdown:", ":ok_hand:", ":punch:", ":fist:", ":v:",
        ":wave:", ":hand:", ":open_hands:", ":point_up:", ":point_down:",
        ":point_left:", ":point_right:", ":raised_hands:", ":pray:", ":clap:",
        ":fire:", ":star:", ":star2:", ":sparkles:", ":zap:", ":boom:", ":collision:",
        ":dizzy:", ":sweat_drops:", ":dash:", ":droplet:", ":ocean:", ":snowflake:"
    ]

    // MARK: - LaTeX Math Symbols

    static let mathSymbols = [
        "\\alpha", "\\beta", "\\gamma", "\\delta", "\\epsilon", "\\zeta", "\\eta",
        "\\theta", "\\iota", "\\kappa", "\\lambda", "\\mu", "\\nu", "\\xi",
        "\\pi", "\\rho", "\\sigma", "\\tau", "\\upsilon", "\\phi", "\\chi", "\\psi", "\\omega",
        "\\sum", "\\prod", "\\int", "\\frac", "\\sqrt", "\\cdot", "\\times", "\\div",
        "\\pm", "\\mp", "\\leq", "\\geq", "\\neq", "\\approx", "\\equiv", "\\subset",
        "\\supset", "\\subseteq", "\\supseteq", "\\in", "\\notin", "\\emptyset",
        "\\infty", "\\partial", "\\nabla", "\\exists", "\\forall", "\\therefore", "\\because"
    ]

    // MARK: - Link Patterns

    static let linkPatterns = [
        "http://", "https://", "ftp://", "mailto:", "tel:", "sms:", "file://",
        "www.", ".com", ".org", ".net", ".edu", ".gov", ".io", ".co", ".me"
    ]

    // MARK: - Snippet Templates

    static let snippets: [SnippetTemplate] = [
        SnippetTemplate(
            label: "link",
            insertText: "[${1:text}](${2:url})",
            description: "Link"
        ),
        SnippetTemplate(
            label: "image",
            insertText: "![${1:alt text}](${2:image url})",
            description: "Image"
        ),
        SnippetTemplate(
            label: "code",
            insertText: "`${1:code}`",
            description: "Inline code"
        ),
        SnippetTemplate(
            label: "codeblock",
            insertText: """
```${1:language}
${2:code}
```
""",
            description: "Code block"
        ),
        SnippetTemplate(
            label: "table",
            insertText: """
| ${1:Header 1} | ${2:Header 2} | ${3:Header 3} |
|----------|----------|----------|
| ${4:Cell 1}   | ${5:Cell 2}   | ${6:Cell 3}   |
| ${7:Cell 4}   | ${8:Cell 5}   | ${9:Cell 6}   |
""",
            description: "Table"
        ),
        SnippetTemplate(
            label: "table-simple",
            insertText: """
| ${1:Column 1} | ${2:Column 2} |
|-----------|-----------|
| ${3:Value 1}  | ${4:Value 2}  |
""",
            description: "Simple table"
        ),
        SnippetTemplate(
            label: "checklist",
            insertText: """
- [ ] ${1:Task 1}
- [ ] ${2:Task 2}
- [x] ${3:Completed task}
""",
            description: "Task list"
        ),
        SnippetTemplate(
            label: "quote",
            insertText: "> ${1:Quote text}",
            description: "Blockquote"
        ),
        SnippetTemplate(
            label: "quote-multi",
            insertText: """
> ${1:First line}
> ${2:Second line}
> ${3:Third line}
""",
            description: "Multi-line blockquote"
        ),
        SnippetTemplate(
            label: "details",
            insertText: """
<details>
<summary>${1:Summary}</summary>

${2:Content}

</details>
""",
            description: "Collapsible details"
        ),
        SnippetTemplate(
            label: "footnote",
            insertText: "[^${1:1}]: ${2:Footnote text}",
            description: "Footnote definition"
        ),
        SnippetTemplate(
            label: "footnote-ref",
            insertText: "[^${1:1}]",
            description: "Footnote reference"
        ),
        SnippetTemplate(
            label: "kbd",
            insertText: "<kbd>${1:key}</kbd>",
            description: "Keyboard key"
        ),
        SnippetTemplate(
            label: "math",
            insertText: "$${1:formula}$",
            description: "Inline math"
        ),
        SnippetTemplate(
            label: "math-block",
            insertText: """
$$
${1:formula}
$$
""",
            description: "Math block"
        ),
        SnippetTemplate(
            label: "admonition",
            insertText: """
> [!${1:NOTE}]
> ${2:Content}
""",
            description: "GitHub-style admonition"
        ),
        SnippetTemplate(
            label: "mermaid",
            insertText: """
```mermaid
${1:graph TD
    A[Start] --> B[Process]
    B --> C[End]
}
```
""",
            description: "Mermaid diagram"
        ),
        SnippetTemplate(
            label: "frontmatter",
            insertText: """
---
title: ${1:Title}
date: ${2:\\$CURRENT_YEAR-\\$CURRENT_MONTH-\\$CURRENT_DATE}
tags: [${3:tag1, tag2}]
---
""",
            description: "YAML frontmatter"
        ),
        SnippetTemplate(
            label: "abbr",
            insertText: "*[${1:abbr}]: ${2:definition}",
            description: "Abbreviation definition"
        )
    ]

    // MARK: - GitHub Flavored Markdown Elements

    static let gfmElements = [
        "@mention", "#issue", "task list", "table", "strikethrough",
        "emoji", "syntax highlighting", "footnote", "heading ID",
        "definition list", "highlight", "subscript", "superscript"
    ]

    // MARK: - Common Markdown File Extensions

    static let markdownExtensions = [
        ".md", ".markdown", ".mdown", ".mkdn", ".mkd", ".mdwn",
        ".mdtxt", ".mdtext", ".text", ".Rmd"
    ]
}
