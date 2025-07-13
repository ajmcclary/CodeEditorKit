import Foundation

// MARK: - Markdown Completion Provider

/// Built-in completion provider for Markdown language
@MainActor
public final class MarkdownCompletionProvider: CompletionProvider {
    public let id = "markdown-builtin"
    public let supportedLanguages: [Language] = [.markdown]
    public let triggerCharacters = ["#", "*", "_", "[", "]", "(", ")", "`", "!", "|", "-", "+", ":", "<", ">", " "]
    public let supportsSnippets = true
    
    // Markdown syntax elements
    private let markdownSyntax = [
        "**bold**", "*italic*", "_italic_", "__bold__", "~~strikethrough~~",
        "`inline code`", "```code block```", "[link](url)", "![image](url)",
        "# heading 1", "## heading 2", "### heading 3", "#### heading 4",
        "##### heading 5", "###### heading 6", "---", "***", "___",
        "> blockquote", "- list item", "+ list item", "* list item",
        "1. numbered list", "| table |", "<!-- comment -->", "<br>", "<hr>"
    ]
    
    // Common markdown elements
    private let elements = [
        "heading", "paragraph", "blockquote", "list", "table", "code", "link",
        "image", "emphasis", "strong", "strikethrough", "horizontal-rule",
        "line-break", "comment", "footnote", "definition-list", "task-list"
    ]
    
    // HTML tags commonly used in Markdown
    private let htmlTags = [
        "div", "span", "p", "br", "hr", "h1", "h2", "h3", "h4", "h5", "h6",
        "strong", "em", "b", "i", "u", "s", "del", "ins", "mark", "sub", "sup",
        "code", "pre", "kbd", "samp", "var", "small", "big", "abbr", "cite",
        "blockquote", "q", "ul", "ol", "li", "dl", "dt", "dd", "table", "thead",
        "tbody", "tfoot", "tr", "th", "td", "caption", "colgroup", "col",
        "a", "img", "figure", "figcaption", "picture", "source", "video", "audio",
        "iframe", "embed", "object", "param", "details", "summary", "dialog"
    ]
    
    // HTML attributes
    private let htmlAttributes = [
        "id", "class", "style", "title", "lang", "dir", "hidden", "tabindex",
        "accesskey", "contenteditable", "draggable", "spellcheck", "translate",
        "href", "target", "rel", "download", "hreflang", "type", "media",
        "src", "alt", "width", "height", "loading", "sizes", "srcset",
        "colspan", "rowspan", "headers", "scope", "data-*", "aria-*"
    ]
    
    // Emoji shortcuts (commonly used)
    private let emojiShortcuts = [
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
    
    // LaTeX math symbols (for math expressions)
    private let mathSymbols = [
        "\\alpha", "\\beta", "\\gamma", "\\delta", "\\epsilon", "\\zeta", "\\eta",
        "\\theta", "\\iota", "\\kappa", "\\lambda", "\\mu", "\\nu", "\\xi",
        "\\pi", "\\rho", "\\sigma", "\\tau", "\\upsilon", "\\phi", "\\chi", "\\psi", "\\omega",
        "\\sum", "\\prod", "\\int", "\\frac", "\\sqrt", "\\cdot", "\\times", "\\div",
        "\\pm", "\\mp", "\\leq", "\\geq", "\\neq", "\\approx", "\\equiv", "\\subset",
        "\\supset", "\\subseteq", "\\supseteq", "\\in", "\\notin", "\\emptyset",
        "\\infty", "\\partial", "\\nabla", "\\exists", "\\forall", "\\therefore", "\\because"
    ]
    
    // Common link patterns
    private let linkPatterns = [
        "http://", "https://", "ftp://", "mailto:", "tel:", "sms:", "file://",
        "www.", ".com", ".org", ".net", ".edu", ".gov", ".io", ".co", ".me"
    ]
    
    private let snippets: [SnippetTemplate] = [
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
graph TD
    A[${1:Start}] --> B{${2:Decision}}
    B -->|${3:Yes}| C[${4:End}]
    B -->|${5:No}| D[${6:Alternative}]
```
""",
            description: "Mermaid diagram"
        ),
        SnippetTemplate(
            label: "h1",
            insertText: "# ${1:Heading}",
            description: "Heading 1"
        ),
        SnippetTemplate(
            label: "h2",
            insertText: "## ${1:Heading}",
            description: "Heading 2"
        ),
        SnippetTemplate(
            label: "h3",
            insertText: "### ${1:Heading}",
            description: "Heading 3"
        ),
        SnippetTemplate(
            label: "h4",
            insertText: "#### ${1:Heading}",
            description: "Heading 4"
        ),
        SnippetTemplate(
            label: "h5",
            insertText: "##### ${1:Heading}",
            description: "Heading 5"
        ),
        SnippetTemplate(
            label: "h6",
            insertText: "###### ${1:Heading}",
            description: "Heading 6"
        ),
        SnippetTemplate(
            label: "hr",
            insertText: "---",
            description: "Horizontal rule"
        ),
        SnippetTemplate(
            label: "badge",
            insertText: "[![${1:Alt text}](${2:badge url})](${3:link url})",
            description: "Badge/shield"
        ),
        SnippetTemplate(
            label: "youtube",
            insertText: "[![${1:Video title}](https://img.youtube.com/vi/${2:VIDEO_ID}/0.jpg)](https://www.youtube.com/watch?v=${2:VIDEO_ID})",
            description: "YouTube video embed"
        )
    ]
    
    public init() {}
    
    // MARK: - CompletionProvider Implementation
    
    public func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()
        
        // Analyze context to determine what kind of completions to provide
        let analysisResult = analyzeContext(context)
        var items: [CompletionItemModel] = []
        
        // Add appropriate completions based on context
        switch analysisResult.type {
        case .heading:
            items.append(contentsOf: createHeadingCompletions(filter: analysisResult.filter))
            
        case .link:
            items.append(contentsOf: createLinkCompletions(filter: analysisResult.filter))
            
        case .image:
            items.append(contentsOf: createImageCompletions(filter: analysisResult.filter))
            
        case .emphasis:
            items.append(contentsOf: createEmphasisCompletions(filter: analysisResult.filter))
            
        case .list:
            items.append(contentsOf: createListCompletions(filter: analysisResult.filter))
            
        case .table:
            items.append(contentsOf: createTableCompletions(filter: analysisResult.filter))
            
        case .codeBlock:
            items.append(contentsOf: createCodeBlockCompletions(filter: analysisResult.filter))
            
        case .htmlTag:
            items.append(contentsOf: createHtmlTagCompletions(filter: analysisResult.filter))
            
        case .htmlAttribute:
            items.append(contentsOf: createHtmlAttributeCompletions(for: analysisResult.htmlTag, filter: analysisResult.filter))
            
        case .emoji:
            items.append(contentsOf: createEmojiCompletions(filter: analysisResult.filter))
            
        case .math:
            items.append(contentsOf: createMathCompletions(filter: analysisResult.filter))
            
        case .general:
            items.append(contentsOf: createSyntaxCompletions(filter: analysisResult.filter))
            if supportsSnippets {
                items.append(contentsOf: createSnippetCompletions(filter: analysisResult.filter))
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return CompletionResult(
            items: items,
            context: context,
            isIncomplete: false,
            processingTime: processingTime
        )
    }
    
    // MARK: - Context Analysis
    
    private func analyzeContext(_ context: CompletionContextModel) -> MarkdownContextAnalysisResult {
        let lineText = context.lineText
        let beforeCursor = String(context.text.prefix(context.cursorPosition))
        
        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)
        
        // Check for math context
        if beforeCursor.contains("$") && !beforeCursor.hasSuffix("$") {
            return MarkdownContextAnalysisResult(type: .math, filter: filter)
        }
        
        // Check for emoji context
        if beforeCursor.hasSuffix(":") || (filter.hasPrefix(":") && !filter.hasSuffix(":")) {
            return MarkdownContextAnalysisResult(type: .emoji, filter: filter)
        }
        
        // Check for heading context
        if lineText.hasPrefix("#") {
            return MarkdownContextAnalysisResult(type: .heading, filter: filter)
        }
        
        // Check for link context
        if beforeCursor.hasSuffix("[") || isInLinkContext(beforeCursor) {
            return MarkdownContextAnalysisResult(type: .link, filter: filter)
        }
        
        // Check for image context
        if beforeCursor.hasSuffix("![") || (beforeCursor.contains("![") && !beforeCursor.contains("](")) {
            return MarkdownContextAnalysisResult(type: .image, filter: filter)
        }
        
        // Check for code block context
        if beforeCursor.hasSuffix("```") {
            return MarkdownContextAnalysisResult(type: .codeBlock, filter: filter)
        }
        
        // Check for HTML tag context
        if beforeCursor.hasSuffix("<") || isInHtmlTag(beforeCursor) {
            let htmlTag = extractCurrentHtmlTag(from: beforeCursor)
            if isInHtmlAttribute(beforeCursor) {
                return MarkdownContextAnalysisResult(type: .htmlAttribute, filter: filter, htmlTag: htmlTag)
            } else {
                return MarkdownContextAnalysisResult(type: .htmlTag, filter: filter)
            }
        }
        
        // Check for table context
        if lineText.contains("|") || beforeCursor.hasSuffix("|") {
            return MarkdownContextAnalysisResult(type: .table, filter: filter)
        }
        
        // Check for list context
        if isInListContext(lineText) {
            return MarkdownContextAnalysisResult(type: .list, filter: filter)
        }
        
        // Check for emphasis context
        if isInEmphasisContext(beforeCursor) {
            return MarkdownContextAnalysisResult(type: .emphasis, filter: filter)
        }
        
        return MarkdownContextAnalysisResult(type: .general, filter: filter)
    }
    
    private func extractCurrentWord(from text: String) -> String {
        if text.hasSuffix(":") {
            return ":"
        }
        
        if text.hasSuffix("[") || text.hasSuffix("![") {
            return ""
        }
        
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-:#")).inverted)
        return components.last ?? ""
    }
    
    private func isInLinkContext(_ text: String) -> Bool {
        // Check if we're inside [] brackets for link text
        let openBrackets = text.components(separatedBy: "[").count - 1
        let closeBrackets = text.components(separatedBy: "]").count - 1
        return openBrackets > closeBrackets && !text.hasSuffix("![")
    }
    
    private func isInHtmlTag(_ text: String) -> Bool {
        let lastOpen = text.lastIndex(of: "<") ?? text.startIndex
        let lastClose = text.lastIndex(of: ">") ?? text.startIndex
        return lastOpen > lastClose
    }
    
    private func isInHtmlAttribute(_ text: String) -> Bool {
        guard isInHtmlTag(text) else { return false }
        
        // Check if we're after a space and before the closing >
        let pattern = #"<\w+\s+[^>]*$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }
        return false
    }
    
    private func extractCurrentHtmlTag(from text: String) -> String? {
        let pattern = #"<(\w+)[^>]*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }
    
    private func isInListContext(_ lineText: String) -> Bool {
        let trimmed = lineText.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("- ") || trimmed.hasPrefix("+ ") || trimmed.hasPrefix("* ") ||
               trimmed.hasPrefix("1. ") || trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]")
    }
    
    private func isInEmphasisContext(_ text: String) -> Bool {
        text.hasSuffix("*") || text.hasSuffix("_") || text.hasSuffix("**") || text.hasSuffix("__")
    }
    
    // MARK: - Completion Creation Methods
    
    private func createHeadingCompletions(filter: String) -> [CompletionItemModel] {
        let headings = ["# ", "## ", "### ", "#### ", "##### ", "###### "]
        
        return headings
            .filter { heading in
                filter.isEmpty || heading.localizedCaseInsensitiveContains(filter)
            }
            .map { heading in
                let level = heading.trimmingCharacters(in: .whitespaces).count
                return CompletionItemModel(
                    label: heading.trimmingCharacters(in: .whitespaces),
                    insertText: "\(heading)${1:Heading}",
                    kind: .property,
                    detail: "Heading level \(level)",
                    priority: 85,
                    snippetSupport: true
                )
            }
    }
    
    private func createLinkCompletions(filter: String) -> [CompletionItemModel] {
        var items: [CompletionItemModel] = []
        
        // Link syntax completion
        items.append(CompletionItemModel(
            label: "[text](url)",
            insertText: "[${1:text}](${2:url})",
            kind: .snippet,
            detail: "Link",
            priority: 90,
            snippetSupport: true
        ))
        
        // Common URL patterns
        let patterns = linkPatterns.filter { pattern in
            filter.isEmpty || pattern.localizedCaseInsensitiveContains(filter)
        }
        
        items.append(contentsOf: patterns.map { pattern in
            CompletionItemModel(
                label: pattern,
                insertText: pattern,
                kind: .value,
                detail: "URL pattern",
                priority: 75
            )
        })
        
        return items
    }
    
    private func createImageCompletions(filter _: String) -> [CompletionItemModel] {
        [
            CompletionItemModel(
                label: "![alt](url)",
                insertText: "![${1:alt text}](${2:image url})",
                kind: .snippet,
                detail: "Image",
                priority: 90,
                snippetSupport: true
            ),
            CompletionItemModel(
                label: "![alt](url \"title\")",
                insertText: "![${1:alt text}](${2:image url} \"${3:title}\")",
                kind: .snippet,
                detail: "Image with title",
                priority: 85,
                snippetSupport: true
            )
        ]
    }
    
    private func createEmphasisCompletions(filter: String) -> [CompletionItemModel] {
        let emphasisPatterns = [
            ("*italic*", "*${1:text}*", "Italic text"),
            ("**bold**", "**${1:text}**", "Bold text"),
            ("***bold italic***", "***${1:text}***", "Bold italic text"),
            ("~~strikethrough~~", "~~${1:text}~~", "Strikethrough text"),
            ("`code`", "`${1:code}`", "Inline code"),
            ("_italic_", "_${1:text}_", "Italic text (underscore)"),
            ("__bold__", "__${1:text}__", "Bold text (underscore)")
        ]
        
        return emphasisPatterns
            .filter { label, _, _ in
                filter.isEmpty || label.localizedCaseInsensitiveContains(filter)
            }
            .map { label, insertText, description in
                CompletionItemModel(
                    label: label,
                    insertText: insertText,
                    kind: .snippet,
                    detail: description,
                    priority: 80,
                    snippetSupport: true
                )
            }
    }
    
    private func createListCompletions(filter: String) -> [CompletionItemModel] {
        let listTypes = [
            ("- ", "- ${1:item}", "Bullet list item"),
            ("+ ", "+ ${1:item}", "Bullet list item"),
            ("* ", "* ${1:item}", "Bullet list item"),
            ("1. ", "1. ${1:item}", "Numbered list item"),
            ("- [ ] ", "- [ ] ${1:task}", "Unchecked task"),
            ("- [x] ", "- [x] ${1:completed task}", "Checked task")
        ]
        
        return listTypes
            .filter { label, _, _ in
                filter.isEmpty || label.localizedCaseInsensitiveContains(filter)
            }
            .map { label, insertText, description in
                CompletionItemModel(
                    label: label.trimmingCharacters(in: .whitespaces),
                    insertText: insertText,
                    kind: .snippet,
                    detail: description,
                    priority: 80,
                    snippetSupport: true
                )
            }
    }
    
    private func createTableCompletions(filter _: String) -> [CompletionItemModel] {
        [
            CompletionItemModel(
                label: "| table |",
                insertText: "| ${1:Header} | ${2:Header} |\n|----------|----------|\n| ${3:Cell}   | ${4:Cell}   |",
                kind: .snippet,
                detail: "Table",
                priority: 85,
                snippetSupport: true
            ),
            CompletionItemModel(
                label: "|---|",
                insertText: "|${1:----------|----------|----------|",
                kind: .snippet,
                detail: "Table separator",
                priority: 80,
                snippetSupport: true
            )
        ]
    }
    
    private func createCodeBlockCompletions(filter: String) -> [CompletionItemModel] {
        let languages = [
            "javascript", "typescript", "python", "java", "swift", "rust", "go",
            "c", "cpp", "csharp", "php", "ruby", "kotlin", "scala", "dart",
            "html", "css", "scss", "less", "json", "xml", "yaml", "toml",
            "sql", "bash", "shell", "powershell", "dockerfile", "makefile",
            "markdown", "tex", "latex", "r", "matlab", "perl", "lua",
            "haskell", "elm", "clojure", "erlang", "elixir", "fsharp",
            "objective-c", "assembly", "fortran", "cobol", "ada"
        ]
        
        return languages
            .filter { language in
                filter.isEmpty || language.localizedCaseInsensitiveContains(filter)
            }
            .map { language in
                CompletionItemModel(
                    label: language,
                    insertText: "\(language)\n${1:code}\n```",
                    kind: .snippet,
                    detail: "Code block",
                    priority: 85,
                    snippetSupport: true
                )
            }
    }
    
    private func createHtmlTagCompletions(filter: String) -> [CompletionItemModel] {
        htmlTags
            .filter { tag in
                filter.isEmpty || tag.localizedCaseInsensitiveContains(filter)
            }
            .map { tag in
                let insertText: String
                let selfClosing = ["br", "hr", "img", "input", "meta", "link", "area", "base", "col", "embed", "source", "track", "wbr"]
                
                if selfClosing.contains(tag) {
                    insertText = "\(tag)$0 />"
                } else {
                    insertText = "\(tag)$0>\n${1:content}\n</\(tag)>"
                }
                
                return CompletionItemModel(
                    label: tag,
                    insertText: insertText,
                    kind: .property,
                    detail: "HTML tag",
                    priority: 75,
                    snippetSupport: true
                )
            }
    }
    
    private func createHtmlAttributeCompletions(for _: String?, filter: String) -> [CompletionItemModel] {
        htmlAttributes
            .filter { attribute in
                filter.isEmpty || attribute.localizedCaseInsensitiveContains(filter)
            }
            .map { attribute in
                let insertText = "\(attribute)=\"${1:value}\""
                
                return CompletionItemModel(
                    label: attribute,
                    insertText: insertText,
                    kind: .property,
                    detail: "HTML attribute",
                    priority: 70,
                    snippetSupport: true
                )
            }
    }
    
    private func createEmojiCompletions(filter: String) -> [CompletionItemModel] {
        emojiShortcuts
            .filter { emoji in
                let filterToUse = filter.hasPrefix(":") ? filter : ":\(filter)"
                return emoji.localizedCaseInsensitiveContains(filterToUse)
            }
            .map { emoji in
                CompletionItemModel(
                    label: emoji,
                    insertText: emoji,
                    kind: .constant,
                    detail: "Emoji",
                    priority: 70
                )
            }
    }
    
    private func createMathCompletions(filter: String) -> [CompletionItemModel] {
        mathSymbols
            .filter { symbol in
                filter.isEmpty || symbol.localizedCaseInsensitiveContains(filter)
            }
            .map { symbol in
                CompletionItemModel(
                    label: symbol,
                    insertText: symbol,
                    kind: .constant,
                    detail: "LaTeX symbol",
                    priority: 75
                )
            }
    }
    
    private func createSyntaxCompletions(filter: String) -> [CompletionItemModel] {
        markdownSyntax
            .filter { syntax in
                filter.isEmpty || syntax.localizedCaseInsensitiveContains(filter)
            }
            .map { syntax in
                CompletionItemModel(
                    label: syntax,
                    insertText: syntax,
                    kind: .snippet,
                    detail: "Markdown syntax",
                    priority: 80
                )
            }
    }
    
    private func createSnippetCompletions(filter: String) -> [CompletionItemModel] {
        snippets
            .filter { snippet in
                filter.isEmpty || snippet.label.localizedCaseInsensitiveContains(filter)
            }
            .map { snippet in
                CompletionItemModel(
                    label: snippet.label,
                    insertText: snippet.insertText,
                    kind: .snippet,
                    detail: snippet.description,
                    priority: 90,
                    snippetSupport: true
                )
            }
    }
}

// MARK: - Supporting Types

private struct MarkdownContextAnalysisResult {
    enum CompletionType {
        case heading
        case link
        case image
        case emphasis
        case list
        case table
        case codeBlock
        case htmlTag
        case htmlAttribute
        case emoji
        case math
        case general
    }
    
    let type: CompletionType
    let filter: String
    let htmlTag: String?
    
    init(type: CompletionType, filter: String, htmlTag: String? = nil) {
        self.type = type
        self.filter = filter
        self.htmlTag = htmlTag
    }
}
