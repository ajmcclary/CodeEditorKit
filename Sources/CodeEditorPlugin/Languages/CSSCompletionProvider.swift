import Foundation

// MARK: - CSS Completion Provider

/// Built-in completion provider for CSS language
@MainActor
public final class CSSCompletionProvider: CompletionProvider {
    public let id = "css-builtin"
    public let supportedLanguages: [Language] = [.css]
    public let triggerCharacters = [".", "#", ":", " ", "-", "(", "\"", "'"]
    public let supportsSnippets = true
    
    // CSS properties
    private let properties = [
        // Layout
        "display", "position", "top", "right", "bottom", "left", "float", "clear",
        "z-index", "overflow", "overflow-x", "overflow-y", "visibility", "opacity",
        // Box Model
        "width", "height", "max-width", "max-height", "min-width", "min-height",
        "margin", "margin-top", "margin-right", "margin-bottom", "margin-left",
        "padding", "padding-top", "padding-right", "padding-bottom", "padding-left",
        "border", "border-width", "border-style", "border-color",
        "border-top", "border-right", "border-bottom", "border-left",
        "border-radius", "border-top-left-radius", "border-top-right-radius",
        "border-bottom-left-radius", "border-bottom-right-radius",
        "box-sizing", "box-shadow",
        // Flexbox
        "flex", "flex-direction", "flex-wrap", "flex-flow", "justify-content",
        "align-items", "align-content", "align-self", "order", "flex-grow",
        "flex-shrink", "flex-basis", "gap", "row-gap", "column-gap",
        // Grid
        "grid", "grid-template", "grid-template-columns", "grid-template-rows",
        "grid-template-areas", "grid-column", "grid-row", "grid-area",
        "grid-column-start", "grid-column-end", "grid-row-start", "grid-row-end",
        "grid-auto-columns", "grid-auto-rows", "grid-auto-flow",
        "justify-items", "justify-self", "place-items", "place-content", "place-self",
        // Typography
        "font", "font-family", "font-size", "font-weight", "font-style",
        "font-variant", "font-stretch", "line-height", "letter-spacing",
        "word-spacing", "text-align", "text-decoration", "text-transform",
        "text-indent", "text-shadow", "vertical-align", "white-space",
        "word-break", "word-wrap", "text-overflow",
        // Color & Background
        "color", "background", "background-color", "background-image",
        "background-position", "background-repeat", "background-size",
        "background-attachment", "background-origin", "background-clip",
        "background-blend-mode",
        // Animation & Transition
        "animation", "animation-name", "animation-duration", "animation-timing-function",
        "animation-delay", "animation-iteration-count", "animation-direction",
        "animation-fill-mode", "animation-play-state",
        "transition", "transition-property", "transition-duration",
        "transition-timing-function", "transition-delay",
        "transform", "transform-origin", "transform-style", "perspective",
        "perspective-origin", "backface-visibility",
        // Other
        "cursor", "outline", "outline-width", "outline-style", "outline-color",
        "outline-offset", "resize", "user-select", "pointer-events",
        "list-style", "list-style-type", "list-style-position", "list-style-image",
        "content", "counter-reset", "counter-increment", "quotes",
        "filter", "backdrop-filter", "mix-blend-mode", "isolation",
        "clip", "clip-path", "mask", "mask-image", "mask-mode", "mask-position",
        "object-fit", "object-position", "will-change", "contain", "aspect-ratio"
    ]
    
    // CSS values by property type
    private let commonValues: [String: [String]] = [
        "display": ["none", "block", "inline", "inline-block", "flex", "inline-flex", "grid", "inline-grid", "table", "table-row", "table-cell", "list-item", "contents"],
        "position": ["static", "relative", "absolute", "fixed", "sticky"],
        "float": ["none", "left", "right"],
        "clear": ["none", "left", "right", "both"],
        "overflow": ["visible", "hidden", "scroll", "auto", "overlay"],
        "visibility": ["visible", "hidden", "collapse"],
        "flex-direction": ["row", "row-reverse", "column", "column-reverse"],
        "flex-wrap": ["nowrap", "wrap", "wrap-reverse"],
        "justify-content": ["flex-start", "flex-end", "center", "space-between", "space-around", "space-evenly"],
        "align-items": ["stretch", "flex-start", "flex-end", "center", "baseline"],
        "align-content": ["stretch", "flex-start", "flex-end", "center", "space-between", "space-around"],
        "font-weight": ["normal", "bold", "bolder", "lighter", "100", "200", "300", "400", "500", "600", "700", "800", "900"],
        "font-style": ["normal", "italic", "oblique"],
        "text-align": ["left", "right", "center", "justify", "start", "end"],
        "text-decoration": ["none", "underline", "overline", "line-through"],
        "text-transform": ["none", "capitalize", "uppercase", "lowercase"],
        "white-space": ["normal", "nowrap", "pre", "pre-wrap", "pre-line", "break-spaces"],
        "vertical-align": ["baseline", "top", "middle", "bottom", "text-top", "text-bottom", "sub", "super"],
        "cursor": ["auto", "default", "pointer", "move", "text", "wait", "help", "crosshair", "not-allowed", "zoom-in", "zoom-out", "grab", "grabbing"],
        "list-style-type": ["none", "disc", "circle", "square", "decimal", "decimal-leading-zero", "lower-roman", "upper-roman", "lower-alpha", "upper-alpha"],
        "box-sizing": ["content-box", "border-box"],
        "object-fit": ["fill", "contain", "cover", "none", "scale-down"],
        "background-repeat": ["repeat", "repeat-x", "repeat-y", "no-repeat", "space", "round"],
        "background-attachment": ["scroll", "fixed", "local"],
        "background-size": ["auto", "cover", "contain"]
    ]
    
    // CSS pseudo-classes
    private let pseudoClasses = [
        "hover", "active", "focus", "visited", "link", "disabled", "enabled",
        "checked", "empty", "first-child", "last-child", "nth-child",
        "nth-last-child", "only-child", "first-of-type", "last-of-type",
        "nth-of-type", "nth-last-of-type", "only-of-type", "target", "root",
        "not", "lang", "focus-visible", "focus-within", "required", "optional",
        "valid", "invalid", "in-range", "out-of-range", "read-only", "read-write",
        "placeholder-shown", "default", "checked", "indeterminate"
    ]
    
    // CSS pseudo-elements
    private let pseudoElements = [
        "before", "after", "first-line", "first-letter", "selection",
        "backdrop", "placeholder", "marker", "cue", "grammar-error", "spelling-error"
    ]
    
    // CSS functions
    private let functions = [
        "rgb", "rgba", "hsl", "hsla", "hwb", "lab", "lch", "oklab", "oklch",
        "color", "color-mix", "linear-gradient", "radial-gradient", "conic-gradient",
        "repeating-linear-gradient", "repeating-radial-gradient", "repeating-conic-gradient",
        "url", "var", "calc", "min", "max", "clamp", "attr", "counter", "counters",
        "cubic-bezier", "steps", "path", "polygon", "circle", "ellipse", "inset",
        "matrix", "matrix3d", "translate", "translateX", "translateY", "translateZ",
        "translate3d", "scale", "scaleX", "scaleY", "scaleZ", "scale3d",
        "rotate", "rotateX", "rotateY", "rotateZ", "rotate3d", "skew", "skewX", "skewY",
        "perspective", "blur", "brightness", "contrast", "drop-shadow", "grayscale",
        "hue-rotate", "invert", "opacity", "saturate", "sepia"
    ]
    
    // CSS units
    private let units = [
        "px", "em", "rem", "%", "vw", "vh", "vmin", "vmax", "ch", "ex",
        "cm", "mm", "in", "pt", "pc", "deg", "rad", "grad", "turn",
        "s", "ms", "Hz", "kHz", "dpi", "dpcm", "dppx", "fr"
    ]
    
    // Common color names
    private let colorNames = [
        "transparent", "black", "white", "red", "green", "blue", "yellow",
        "cyan", "magenta", "gray", "grey", "orange", "purple", "brown",
        "pink", "lime", "navy", "teal", "silver", "maroon", "olive",
        "aqua", "fuchsia", "crimson", "coral", "salmon", "gold", "khaki",
        "lavender", "violet", "indigo", "turquoise", "tan", "beige", "ivory"
    ]
    
    private let snippets: [SnippetTemplate] = [
        SnippetTemplate(
            label: "media",
            insertText: "@media (${1:min-width: 768px}) {\n    ${2:/* styles */}\n}",
            description: "Media query"
        ),
        SnippetTemplate(
            label: "keyframes",
            insertText: "@keyframes ${1:name} {\n    from {\n        ${2:/* initial state */}\n    }\n    to {\n        ${3:/* final state */}\n    }\n}",
            description: "Keyframes animation"
        ),
        SnippetTemplate(
            label: "import",
            insertText: "@import url('${1:path/to/file.css}');",
            description: "Import CSS file"
        ),
        SnippetTemplate(
            label: "flex-center",
            insertText: "display: flex;\njustify-content: center;\nalign-items: center;",
            description: "Flexbox center alignment"
        ),
        SnippetTemplate(
            label: "grid-template",
            insertText: "display: grid;\ngrid-template-columns: ${1:repeat(3, 1fr)};\ngrid-gap: ${2:1rem};",
            description: "CSS Grid layout"
        ),
        SnippetTemplate(
            label: "transition",
            insertText: "transition: ${1:all} ${2:0.3s} ${3:ease};",
            description: "CSS transition"
        ),
        SnippetTemplate(
            label: "animation",
            insertText: "animation: ${1:name} ${2:1s} ${3:ease} ${4:infinite};",
            description: "CSS animation"
        ),
        SnippetTemplate(
            label: "linear-gradient",
            insertText: "background: linear-gradient(${1:to right}, ${2:#000}, ${3:#fff});",
            description: "Linear gradient"
        ),
        SnippetTemplate(
            label: "box-shadow",
            insertText: "box-shadow: ${1:0} ${2:2px} ${3:4px} ${4:rgba(0, 0, 0, 0.1)};",
            description: "Box shadow"
        ),
        SnippetTemplate(
            label: "text-shadow",
            insertText: "text-shadow: ${1:1px} ${2:1px} ${3:2px} ${4:rgba(0, 0, 0, 0.5)};",
            description: "Text shadow"
        ),
        SnippetTemplate(
            label: "transform",
            insertText: "transform: ${1:translateX(0)} ${2:translateY(0)} ${3:scale(1)} ${4:rotate(0deg)};",
            description: "CSS transform"
        ),
        SnippetTemplate(
            label: "custom-property",
            insertText: "--${1:property-name}: ${2:value};",
            description: "CSS custom property"
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
        case .property:
            items.append(contentsOf: createPropertyCompletions(filter: analysisResult.filter))
            
        case .value:
            items.append(contentsOf: createValueCompletions(for: analysisResult.targetProperty, filter: analysisResult.filter))
            
        case .selector:
            items.append(contentsOf: createSelectorCompletions(filter: analysisResult.filter))
            
        case .pseudoClass:
            items.append(contentsOf: createPseudoClassCompletions(filter: analysisResult.filter))
            
        case .pseudoElement:
            items.append(contentsOf: createPseudoElementCompletions(filter: analysisResult.filter))
            
        case .function:
            items.append(contentsOf: createFunctionCompletions(filter: analysisResult.filter))
            
        case .unit:
            items.append(contentsOf: createUnitCompletions(filter: analysisResult.filter))
            
        case .atRule:
            items.append(contentsOf: createAtRuleCompletions(filter: analysisResult.filter))
            
        case .general:
            items.append(contentsOf: createPropertyCompletions(filter: analysisResult.filter))
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
    
    private func analyzeContext(_ context: CompletionContextModel) -> ContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = String(context.text.prefix(context.cursorPosition))
        
        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)
        
        // Check for @ rules
        if lineText.hasPrefix("@") || filter.hasPrefix("@") {
            return ContextAnalysisResult(type: .atRule, filter: filter)
        }
        
        // Check if we're in a rule block
        if let ruleContext = getCurrentRuleContext(from: beforeCursor) {
            // Check for pseudo-element (::)
            if beforeCursor.hasSuffix("::") {
                return ContextAnalysisResult(type: .pseudoElement, filter: "")
            }
            
            // Check for pseudo-class (:)
            if beforeCursor.hasSuffix(":") && !beforeCursor.hasSuffix("::") && !ruleContext.inDeclaration {
                return ContextAnalysisResult(type: .pseudoClass, filter: "")
            }
            
            // Check if we're after a property declaration
            if ruleContext.inDeclaration {
                if let property = ruleContext.currentProperty {
                    // Check for function context
                    if beforeCursor.hasSuffix("(") || isInFunction(beforeCursor) {
                        return ContextAnalysisResult(type: .function, filter: filter)
                    }
                    
                    // Check for unit context
                    if extractLastNumber(from: beforeCursor) != nil {
                        return ContextAnalysisResult(type: .unit, filter: filter)
                    }
                    
                    return ContextAnalysisResult(type: .value, filter: filter, targetProperty: property)
                }
            } else {
                return ContextAnalysisResult(type: .property, filter: filter)
            }
        }
        
        // We're likely in selector context
        return ContextAnalysisResult(type: .selector, filter: filter)
    }
    
    private func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-@")).inverted)
        return components.last ?? ""
    }
    
    private func getCurrentRuleContext(from text: String) -> RuleContext? {
        // Find if we're inside a CSS rule block
        var braceCount = 0
        var inDeclaration = false
        var currentProperty: String?
        
        // Count braces to determine if we're in a rule
        for char in text {
            if char == "{" {
                braceCount += 1
            } else if char == "}" {
                braceCount -= 1
                inDeclaration = false
                currentProperty = nil
            }
        }
        
        guard braceCount > 0 else { return nil }
        
        // Find current property if in declaration
        if let lastBrace = text.lastIndex(of: "{") {
            let afterBrace = String(text[text.index(after: lastBrace)...])
            
            // Check if we have a colon after the last semicolon
            if let lastSemicolon = afterBrace.lastIndex(of: ";") {
                let afterSemicolon = String(afterBrace[afterBrace.index(after: lastSemicolon)...])
                if afterSemicolon.contains(":") {
                    inDeclaration = true
                    // Extract property name
                    if let colonIndex = afterSemicolon.firstIndex(of: ":") {
                        currentProperty = String(afterSemicolon[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            } else if afterBrace.contains(":") {
                inDeclaration = true
                // Extract property name
                if let colonIndex = afterBrace.firstIndex(of: ":") {
                    currentProperty = String(afterBrace[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return RuleContext(inRule: true, inDeclaration: inDeclaration, currentProperty: currentProperty)
    }
    
    private func isInFunction(_ text: String) -> Bool {
        var parenCount = 0
        for char in text {
            if char == "(" {
                parenCount += 1
            } else if char == ")" {
                parenCount -= 1
            }
        }
        return parenCount > 0
    }
    
    private func extractLastNumber(from text: String) -> String? {
        let pattern = #"(\d+\.?\d*)\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }
    
    // MARK: - Completion Creation Methods
    
    private func createPropertyCompletions(filter: String) -> [CompletionItemModel] {
        properties
            .filter { property in
                filter.isEmpty || property.localizedCaseInsensitiveContains(filter)
            }
            .map { property in
                CompletionItemModel(
                    label: property,
                    insertText: "\(property): $0;",
                    kind: .property,
                    detail: "CSS property",
                    priority: 80,
                    preselect: property == filter
                )
            }
    }
    
    private func createValueCompletions(for property: String?, filter: String) -> [CompletionItemModel] {
        guard let property else { return [] }
        
        var items: [CompletionItemModel] = []
        
        // Add property-specific values
        if let values = commonValues[property] {
            items.append(contentsOf: values
                .filter { value in
                    filter.isEmpty || value.localizedCaseInsensitiveContains(filter)
                }
                .map { value in
                    CompletionItemModel(
                        label: value,
                        insertText: value,
                        kind: .value,
                        detail: "CSS value",
                        priority: 85
                    )
                })
        }
        
        // Add color names for color properties
        if ["color", "background-color", "border-color", "outline-color", "text-shadow", "box-shadow"].contains(property) {
            items.append(contentsOf: createColorCompletions(filter: filter))
        }
        
        // Add inherit, initial, unset for all properties
        let globalValues = ["inherit", "initial", "unset", "revert"]
        items.append(contentsOf: globalValues
            .filter { value in
                filter.isEmpty || value.localizedCaseInsensitiveContains(filter)
            }
            .map { value in
                CompletionItemModel(
                    label: value,
                    insertText: value,
                    kind: .value,
                    detail: "CSS global value",
                    priority: 70
                )
            })
        
        return items
    }
    
    private func createSelectorCompletions(filter: String) -> [CompletionItemModel] {
        let selectors = [
            ("*", "Universal selector"),
            ("#id", "ID selector"),
            (".class", "Class selector"),
            ("element", "Element selector"),
            ("[attribute]", "Attribute selector"),
            (":hover", "Pseudo-class"),
            ("::before", "Pseudo-element")
        ]
        
        return selectors
            .filter { selector, _ in
                filter.isEmpty || selector.localizedCaseInsensitiveContains(filter)
            }
            .map { selector, description in
                CompletionItemModel(
                    label: selector,
                    insertText: selector,
                    kind: .keyword,
                    detail: description,
                    priority: 75
                )
            }
    }
    
    private func createPseudoClassCompletions(filter: String) -> [CompletionItemModel] {
        pseudoClasses
            .filter { pseudo in
                filter.isEmpty || pseudo.localizedCaseInsensitiveContains(filter)
            }
            .map { pseudo in
                let needsParens = ["nth-child", "nth-last-child", "nth-of-type", "nth-last-of-type", "not", "lang"].contains(pseudo)
                let insertText = needsParens ? "\(pseudo)($0)" : pseudo
                
                return CompletionItemModel(
                    label: pseudo,
                    insertText: insertText,
                    kind: .keyword,
                    detail: "CSS pseudo-class",
                    priority: 85
                )
            }
    }
    
    private func createPseudoElementCompletions(filter: String) -> [CompletionItemModel] {
        pseudoElements
            .filter { pseudo in
                filter.isEmpty || pseudo.localizedCaseInsensitiveContains(filter)
            }
            .map { pseudo in
                CompletionItemModel(
                    label: pseudo,
                    insertText: pseudo,
                    kind: .keyword,
                    detail: "CSS pseudo-element",
                    priority: 85
                )
            }
    }
    
    private func createFunctionCompletions(filter: String) -> [CompletionItemModel] {
        functions
            .filter { function in
                filter.isEmpty || function.localizedCaseInsensitiveContains(filter)
            }
            .map { function in
                CompletionItemModel(
                    label: function,
                    insertText: "\(function)($0)",
                    kind: .function,
                    detail: "CSS function",
                    priority: 80
                )
            }
    }
    
    private func createUnitCompletions(filter: String) -> [CompletionItemModel] {
        units
            .filter { unit in
                filter.isEmpty || unit.localizedCaseInsensitiveContains(filter)
            }
            .map { unit in
                CompletionItemModel(
                    label: unit,
                    insertText: unit,
                    kind: .unit,
                    detail: "CSS unit",
                    priority: 90
                )
            }
    }
    
    private func createColorCompletions(filter: String) -> [CompletionItemModel] {
        colorNames
            .filter { color in
                filter.isEmpty || color.localizedCaseInsensitiveContains(filter)
            }
            .map { color in
                CompletionItemModel(
                    label: color,
                    insertText: color,
                    kind: .color,
                    detail: "CSS color",
                    priority: 75
                )
            }
    }
    
    private func createAtRuleCompletions(filter: String) -> [CompletionItemModel] {
        let atRules = [
            "@media", "@import", "@keyframes", "@font-face", "@supports",
            "@page", "@namespace", "@charset", "@document", "@viewport",
            "@counter-style", "@font-feature-values", "@property"
        ]
        
        return atRules
            .filter { rule in
                let filterToUse = filter.hasPrefix("@") ? filter : "@\(filter)"
                return rule.localizedCaseInsensitiveContains(filterToUse)
            }
            .map { rule in
                let insertText: String
                switch rule {
                case "@media":
                    insertText = "@media ($0) {\n    \n}"

                case "@import":
                    insertText = "@import url('$0');"

                case "@keyframes":
                    insertText = "@keyframes $0 {\n    \n}"

                case "@font-face":
                    insertText = "@font-face {\n    font-family: '$0';\n    src: url('');\n}"

                case "@supports":
                    insertText = "@supports ($0) {\n    \n}"

                default:
                    insertText = rule
                }
                
                return CompletionItemModel(
                    label: rule,
                    insertText: insertText,
                    kind: .keyword,
                    detail: "CSS at-rule",
                    priority: 85
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

private struct ContextAnalysisResult {
    enum CompletionType {
        case property
        case value
        case selector
        case pseudoClass
        case pseudoElement
        case function
        case unit
        case atRule
        case general
    }
    
    let type: CompletionType
    let filter: String
    let targetProperty: String?
    
    init(type: CompletionType, filter: String, targetProperty: String? = nil) {
        self.type = type
        self.filter = filter
        self.targetProperty = targetProperty
    }
}

private struct RuleContext {
    let inRule: Bool
    let inDeclaration: Bool
    let currentProperty: String?
}

private struct SnippetTemplate {
    let label: String
    let insertText: String
    let description: String
}
