import Foundation

// MARK: - Markdown Completion Provider

/// Built-in completion provider for Markdown language
@MainActor
final class MarkdownCompletionProvider: BaseCompletionProvider {
    // Reference to static data from MarkdownCompletionData
    private let markdownSyntax = MarkdownCompletionData.markdownSyntax
    private let elements = MarkdownCompletionData.elements
    private let htmlTags = MarkdownCompletionData.htmlTags
    private let htmlAttributes = MarkdownCompletionData.htmlAttributes
    private let emojiShortcuts = MarkdownCompletionData.emojiShortcuts
    private let mathSymbols = MarkdownCompletionData.mathSymbols
    private let linkPatterns = MarkdownCompletionData.linkPatterns

    // Override snippets property
    override var snippets: [SnippetTemplate] {
        MarkdownCompletionData.snippets
    }

    init() {
        super.init(
            id: "markdown-builtin",
            supportedLanguages: [.markdown],
            triggerCharacters: ["#", "*", "_", "[", "]", "(", ")", "`", "!", "|", "-", "+", ":", "<", ">", " "],
            supportsSnippets: true
        )
    }

    // MARK: - Overrides for Markdown Completions

    override func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()

        // Analyze context to determine what kind of completions to provide
        let analysisResult = analyzeMarkdownContext(context)
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
                items.append(contentsOf: super.createSnippetCompletions(filter: analysisResult.filter))
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

    private func analyzeMarkdownContext(_ context: CompletionContextModel) -> MarkdownContextAnalysisResult {
        let lineText = context.lineText
        let beforeCursor = context.textBeforeCursor

        // Extract current word being typed
        let filter = extractMarkdownWord(from: beforeCursor)

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

    private func extractMarkdownWord(from text: String) -> String {
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
