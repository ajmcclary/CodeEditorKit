import Foundation

// MARK: - Java Completion Provider

/// Built-in completion provider for Java language
@MainActor
public final class JavaCompletionProvider: CompletionProvider {
    public let id = "java-builtin"
    public let supportedLanguages: [Language] = [.java]
    public let triggerCharacters = [".", "(", " ", "@", ":"]
    public let supportsSnippets = true
    
    // Java keywords
    private let keywords = [
        "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char",
        "class", "const", "continue", "default", "do", "double", "else", "enum",
        "extends", "final", "finally", "float", "for", "goto", "if", "implements",
        "import", "instanceof", "int", "interface", "long", "native", "new",
        "package", "private", "protected", "public", "return", "short", "static",
        "strictfp", "super", "switch", "synchronized", "this", "throw", "throws",
        "transient", "try", "void", "volatile", "while", "true", "false", "null",
        "var", "yield", "record", "sealed", "permits", "non-sealed"
    ]
    
    // Built-in types and classes
    private let types = [
        "boolean", "byte", "char", "short", "int", "long", "float", "double",
        "String", "Object", "Class", "Integer", "Double", "Float", "Long",
        "Boolean", "Character", "Byte", "Short", "Number", "Math", "System",
        "Thread", "Runnable", "Exception", "RuntimeException", "Error",
        "Throwable", "StringBuilder", "StringBuffer", "ArrayList", "LinkedList",
        "HashMap", "HashSet", "TreeMap", "TreeSet", "Iterator", "Collection",
        "List", "Set", "Map", "Queue", "Deque", "Stack", "Vector"
    ]
    
    // Common annotations
    private let annotations = [
        "@Override", "@Deprecated", "@SuppressWarnings", "@FunctionalInterface",
        "@SafeVarargs", "@Retention", "@Target", "@Documented", "@Inherited",
        "@Repeatable", "@Test", "@Before", "@After", "@BeforeClass", "@AfterClass",
        "@Autowired", "@Component", "@Service", "@Repository", "@Controller",
        "@RequestMapping", "@GetMapping", "@PostMapping", "@PutMapping",
        "@DeleteMapping", "@PathVariable", "@RequestParam", "@RequestBody"
    ]
    
    // Common packages
    private let packages = [
        "java.lang", "java.util", "java.io", "java.nio", "java.net", "java.time",
        "java.math", "java.text", "java.util.stream", "java.util.concurrent",
        "java.util.function", "java.util.regex", "javax.swing", "javafx",
        "org.springframework", "org.junit", "org.apache", "com.google"
    ]
    
    private let snippets: [SnippetTemplate] = [
        SnippetTemplate(
            label: "class",
            insertText: "public class ${1:ClassName} {\n    ${2:// fields and methods}\n}",
            description: "Class declaration"
        ),
        SnippetTemplate(
            label: "interface",
            insertText: "public interface ${1:InterfaceName} {\n    ${2:// method signatures}\n}",
            description: "Interface declaration"
        ),
        SnippetTemplate(
            label: "enum",
            insertText: "public enum ${1:EnumName} {\n    ${2:VALUE1},\n    ${3:VALUE2}\n}",
            description: "Enum declaration"
        ),
        SnippetTemplate(
            label: "main",
            insertText: "public static void main(String[] args) {\n    ${1:// main code}\n}",
            description: "Main method"
        ),
        SnippetTemplate(
            label: "method",
            insertText: "${1:public} ${2:void} ${3:methodName}(${4:parameters}) {\n    ${5:// method body}\n}",
            description: "Method declaration"
        ),
        SnippetTemplate(
            label: "constructor",
            insertText: "public ${1:ClassName}(${2:parameters}) {\n    ${3:// constructor body}\n}",
            description: "Constructor"
        ),
        SnippetTemplate(
            label: "if",
            insertText: "if (${1:condition}) {\n    ${2:// body}\n}",
            description: "If statement"
        ),
        SnippetTemplate(
            label: "ifelse",
            insertText: "if (${1:condition}) {\n    ${2:// if body}\n} else {\n    ${3:// else body}\n}",
            description: "If-else statement"
        ),
        SnippetTemplate(
            label: "for",
            insertText: "for (${1:int i = 0}; ${2:i < n}; ${3:i++}) {\n    ${4:// body}\n}",
            description: "For loop"
        ),
        SnippetTemplate(
            label: "foreach",
            insertText: "for (${1:Type} ${2:item} : ${3:collection}) {\n    ${4:// body}\n}",
            description: "Enhanced for loop"
        ),
        SnippetTemplate(
            label: "while",
            insertText: "while (${1:condition}) {\n    ${2:// body}\n}",
            description: "While loop"
        ),
        SnippetTemplate(
            label: "dowhile",
            insertText: "do {\n    ${1:// body}\n} while (${2:condition});",
            description: "Do-while loop"
        ),
        SnippetTemplate(
            label: "switch",
            insertText: "switch (${1:expression}) {\n    case ${2:value1}:\n        ${3:// code}\n        break;\n    default:\n        ${4:// default code}\n        break;\n}",
            description: "Switch statement"
        ),
        SnippetTemplate(
            label: "try",
            insertText: "try {\n    ${1:// code}\n} catch (${2:Exception} ${3:e}) {\n    ${4:// handle exception}\n}",
            description: "Try-catch block"
        ),
        SnippetTemplate(
            label: "tryfinally",
            insertText: "try {\n    ${1:// code}\n} catch (${2:Exception} ${3:e}) {\n    ${4:// handle exception}\n} finally {\n    ${5:// cleanup}\n}",
            description: "Try-catch-finally"
        ),
        SnippetTemplate(
            label: "lambda",
            insertText: "(${1:params}) -> ${2:expression}",
            description: "Lambda expression"
        ),
        SnippetTemplate(
            label: "stream",
            insertText: "${1:collection}.stream()${2:.filter(x -> x > 0)}${3:.collect(Collectors.toList())}",
            description: "Stream operation"
        ),
        SnippetTemplate(
            label: "sout",
            insertText: "System.out.println(${1:message});",
            description: "Print to console"
        ),
        SnippetTemplate(
            label: "test",
            insertText: "@Test\npublic void ${1:testMethodName}() {\n    ${2:// test code}\n}",
            description: "JUnit test method"
        ),
        SnippetTemplate(
            label: "getter",
            insertText: "public ${1:Type} get${2:Property}() {\n    return ${3:property};\n}",
            description: "Getter method"
        ),
        SnippetTemplate(
            label: "setter",
            insertText: "public void set${1:Property}(${2:Type} ${3:property}) {\n    this.${3:property} = ${3:property};\n}",
            description: "Setter method"
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
        case .import:
            items.append(contentsOf: createImportCompletions(filter: analysisResult.filter))
            
        case .annotation:
            items.append(contentsOf: createAnnotationCompletions(filter: analysisResult.filter))
            
        case .keyword:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            
        case .type:
            items.append(contentsOf: createTypeCompletions(filter: analysisResult.filter))
            
        case .member:
            items.append(contentsOf: createMemberCompletions(for: analysisResult.targetType, filter: analysisResult.filter))
            
        case .general:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createTypeCompletions(filter: analysisResult.filter))
            if supportsSnippets {
                items.append(contentsOf: createSnippetCompletions(filter: analysisResult.filter))
            }
            
        case .parameter:
            items.append(contentsOf: createParameterCompletions(filter: analysisResult.filter))
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
        
        // Check for import statements
        if lineText.hasPrefix("import ") {
            return ContextAnalysisResult(type: .import, filter: filter)
        }
        
        // Check for annotation context
        if beforeCursor.hasSuffix("@") || filter.hasPrefix("@") {
            return ContextAnalysisResult(type: .annotation, filter: filter)
        }
        
        // Check for member access
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return ContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }
        
        // Check for type context
        if lineText.contains(" ") && !lineText.contains("=") && !lineText.contains("(") {
            // Likely a variable declaration
            return ContextAnalysisResult(type: .type, filter: filter)
        }
        
        // Check for method declaration
        if lineText.contains("(") && !lineText.contains(")") {
            return ContextAnalysisResult(type: .parameter, filter: filter)
        }
        
        return ContextAnalysisResult(type: .general, filter: filter)
    }
    
    private func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_@")).inverted)
        return components.last ?? ""
    }
    
    private func extractTargetType(from text: String) -> String? {
        // Extract the object before the dot
        let pattern = #"(\w+)\s*\.\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }
    
    // MARK: - Completion Creation Methods
    
    private func createKeywordCompletions(filter: String) -> [CompletionItemModel] {
        keywords
            .filter { keyword in
                filter.isEmpty || keyword.localizedCaseInsensitiveContains(filter)
            }
            .map { keyword in
                CompletionItemModel(
                    label: keyword,
                    insertText: keyword,
                    kind: .keyword,
                    detail: "Java keyword",
                    priority: 80,
                    preselect: keyword == filter
                )
            }
    }
    
    private func createTypeCompletions(filter: String) -> [CompletionItemModel] {
        types
            .filter { type in
                filter.isEmpty || type.localizedCaseInsensitiveContains(filter)
            }
            .map { type in
                let isGeneric = ["ArrayList", "LinkedList", "HashMap", "HashSet", "TreeMap", "TreeSet", "List", "Set", "Map", "Collection", "Iterator"].contains(type)
                return CompletionItemModel(
                    label: type,
                    insertText: isGeneric ? "\(type)<$0>" : type,
                    kind: .class,
                    detail: "Java type",
                    priority: 70
                )
            }
    }
    
    private func createAnnotationCompletions(filter: String) -> [CompletionItemModel] {
        annotations
            .filter { annotation in
                let name = annotation.hasPrefix("@") ? annotation : "@\(annotation)"
                return filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
            }
            .map { annotation in
                CompletionItemModel(
                    label: annotation,
                    insertText: annotation,
                    kind: .method,
                    detail: "Java annotation",
                    priority: 85
                )
            }
    }
    
    private func createImportCompletions(filter: String) -> [CompletionItemModel] {
        packages
            .filter { pkg in
                filter.isEmpty || pkg.localizedCaseInsensitiveContains(filter)
            }
            .map { pkg in
                CompletionItemModel(
                    label: pkg,
                    insertText: pkg,
                    kind: .module,
                    detail: "Java package",
                    priority: 85
                )
            }
    }
    
    private func createParameterCompletions(filter: String) -> [CompletionItemModel] {
        let commonParams = [
            "String str", "int n", "int i", "boolean flag", "Object obj",
            "List<?> list", "Map<?, ?> map", "Exception e", "T value"
        ]
        
        return commonParams
            .filter { param in
                filter.isEmpty || param.localizedCaseInsensitiveContains(filter)
            }
            .map { param in
                CompletionItemModel(
                    label: param,
                    insertText: param,
                    kind: .variable,
                    detail: "Parameter suggestion",
                    priority: 50
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
    
    private func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
        guard let targetType else { return [] }
        
        // Provide common member completions based on type
        switch targetType.lowercased() {
        case "string":
            return createStringMemberCompletions(filter: filter)
            
        case "list", "arraylist", "linkedlist":
            return createListMemberCompletions(filter: filter)
            
        case "map", "hashmap", "treemap":
            return createMapMemberCompletions(filter: filter)
            
        case "system":
            return createSystemMemberCompletions(filter: filter)
            
        case "math":
            return createMathMemberCompletions(filter: filter)
            
        default:
            return createCommonMemberCompletions(filter: filter)
        }
    }
    
    // MARK: - Type-Specific Members
    
    private func createStringMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("length()", "method", "Get string length"),
            ("isEmpty()", "method", "Check if empty"),
            ("charAt()", "method", "Character at index"),
            ("substring()", "method", "Extract substring"),
            ("indexOf()", "method", "Find index"),
            ("contains()", "method", "Check if contains"),
            ("startsWith()", "method", "Check prefix"),
            ("endsWith()", "method", "Check suffix"),
            ("toLowerCase()", "method", "Convert to lowercase"),
            ("toUpperCase()", "method", "Convert to uppercase"),
            ("trim()", "method", "Remove whitespace"),
            ("replace()", "method", "Replace substring"),
            ("split()", "method", "Split string"),
            ("equals()", "method", "Check equality"),
            ("compareTo()", "method", "Compare strings")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createListMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("size()", "method", "Get list size"),
            ("isEmpty()", "method", "Check if empty"),
            ("add()", "method", "Add element"),
            ("remove()", "method", "Remove element"),
            ("get()", "method", "Get element"),
            ("set()", "method", "Set element"),
            ("clear()", "method", "Clear list"),
            ("contains()", "method", "Check if contains"),
            ("indexOf()", "method", "Find index"),
            ("iterator()", "method", "Get iterator"),
            ("toArray()", "method", "Convert to array"),
            ("sort()", "method", "Sort list"),
            ("stream()", "method", "Get stream")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createMapMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("size()", "method", "Get map size"),
            ("isEmpty()", "method", "Check if empty"),
            ("put()", "method", "Put key-value"),
            ("get()", "method", "Get value"),
            ("remove()", "method", "Remove key"),
            ("clear()", "method", "Clear map"),
            ("containsKey()", "method", "Check key"),
            ("containsValue()", "method", "Check value"),
            ("keySet()", "method", "Get keys"),
            ("values()", "method", "Get values"),
            ("entrySet()", "method", "Get entries"),
            ("forEach()", "method", "Iterate entries")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createSystemMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("out", "property", "Standard output"),
            ("err", "property", "Error output"),
            ("in", "property", "Standard input"),
            ("exit()", "method", "Exit program"),
            ("currentTimeMillis()", "method", "Current time"),
            ("nanoTime()", "method", "Nano time"),
            ("getProperty()", "method", "Get property"),
            ("setProperty()", "method", "Set property"),
            ("getenv()", "method", "Get environment"),
            ("gc()", "method", "Garbage collection")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createMathMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("PI", "constant", "Pi constant"),
            ("E", "constant", "E constant"),
            ("abs()", "method", "Absolute value"),
            ("ceil()", "method", "Ceiling"),
            ("floor()", "method", "Floor"),
            ("round()", "method", "Round"),
            ("max()", "method", "Maximum"),
            ("min()", "method", "Minimum"),
            ("pow()", "method", "Power"),
            ("sqrt()", "method", "Square root"),
            ("random()", "method", "Random number"),
            ("sin()", "method", "Sine"),
            ("cos()", "method", "Cosine"),
            ("tan()", "method", "Tangent"),
            ("log()", "method", "Logarithm")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createCommonMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("toString()", "method", "Convert to string"),
            ("equals()", "method", "Check equality"),
            ("hashCode()", "method", "Hash code"),
            ("getClass()", "method", "Get class"),
            ("notify()", "method", "Notify thread"),
            ("notifyAll()", "method", "Notify all threads"),
            ("wait()", "method", "Wait for notification")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createMemberItems(from members: [(String, String, String)], filter: String) -> [CompletionItemModel] {
        members
            .filter { name, _, _ in
                filter.isEmpty || name.localizedCaseInsensitiveContains(filter)
            }
            .map { name, type, description in
                CompletionItemModel(
                    label: name,
                    insertText: name,
                    kind: type == "method" ? .method : (type == "constant" ? .constant : .property),
                    detail: description,
                    priority: 85
                )
            }
    }
}

// MARK: - Supporting Types

private struct ContextAnalysisResult {
    enum CompletionType {
        case keyword
        case type
        case `import`
        case annotation
        case member
        case general
        case parameter
    }
    
    let type: CompletionType
    let filter: String
    let targetType: String?
    
    init(type: CompletionType, filter: String, targetType: String? = nil) {
        self.type = type
        self.filter = filter
        self.targetType = targetType
    }
}

private struct SnippetTemplate {
    let label: String
    let insertText: String
    let description: String
}
