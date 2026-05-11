import Foundation

// MARK: - XML Completion Provider

/// Built-in completion provider for XML language
@MainActor
final class XMLCompletionProvider: BaseCompletionProvider {
    // Common XML elements
    private let commonElements = [
        "xml", "element", "attribute", "text", "cdata", "comment", "processing-instruction",
        "document", "schema", "complexType", "simpleType", "sequence", "choice", "all",
        "element", "attribute", "restriction", "extension", "enumeration", "pattern",
        "minInclusive", "maxInclusive", "minExclusive", "maxExclusive", "length",
        "minLength", "maxLength", "totalDigits", "fractionDigits"
    ]

    // XML Schema elements
    private let schemaElements = [
        "schema", "element", "attribute", "complexType", "simpleType", "sequence",
        "choice", "all", "group", "attributeGroup", "complexContent", "simpleContent",
        "restriction", "extension", "enumeration", "pattern", "whiteSpace", "length",
        "minLength", "maxLength", "minInclusive", "maxInclusive", "minExclusive",
        "maxExclusive", "totalDigits", "fractionDigits", "annotation", "documentation",
        "appinfo", "import", "include", "redefine", "notation", "any", "anyAttribute",
        "unique", "key", "keyref", "selector", "field"
    ]

    // Common XML attributes
    private let commonAttributes = [
        "id", "name", "type", "ref", "use", "default", "fixed", "form", "minOccurs",
        "maxOccurs", "nillable", "abstract", "block", "final", "substitutionGroup",
        "elementFormDefault", "attributeFormDefault", "targetNamespace", "xmlns",
        "xmlns:xsi", "xsi:schemaLocation", "xsi:noNamespaceSchemaLocation", "version",
        "encoding", "standalone", "xml:lang", "xml:space", "xml:base"
    ]

    // XML namespaces
    private let namespaces = [
        ("xmlns", "http://www.w3.org/2000/xmlns/"),
        ("xsi", "http://www.w3.org/2001/XMLSchema-instance"),
        ("xs", "http://www.w3.org/2001/XMLSchema"),
        ("xsl", "http://www.w3.org/1999/XSL/Transform"),
        ("soap", "http://schemas.xmlsoap.org/soap/envelope/"),
        ("wsdl", "http://schemas.xmlsoap.org/wsdl/"),
        ("svg", "http://www.w3.org/2000/svg"),
        ("xhtml", "http://www.w3.org/1999/xhtml"),
        ("rdf", "http://www.w3.org/1999/02/22-rdf-syntax-ns#"),
        ("atom", "http://www.w3.org/2005/Atom")
    ]

    // XML entities
    private let entities = [
        "&lt;", "&gt;", "&amp;", "&quot;", "&apos;", "&#160;", "&#169;", "&#174;",
        "&#8482;", "&#8364;", "&#163;", "&#165;", "&#162;", "&#176;", "&#177;",
        "&#181;", "&#182;", "&#167;", "&#247;", "&#215;", "&#172;", "&#173;"
    ]

    // XML Schema types
    private let schemaTypes = [
        "string", "boolean", "decimal", "float", "double", "duration", "dateTime",
        "time", "date", "gYearMonth", "gYear", "gMonthDay", "gDay", "gMonth",
        "hexBinary", "base64Binary", "anyURI", "QName", "NOTATION", "normalizedString",
        "token", "language", "NMTOKEN", "NMTOKENS", "Name", "NCName", "ID", "IDREF",
        "IDREFS", "ENTITY", "ENTITIES", "integer", "nonPositiveInteger", "negativeInteger",
        "long", "int", "short", "byte", "nonNegativeInteger", "unsignedLong",
        "unsignedInt", "unsignedShort", "unsignedByte", "positiveInteger"
    ]

    // SVG specific elements (for SVG files)
    private let svgElements = [
        "svg", "g", "rect", "circle", "ellipse", "line", "polyline", "polygon",
        "path", "text", "tspan", "tref", "textPath", "altGlyph", "altGlyphDef",
        "altGlyphItem", "glyphRef", "marker", "clipPath", "mask", "linearGradient",
        "radialGradient", "stop", "pattern", "image", "switch", "use", "symbol",
        "defs", "title", "desc", "metadata", "script", "style", "animate",
        "animateMotion", "animateTransform", "animateColor", "set", "mpath"
    ]

    // MARK: - Overrides

    override var snippets: [SnippetTemplate] {
        [
        SnippetTemplate(
            label: "xml-declaration",
            insertText: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            description: "XML declaration"
        ),
        SnippetTemplate(
            label: "element",
            insertText: "<${1:element}>${2:content}</${1:element}>",
            description: "XML element"
        ),
        SnippetTemplate(
            label: "empty-element",
            insertText: "<${1:element} ${2:attribute}=\"${3:value}\" />",
            description: "Empty XML element"
        ),
        SnippetTemplate(
            label: "comment",
            insertText: "<!-- ${1:comment} -->",
            description: "XML comment"
        ),
        SnippetTemplate(
            label: "cdata",
            insertText: "<![CDATA[${1:content}]]>",
            description: "CDATA section"
        ),
        SnippetTemplate(
            label: "schema",
            insertText: """
<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
           targetNamespace="${1:http://example.com/schema}"
           xmlns="${1:http://example.com/schema}"
           elementFormDefault="qualified">

    <xs:element name="${2:root}">
        <xs:complexType>
            <xs:sequence>
                ${3:<!-- elements -->}
            </xs:sequence>
        </xs:complexType>
    </xs:element>

</xs:schema>
""",
            description: "XML Schema template"
        ),
        SnippetTemplate(
            label: "complex-type",
            insertText: """
<xs:complexType name="${1:TypeName}">
    <xs:sequence>
        <xs:element name="${2:element}" type="${3:xs:string}" />
    </xs:sequence>
</xs:complexType>
""",
            description: "Complex type definition"
        ),
        SnippetTemplate(
            label: "simple-type",
            insertText: """
<xs:simpleType name="${1:TypeName}">
    <xs:restriction base="${2:xs:string}">
        ${3:<!-- restrictions -->}
    </xs:restriction>
</xs:simpleType>
""",
            description: "Simple type definition"
        ),
        SnippetTemplate(
            label: "xslt-template",
            insertText: """
<xsl:template match="${1:pattern}">
    ${2:<!-- template content -->}
</xsl:template>
""",
            description: "XSLT template"
        ),
        SnippetTemplate(
            label: "svg",
            insertText: """
<svg xmlns="http://www.w3.org/2000/svg" width="${1:100}" height="${2:100}" viewBox="0 0 ${1:100} ${2:100}">
    ${3:<!-- SVG content -->}
</svg>
""",
            description: "SVG root element"
        )
        ]
    }

    // MARK: - Initialization

    init() {
        super.init(
            id: "xml-builtin",
            supportedLanguages: [.xml],
            triggerCharacters: ["<", ">", " ", "\"", "=", "/", "&", ":", "!"],
            supportsSnippets: true
        )
    }

    // MARK: - Overridden Methods

    override func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()

        // Analyze context to determine what kind of completions to provide
        let analysisResult = analyzeXMLContext(context)
        var items: [CompletionItemModel] = []

        // Add appropriate completions based on context
        switch analysisResult.type {
        case .tag:
            items.append(contentsOf: createTagCompletions(for: analysisResult.fileType, filter: analysisResult.filter))

        case .attribute:
            items.append(contentsOf: createAttributeCompletions(for: analysisResult.targetTag, fileType: analysisResult.fileType, filter: analysisResult.filter))

        case .attributeValue:
            items.append(contentsOf: createAttributeValueCompletions(for: analysisResult.targetTag, attribute: analysisResult.targetAttribute, fileType: analysisResult.fileType, filter: analysisResult.filter))

        case .entity:
            items.append(contentsOf: createEntityCompletions(filter: analysisResult.filter))

        case .closeTag:
            if let tagToClose = analysisResult.targetTag {
                items.append(createCloseTagCompletion(for: tagToClose))
            }

        case .namespace:
            items.append(contentsOf: createNamespaceCompletions(filter: analysisResult.filter))

        case .declaration:
            items.append(contentsOf: createDeclarationCompletions(filter: analysisResult.filter))

        case .general:
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

        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-:&")).inverted)
        return components.last ?? ""
    }

    // MARK: - Context Analysis

    private func analyzeXMLContext(_ context: CompletionContextModel) -> XMLContextAnalysisResult {
        let beforeCursor = context.textBeforeCursor
        let fileType = detectFileType(from: context.text)

        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)

        // Check for declaration context (<?xml or <!)
        if beforeCursor.hasSuffix("<?") || beforeCursor.hasSuffix("<!") {
            return XMLContextAnalysisResult(type: .declaration, filter: filter, fileType: fileType)
        }

        // Check for entity context
        if beforeCursor.hasSuffix("&") || (filter.hasPrefix("&") && !filter.hasSuffix(";")) {
            return XMLContextAnalysisResult(type: .entity, filter: filter, fileType: fileType)
        }

        // Check for namespace context
        if beforeCursor.hasSuffix("xmlns:") || beforeCursor.hasSuffix("xmlns=") {
            return XMLContextAnalysisResult(type: .namespace, filter: filter, fileType: fileType)
        }

        // Check for closing tag
        if beforeCursor.hasSuffix("</") {
            let openTag = findUnclosedTag(in: beforeCursor)
            return XMLContextAnalysisResult(type: .closeTag, filter: filter, fileType: fileType, targetTag: openTag)
        }

        // Check for opening tag
        if beforeCursor.hasSuffix("<") || (beforeCursor.contains("<") && !beforeCursor.contains(">") && isInTag(beforeCursor)) {
            return XMLContextAnalysisResult(type: .tag, filter: filter, fileType: fileType)
        }

        // Check for attribute context
        if let tagContext = getCurrentTagContext(from: beforeCursor) {
            // Check if we're in attribute value
            if let attrContext = getCurrentAttributeContext(from: beforeCursor) {
                if beforeCursor.hasSuffix("=\"") || beforeCursor.hasSuffix("='") {
                    return XMLContextAnalysisResult(type: .attributeValue, filter: "", fileType: fileType, targetTag: tagContext, targetAttribute: attrContext)
                }
            } else if beforeCursor.hasSuffix(" ") || isInAttributePosition(beforeCursor) {
                return XMLContextAnalysisResult(type: .attribute, filter: filter, fileType: fileType, targetTag: tagContext)
            }
        }

        return XMLContextAnalysisResult(type: .general, filter: filter, fileType: fileType)
    }

    private func detectFileType(from text: String) -> XMLFileType {
        // Check for XML Schema
        if text.contains("xmlns:xs=\"http://www.w3.org/2001/XMLSchema\"") || text.contains("<xs:schema") {
            return .schema
        }

        // Check for XSLT
        if text.contains("xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\"") || text.contains("<xsl:stylesheet") {
            return .xslt
        }

        // Check for SVG
        if text.contains("xmlns=\"http://www.w3.org/2000/svg\"") || text.contains("<svg") {
            return .svg
        }

        // Check for SOAP
        if text.contains("soap:Envelope") || text.contains("xmlns:soap=") {
            return .soap
        }

        // Check for RSS/Atom
        if text.contains("<rss") || text.contains("<feed") || text.contains("<atom:feed") {
            return .feed
        }

        return .generic
    }

    private func getCurrentTagContext(from text: String) -> String? {
        // Find the most recent unclosed tag
        let pattern = #"<(\w+(?::\w+)?)\s*[^>]*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }

    private func getCurrentAttributeContext(from text: String) -> String? {
        // Find the current attribute being edited
        let pattern = #"(\w+(?::\w+)?)\s*=\s*[\"']?[^\"']*$"#
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
        let tagPattern = #"<(/)?(\w+(?::\w+)?)[^>]*>"#

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
                            if !fullMatch.hasSuffix("/>") {
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

        let pattern = #"<\w+(?::\w+)?\s+[^>]*$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }
        return false
    }

    // MARK: - Completion Creation Methods

    private func createTagCompletions(for fileType: XMLFileType, filter: String) -> [CompletionItemModel] {
        var elements: [String] = []

        switch fileType {
        case .schema:
            elements = schemaElements

        case .svg:
            elements = svgElements

        case .xslt:
            elements = ["template", "apply-templates", "value-of", "for-each", "if", "choose", "when", "otherwise", "copy", "copy-of", "variable", "param", "with-param", "call-template", "import", "include", "output", "sort", "key"]

        case .soap:
            elements = ["Envelope", "Header", "Body", "Fault", "faultcode", "faultstring", "faultactor", "detail"]

        case .feed:
            elements = ["rss", "channel", "title", "link", "description", "item", "pubDate", "guid", "category", "feed", "entry", "author", "content", "summary", "published", "updated"]

        case .generic:
            elements = commonElements
        }

        return elements
            .filter { element in
                filter.isEmpty || element.localizedCaseInsensitiveContains(filter)
            }
            .map { element in
                let insertText = element.contains(" ") ? element : "\(element)>$0</\(element)>"

                return CompletionItemModel(
                    label: element,
                    insertText: insertText,
                    kind: .property,
                    detail: "XML element",
                    priority: 80,
                    preselect: element == filter
                )
            }
    }

    private func createAttributeCompletions(for _: String?, fileType: XMLFileType, filter: String) -> [CompletionItemModel] {
        var attributes = commonAttributes

        // Add namespace-specific attributes for schema files
        if fileType == .schema {
            attributes.append(contentsOf: ["base", "itemType", "memberTypes", "mixed", "processContents", "namespace", "schemaLocation", "public", "system"])
        }

        return attributes
            .filter { attribute in
                filter.isEmpty || attribute.localizedCaseInsensitiveContains(filter)
            }
            .map { attribute in
                let insertText = "\(attribute)=\"$0\""

                return CompletionItemModel(
                    label: attribute,
                    insertText: insertText,
                    kind: .property,
                    detail: "XML attribute",
                    priority: 75
                )
            }
    }

    private func createAttributeValueCompletions(for _: String?, attribute: String?, fileType: XMLFileType, filter: String) -> [CompletionItemModel] {
        guard let attribute else { return [] }

        var values: [String] = []

        // Provide common values based on attribute
        switch attribute {
        case "type" where fileType == .schema:
            values = schemaTypes

        case "use":
            values = ["required", "optional", "prohibited"]

        case "processContents":
            values = ["strict", "lax", "skip"]

        case "block", "final":
            values = ["restriction", "extension", "substitution", "#all"]

        case "form":
            values = ["qualified", "unqualified"]

        case "maxOccurs":
            values = ["unbounded", "0", "1"]

        case "minOccurs":
            values = ["0", "1"]

        case "standalone":
            values = ["yes", "no"]

        case "xml:space":
            values = ["preserve", "default"]

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
                    detail: "XML entity",
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

    private func createNamespaceCompletions(filter: String) -> [CompletionItemModel] {
        namespaces
            .filter { prefix, _ in
                filter.isEmpty || prefix.localizedCaseInsensitiveContains(filter)
            }
            .map { prefix, uri in
                CompletionItemModel(
                    label: "\(prefix) - \(uri)",
                    insertText: "\"\(uri)\"",
                    kind: .module,
                    detail: "XML namespace",
                    priority: 75
                )
            }
    }

    private func createDeclarationCompletions(filter: String) -> [CompletionItemModel] {
        var items: [CompletionItemModel] = []

        // XML declaration
        if filter.isEmpty || "xml".localizedCaseInsensitiveContains(filter) {
            items.append(CompletionItemModel(
                label: "xml version",
                insertText: "xml version=\"1.0\" encoding=\"UTF-8\"?>",
                kind: .snippet,
                detail: "XML declaration",
                priority: 90
            ))
        }

        // DOCTYPE
        if filter.isEmpty || "DOCTYPE".localizedCaseInsensitiveContains(filter) {
            items.append(CompletionItemModel(
                label: "DOCTYPE",
                insertText: "DOCTYPE ${1:root} SYSTEM \"${2:dtd}\">",
                kind: .snippet,
                detail: "Document type declaration",
                priority: 85
            ))
        }

        // CDATA
        if filter.isEmpty || "CDATA".localizedCaseInsensitiveContains(filter) {
            items.append(CompletionItemModel(
                label: "[CDATA[",
                insertText: "[CDATA[$0]]>",
                kind: .snippet,
                detail: "CDATA section",
                priority: 85
            ))
        }

        return items
    }
}

// MARK: - Supporting Types

private struct XMLContextAnalysisResult {
    enum CompletionType {
        case tag
        case attribute
        case attributeValue
        case entity
        case closeTag
        case namespace
        case declaration
        case general
    }

    let type: CompletionType
    let filter: String
    let fileType: XMLFileType
    let targetTag: String?
    let targetAttribute: String?

    init(type: CompletionType, filter: String, fileType: XMLFileType, targetTag: String? = nil, targetAttribute: String? = nil) {
        self.type = type
        self.filter = filter
        self.fileType = fileType
        self.targetTag = targetTag
        self.targetAttribute = targetAttribute
    }
}

private enum XMLFileType {
    case schema
    case xslt
    case svg
    case soap
    case feed
    case generic
}
