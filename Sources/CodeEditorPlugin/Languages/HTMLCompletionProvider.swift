import Foundation

// MARK: - HTML Completion Provider

/// Built-in completion provider for HTML language
@MainActor
final class HTMLCompletionProvider: BaseCompletionProvider {
    // HTML5 elements
    private let elements = [
        // Document metadata
        "html", "head", "title", "base", "link", "meta", "style",
        // Content sectioning
        "body", "article", "section", "nav", "aside", "h1", "h2", "h3", "h4", "h5", "h6",
        "hgroup", "header", "footer", "address",
        // Text content
        "p", "hr", "pre", "blockquote", "ol", "ul", "li", "dl", "dt", "dd",
        "figure", "figcaption", "main", "div",
        // Inline text
        "a", "em", "strong", "small", "s", "cite", "q", "dfn", "abbr", "ruby", "rt", "rp",
        "data", "time", "code", "var", "samp", "kbd", "sub", "sup", "i", "b", "u", "mark",
        "bdi", "bdo", "span", "br", "wbr",
        // Image and multimedia
        "img", "iframe", "embed", "object", "param", "video", "audio", "source", "track",
        "map", "area", "svg", "canvas",
        // Embedded content
        "math", "picture",
        // Scripting
        "script", "noscript", "template", "slot",
        // Demarcating edits
        "ins", "del",
        // Table content
        "table", "caption", "colgroup", "col", "tbody", "thead", "tfoot", "tr", "td", "th",
        // Forms
        "form", "label", "input", "button", "select", "datalist", "optgroup", "option",
        "textarea", "output", "progress", "meter", "fieldset", "legend",
        // Interactive elements
        "details", "summary", "dialog", "menu",
        // Web Components
        "slot", "template"
    ]

    // Common attributes
    private let globalAttributes = [
        "id", "class", "style", "title", "lang", "dir", "tabindex", "accesskey",
        "contenteditable", "spellcheck", "draggable", "hidden", "translate",
        "data-", "aria-", "role", "itemscope", "itemprop", "itemref", "itemtype"
    ]

    // Element-specific attributes
    private let elementAttributes: [String: [String]] = [
        "a": ["href", "target", "rel", "download", "ping", "type"],
        "img": ["src", "alt", "width", "height", "loading", "decoding", "sizes", "srcset"],
        "input": ["type", "name", "value", "placeholder", "required", "disabled", "readonly", "checked", "min", "max", "step", "pattern"],
        "form": ["action", "method", "enctype", "target", "novalidate"],
        "button": ["type", "name", "value", "disabled", "form"],
        "link": ["href", "rel", "type", "media", "sizes", "as", "crossorigin"],
        "meta": ["name", "content", "charset", "http-equiv"],
        "script": ["src", "type", "async", "defer", "crossorigin", "integrity", "referrerpolicy"],
        "style": ["type", "media"],
        "video": ["src", "controls", "autoplay", "loop", "muted", "poster", "preload", "width", "height"],
        "audio": ["src", "controls", "autoplay", "loop", "muted", "preload"],
        "iframe": ["src", "width", "height", "loading", "sandbox", "allow", "allowfullscreen"]
    ]

    // HTML entities
    private let entities = [
        "&lt;", "&gt;", "&amp;", "&quot;", "&apos;", "&nbsp;", "&copy;", "&reg;",
        "&trade;", "&euro;", "&pound;", "&yen;", "&cent;", "&deg;", "&plusmn;",
        "&micro;", "&para;", "&sect;", "&divide;", "&times;", "&not;", "&shy;",
        "&mdash;", "&ndash;", "&hellip;", "&laquo;", "&raquo;", "&ldquo;", "&rdquo;"
    ]

    override var snippets: [SnippetTemplate] {
        [
            SnippetTemplate(
                label: "html5",
                insertText: """
<!DOCTYPE html>
<html lang="${1:en}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${2:Document}</title>
</head>
<body>
    ${3:<!-- content -->}
</body>
</html>
""",
                description: "HTML5 boilerplate"
            ),
            SnippetTemplate(
                label: "link-css",
                insertText: "<link rel=\"stylesheet\" href=\"${1:style.css}\">",
                description: "Link to CSS file"
            ),
            SnippetTemplate(
                label: "script",
                insertText: "<script src=\"${1:script.js}\"></script>",
                description: "Script tag"
            ),
            SnippetTemplate(
                label: "img",
                insertText: "<img src=\"${1:image.jpg}\" alt=\"${2:description}\" width=\"${3:}\" height=\"${4:}\">",
                description: "Image tag"
            ),
            SnippetTemplate(
                label: "a",
                insertText: "<a href=\"${1:url}\">${2:link text}</a>",
                description: "Anchor link"
            ),
            SnippetTemplate(
                label: "form",
                insertText: """
<form action="${1:/submit}" method="${2:post}">
    ${3:<!-- form fields -->}
    <button type="submit">${4:Submit}</button>
</form>
""",
                description: "Form structure"
            ),
            SnippetTemplate(
                label: "input",
                insertText: "<input type=\"${1:text}\" name=\"${2:name}\" placeholder=\"${3:placeholder}\" ${4:required}>",
                description: "Input field"
            ),
            SnippetTemplate(
                label: "nav",
                insertText: """
<nav>
    <ul>
        <li><a href="${1:#}">${2:Home}</a></li>
        <li><a href="${3:#}">${4:About}</a></li>
        <li><a href="${5:#}">${6:Contact}</a></li>
    </ul>
</nav>
""",
                description: "Navigation menu"
            ),
            SnippetTemplate(
                label: "article",
                insertText: """
<article>
    <header>
        <h2>${1:Title}</h2>
        <time datetime="${2:2024-01-01}">${3:January 1, 2024}</time>
    </header>
    <p>${4:Content}</p>
</article>
""",
                description: "Article structure"
            ),
            SnippetTemplate(
                label: "table",
                insertText: """
<table>
    <thead>
        <tr>
            <th>${1:Header 1}</th>
            <th>${2:Header 2}</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>${3:Data 1}</td>
            <td>${4:Data 2}</td>
        </tr>
    </tbody>
</table>
""",
                description: "Table structure"
            ),
            SnippetTemplate(
                label: "meta-viewport",
                insertText: "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">",
                description: "Viewport meta tag"
            ),
            SnippetTemplate(
                label: "comment",
                insertText: "<!-- ${1:comment} -->",
                description: "HTML comment"
            )
        ]
    }

    init() {
        super.init(
            id: "html-builtin",
            supportedLanguages: [.html],
            triggerCharacters: ["<", ">", " ", "\"", "=", "/", "&"],
            supportsSnippets: true
        )
    }

    // MARK: - Overrides for HTML-specific completion

    override func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()

        // Analyze context to determine what kind of completions to provide
        let analysisResult = analyzeHTMLContext(context)
        var items: [CompletionItemModel] = []

        // Add appropriate completions based on context
        switch analysisResult.type {
        case .tag:
            items.append(contentsOf: createTagCompletions(filter: analysisResult.filter))

        case .attribute:
            items.append(contentsOf: createAttributeCompletions(for: analysisResult.targetTag, filter: analysisResult.filter))

        case .attributeValue:
            items.append(contentsOf: createAttributeValueCompletions(for: analysisResult.targetTag, attribute: analysisResult.targetAttribute, filter: analysisResult.filter))

        case .entity:
            items.append(contentsOf: createEntityCompletions(filter: analysisResult.filter))

        case .closeTag:
            if let tagToClose = analysisResult.targetTag {
                items.append(createCloseTagCompletion(for: tagToClose))
            }

        case .general:
            items.append(contentsOf: createTagCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createEntityCompletions(filter: analysisResult.filter))
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

    override func extractCurrentWord(from text: String) -> String {
        if text.hasSuffix("&") {
            return "&"
        }

        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-&")).inverted)
        return components.last ?? ""
    }

    // MARK: - Context Analysis

    private func analyzeHTMLContext(_ context: CompletionContextModel) -> HTMLContextAnalysisResult {
        let beforeCursor = context.textBeforeCursor
        // let afterCursor = String(context.text.suffix(from: context.text.index(context.text.startIndex, offsetBy: context.cursorPosition)))

        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)

        // Check for entity context
        if beforeCursor.hasSuffix("&") || (filter.hasPrefix("&") && !filter.hasSuffix(";")) {
            return HTMLContextAnalysisResult(type: .entity, filter: filter)
        }

        // Check for closing tag
        if beforeCursor.hasSuffix("</") {
            let openTag = findUnclosedTag(in: beforeCursor)
            return HTMLContextAnalysisResult(type: .closeTag, filter: filter, targetTag: openTag)
        }

        // Check for opening tag
        if beforeCursor.hasSuffix("<") || (beforeCursor.contains("<") && !beforeCursor.contains(">") && isInTag(beforeCursor)) {
            return HTMLContextAnalysisResult(type: .tag, filter: filter)
        }

        // Check for attribute context
        if let tagContext = getCurrentTagContext(from: beforeCursor) {
            // Check if we're in attribute value
            if let attrContext = getCurrentAttributeContext(from: beforeCursor) {
                if beforeCursor.hasSuffix("=\"") || beforeCursor.hasSuffix("='") {
                    return HTMLContextAnalysisResult(type: .attributeValue, filter: "", targetTag: tagContext, targetAttribute: attrContext)
                }
            } else if beforeCursor.hasSuffix(" ") || isInAttributePosition(beforeCursor) {
                return HTMLContextAnalysisResult(type: .attribute, filter: filter, targetTag: tagContext)
            }
        }

        return HTMLContextAnalysisResult(type: .general, filter: filter)
    }

    private func getCurrentTagContext(from text: String) -> String? {
        // Find the most recent unclosed tag
        let pattern = #"<(\w+)(?:\s+[^>]*)?$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }

    private func getCurrentAttributeContext(from text: String) -> String? {
        // Find the current attribute being edited
        let pattern = #"(\w+)\s*=\s*[\"']?[^\"']*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }

    private func findUnclosedTag(in text: String) -> String? {
        // Simple approach: find the most recent opening tag without a closing tag
        var tagStack: [String] = []
        let tagPattern = #"<(/)?(\w+)[^>]*>"#

        if let regex = try? NSRegularExpression(pattern: tagPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

            for match in matches {
                if let closeRange = Range(match.range(at: 1), in: text),
                   let tagRange = Range(match.range(at: 2), in: text) {
                    let tag = String(text[tagRange])
                    if text[closeRange] == "/" {
                        // Closing tag
                        if let lastIndex = tagStack.lastIndex(of: tag) {
                            tagStack.remove(at: lastIndex)
                        }
                    } else {
                        // Opening tag - check if it's not self-closing
                        if let fullRange = Range(match.range, in: text) {
                            let fullMatch = String(text[fullRange])
                            if !fullMatch.hasSuffix("/>") && !["br", "hr", "img", "input", "meta", "link", "area", "base", "col", "embed", "source", "track", "wbr"].contains(tag) {
                                tagStack.append(tag)
                            }
                        }
                    }
                }
            }
        }

        return tagStack.last
    }

    private func isInTag(_ text: String) -> Bool {
        let lastOpenBracket = text.lastIndex(of: "<") ?? text.startIndex
        let lastCloseBracket = text.lastIndex(of: ">") ?? text.startIndex
        return lastOpenBracket > lastCloseBracket
    }

    private func isInAttributePosition(_ text: String) -> Bool {
        // Check if we're inside a tag and after the tag name
        guard isInTag(text) else { return false }

        let pattern = #"<\w+\s+[^>]*$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }
        return false
    }

    // MARK: - Completion Creation Methods

    private func createTagCompletions(filter: String) -> [CompletionItemModel] {
        elements
            .filter { element in
                filter.isEmpty || element.localizedCaseInsensitiveContains(filter)
            }
            .map { element in
                let isSelfClosing = ["br", "hr", "img", "input", "meta", "link", "area", "base", "col", "embed", "source", "track", "wbr"].contains(element)
                let insertText = isSelfClosing ? "\(element) $0/>" : "\(element)>$0</\(element)>"

                return CompletionItemModel(
                    label: element,
                    insertText: insertText,
                    kind: .property,
                    detail: "HTML element",
                    priority: 80,
                    preselect: element == filter
                )
            }
    }

    private func createAttributeCompletions(for tag: String?, filter: String) -> [CompletionItemModel] {
        var attributes = globalAttributes

        if let tag, let tagSpecificAttrs = elementAttributes[tag] {
            attributes += tagSpecificAttrs
        }

        return attributes
            .filter { attribute in
                filter.isEmpty || attribute.localizedCaseInsensitiveContains(filter)
            }
            .map { attribute in
                let insertText = attribute.hasSuffix("-") ? "\(attribute)$0" : "\(attribute)=\"$0\""

                return CompletionItemModel(
                    label: attribute,
                    insertText: insertText,
                    kind: .property,
                    detail: "HTML attribute",
                    priority: 75
                )
            }
    }

    private func createAttributeValueCompletions(for tag: String?, attribute: String?, filter: String) -> [CompletionItemModel] {
        guard let tag, let attribute else { return [] }

        var values: [String] = []

        // Provide common values based on attribute
        switch attribute {
        case "type" where tag == "input":
            values = ["text", "password", "email", "number", "tel", "url", "date", "time", "datetime-local", "month", "week", "color", "checkbox", "radio", "file", "submit", "reset", "button", "hidden", "search", "range"]

        case "method" where tag == "form":
            values = ["get", "post", "dialog"]

        case "target":
            values = ["_blank", "_self", "_parent", "_top"]

        case "rel" where tag == "a" || tag == "link":
            values = ["noopener", "noreferrer", "nofollow", "stylesheet", "icon", "preconnect", "dns-prefetch", "preload", "prefetch"]

        case "loading" where tag == "img" || tag == "iframe":
            values = ["lazy", "eager"]

        case "decoding" where tag == "img":
            values = ["async", "sync", "auto"]

        case "autocomplete":
            values = ["on", "off", "name", "email", "username", "current-password", "new-password", "one-time-code"]

        case "inputmode":
            values = ["none", "text", "decimal", "numeric", "tel", "search", "email", "url"]

        default:
            break
        }

        return values
            .filter { value in
                filter.isEmpty || value.localizedCaseInsensitiveContains(filter)
            }
            .map { value in
                CompletionItemModel(
                    label: value,
                    insertText: value,
                    kind: .value,
                    detail: "Attribute value",
                    priority: 85
                )
            }
    }

    private func createEntityCompletions(filter: String) -> [CompletionItemModel] {
        entities
            .filter { entity in
                let filterToUse = filter.hasPrefix("&") ? filter : "&\(filter)"
                return entity.localizedCaseInsensitiveContains(filterToUse)
            }
            .map { entity in
                CompletionItemModel(
                    label: entity,
                    insertText: entity,
                    kind: .constant,
                    detail: "HTML entity",
                    priority: 70
                )
            }
    }

    private func createCloseTagCompletion(for tag: String) -> CompletionItemModel {
        CompletionItemModel(
            label: tag,
            insertText: "\(tag)>",
            kind: .property,
            detail: "Close tag",
            priority: 95,
            preselect: true
        )
    }
}

// MARK: - Supporting Types

private struct HTMLContextAnalysisResult {
    enum CompletionType {
        case tag
        case attribute
        case attributeValue
        case entity
        case closeTag
        case general
    }

    let type: CompletionType
    let filter: String
    let targetTag: String?
    let targetAttribute: String?

    init(type: CompletionType, filter: String, targetTag: String? = nil, targetAttribute: String? = nil) {
        self.type = type
        self.filter = filter
        self.targetTag = targetTag
        self.targetAttribute = targetAttribute
    }
}
