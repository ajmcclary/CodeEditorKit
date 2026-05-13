import Foundation

// MARK: - Language Metadata Registry

/// DI-friendly registry that wraps `LanguageDescriptor` for the completion system.
///
/// Previously duplicated keyword/type/function/literal data that now lives in
/// `LanguageDescriptor`. This class exists to satisfy the dependency-injection
/// contract (`EditorRuntimeDependencies`, `EditorFeatureRuntimeDependencies`,
/// `CompletionProviderRegistry`) and provides a stable public API.
@MainActor
public final class LanguageMetadataRegistry {
    /// Public initializer for dependency injection
    public init() {}

    // MARK: - Public API

    /// Gets metadata for a specific language.
    ///
    /// All core data (keywords, types, functions, literals, triggers) comes from
    /// `LanguageDescriptor`; snippets, member completions, and common modules are
    /// also read from the descriptor so every language gets consistent treatment.
    public func metadata(for language: Language) -> ExtendedLanguageMetadata? {
        guard let descriptor = LanguageDescriptor.descriptor(for: language) else { return nil }
        return ExtendedLanguageMetadata(
            keywords: descriptor.keywords,
            types: descriptor.types,
            functions: descriptor.functions,
            literals: descriptor.literals,
            triggerCharacters: descriptor.triggerCharacters,
            snippets: descriptor.snippets,
            memberCompletions: descriptor.memberCompletions ?? DefaultMemberCompletions(),
            commonModules: descriptor.commonModules
        )
    }

    /// Gets all supported languages
    public var supportedLanguages: [Language] {
        Array(LanguageDescriptor.all.keys)
    }

    /// Creates a completion provider for the specified language.
    ///
    /// Delegates to `LanguageProviderFactory` so there is a single code path
    /// for provider creation.
    public func createProvider(for language: Language) -> CompletionProvider? {
        LanguageProviderFactory.createProvider(for: language)
    }
}

// MARK: - Extended Language Metadata

/// Extended metadata that includes snippets and module information
public struct ExtendedLanguageMetadata {
    let keywords: [String]
    let types: [String]
    let functions: [String]
    let literals: [String]
    let triggerCharacters: [String]
    let snippets: [SnippetTemplate]
    let memberCompletions: LanguageMemberCompletions
    let commonModules: [String]
}

// MARK: - Snippet Collections

/// Collection of Swift code snippets
public enum SwiftSnippets {
    /// All available Swift snippets
    public static let all: [SnippetTemplate] = [
        SnippetTemplate(
            label: "func",
            insertText: "func ${1:name}(${2:parameters}) -> ${3:ReturnType} {\n    ${4:// body}\n}",
            description: "Function definition"
        ),
        SnippetTemplate(
            label: "class",
            insertText: "class ${1:ClassName}: ${2:SuperClass} {\n    ${3:// properties and methods}\n}",
            description: "Class definition"
        ),
        SnippetTemplate(
            label: "struct",
            insertText: "struct ${1:StructName} {\n    ${2:// properties}\n}",
            description: "Struct definition"
        ),
        SnippetTemplate(
            label: "enum",
            insertText: "enum ${1:EnumName} {\n    case ${2:caseName}\n}",
            description: "Enum definition"
        ),
        SnippetTemplate(
            label: "protocol",
            insertText: "protocol ${1:ProtocolName} {\n    ${2:// requirements}\n}",
            description: "Protocol definition"
        ),
        SnippetTemplate(
            label: "extension",
            insertText: "extension ${1:TypeName} {\n    ${2:// methods and properties}\n}",
            description: "Extension definition"
        ),
        SnippetTemplate(
            label: "if",
            insertText: "if ${1:condition} {\n    ${2:// body}\n}",
            description: "If statement"
        ),
        SnippetTemplate(
            label: "guard",
            insertText: "guard ${1:condition} else {\n    ${2:return}\n}",
            description: "Guard statement"
        ),
        SnippetTemplate(
            label: "for",
            insertText: "for ${1:item} in ${2:collection} {\n    ${3:// body}\n}",
            description: "For-in loop"
        ),
        SnippetTemplate(
            label: "switch",
            insertText: "switch ${1:value} {\ncase ${2:pattern}:\n    ${3:// code}\ndefault:\n    ${4:// default case}\n}",
            description: "Switch statement"
        )
    ]
}

/// Collection of TypeScript code snippets
public enum TypeScriptSnippets {
    /// All available TypeScript snippets
    public static let all: [SnippetTemplate] = [
        SnippetTemplate(
            label: "interface",
            insertText: "interface ${1:InterfaceName} {\n    ${2:property}: ${3:type};\n}",
            description: "Interface definition"
        ),
        SnippetTemplate(
            label: "type",
            insertText: "type ${1:TypeName} = ${2:type};",
            description: "Type alias"
        ),
        SnippetTemplate(
            label: "class",
            insertText: "class ${1:ClassName} {\n    constructor(${2:parameters}) {\n        ${3:// constructor body}\n    }\n}",
            description: "Class definition"
        ),
        SnippetTemplate(
            label: "function",
            insertText: "function ${1:name}(${2:params}): ${3:ReturnType} {\n    ${4:// body}\n}",
            description: "Function definition"
        ),
        SnippetTemplate(
            label: "arrow",
            insertText: "const ${1:name} = (${2:params}): ${3:ReturnType} => {\n    ${4:// body}\n}",
            description: "Arrow function"
        ),
        SnippetTemplate(
            label: "async",
            insertText: "async function ${1:name}(${2:params}): Promise<${3:ReturnType}> {\n    ${4:// async body}\n}",
            description: "Async function"
        )
    ]
}

/// Collection of Go code snippets
public enum GoSnippets {
    /// All available Go snippets
    public static let all: [SnippetTemplate] = [
        SnippetTemplate(
            label: "func",
            insertText: "func ${1:name}(${2:params}) ${3:returnType} {\n    ${4:// body}\n}",
            description: "Function definition"
        ),
        SnippetTemplate(
            label: "method",
            insertText: "func (${1:receiver} ${2:Type}) ${3:name}(${4:params}) ${5:returnType} {\n    ${6:// body}\n}",
            description: "Method definition"
        ),
        SnippetTemplate(
            label: "struct",
            insertText: "type ${1:StructName} struct {\n    ${2:Field} ${3:Type}\n}",
            description: "Struct definition"
        ),
        SnippetTemplate(
            label: "interface",
            insertText: "type ${1:InterfaceName} interface {\n    ${2:Method}() ${3:returnType}\n}",
            description: "Interface definition"
        ),
        SnippetTemplate(
            label: "if err",
            insertText: "if err != nil {\n    ${1:return err}\n}",
            description: "Error check"
        ),
        SnippetTemplate(
            label: "for range",
            insertText: "for ${1:key}, ${2:value} := range ${3:collection} {\n    ${4:// body}\n}",
            description: "For range loop"
        )
    ]
}

// MARK: - Additional Member Completions

public struct SwiftMemberCompletions: LanguageMemberCompletions {
    public func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
        guard let targetType else { return [] }

        switch targetType.lowercased() {
        case "string":
            return createStringMemberCompletions(filter: filter)

        case "array":
            return createArrayMemberCompletions(filter: filter)

        case "dictionary":
            return createDictionaryMemberCompletions(filter: filter)

        default:
            return createCommonMemberCompletions(filter: filter)
        }
    }

    private func createStringMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("count", "property", "Number of characters"),
            ("isEmpty", "property", "Whether string is empty"),
            ("startIndex", "property", "Start index"),
            ("endIndex", "property", "End index"),
            ("uppercased()", "method", "Uppercase string"),
            ("lowercased()", "method", "Lowercase string"),
            ("capitalized", "property", "Capitalized string"),
            ("contains(_:)", "method", "Check if contains substring"),
            ("hasPrefix(_:)", "method", "Check prefix"),
            ("hasSuffix(_:)", "method", "Check suffix"),
            ("components(separatedBy:)", "method", "Split string"),
            ("trimmingCharacters(in:)", "method", "Trim characters"),
            ("replacingOccurrences(of:with:)", "method", "Replace occurrences")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }

    private func createArrayMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("count", "property", "Number of elements"),
            ("isEmpty", "property", "Whether array is empty"),
            ("first", "property", "First element"),
            ("last", "property", "Last element"),
            ("append(_:)", "method", "Add element"),
            ("insert(_:at:)", "method", "Insert element"),
            ("remove(at:)", "method", "Remove element"),
            ("removeAll()", "method", "Remove all elements"),
            ("contains(_:)", "method", "Check if contains"),
            ("firstIndex(of:)", "method", "Find first index"),
            ("sorted()", "method", "Sorted array"),
            ("reversed()", "method", "Reversed array"),
            ("map(_:)", "method", "Transform elements"),
            ("filter(_:)", "method", "Filter elements"),
            ("reduce(_:_:)", "method", "Reduce to single value")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }

    private func createDictionaryMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("count", "property", "Number of key-value pairs"),
            ("isEmpty", "property", "Whether dictionary is empty"),
            ("keys", "property", "Dictionary keys"),
            ("values", "property", "Dictionary values"),
            ("removeValue(forKey:)", "method", "Remove value"),
            ("removeAll()", "method", "Remove all entries"),
            ("updateValue(_:forKey:)", "method", "Update value"),
            ("merge(_:uniquingKeysWith:)", "method", "Merge dictionaries"),
            ("mapValues(_:)", "method", "Transform values"),
            ("filter(_:)", "method", "Filter entries")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }

    private func createCommonMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("description", "property", "String description"),
            ("debugDescription", "property", "Debug description"),
            ("hash", "property", "Hash value"),
            ("self", "property", "Self reference")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
}

public struct TypeScriptMemberCompletions: LanguageMemberCompletions {
    public func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
        // Reuse JavaScript completions for TypeScript
        let jsCompletions = JavaScriptMemberCompletions()
        return jsCompletions.createMemberCompletions(for: targetType, filter: filter)
    }
}

public struct GoMemberCompletions: LanguageMemberCompletions {
    public func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
        guard let targetType else { return [] }

        switch targetType.lowercased() {
        // Type-based completions
        case "string":
            return createStringMemberCompletions(filter: filter)

        case "slice", "[]":
            return createSliceMemberCompletions(filter: filter)

        case "map":
            return createMapMemberCompletions(filter: filter)

        // Package-based completions
        case "fmt":
            return createFmtPackageCompletions(filter: filter)

        case "strings":
            return createStringsPackageCompletions(filter: filter)

        case "time":
            return createTimePackageCompletions(filter: filter)

        case "http":
            return createHttpPackageCompletions(filter: filter)

        default:
            return createCommonMemberCompletions(filter: filter)
        }
    }

    // MARK: - Type-Specific Members

    private func createStringMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("len()", "function", "String length"),
            ("strings.Contains()", "function", "Check substring"),
            ("strings.HasPrefix()", "function", "Check prefix"),
            ("strings.HasSuffix()", "function", "Check suffix"),
            ("strings.Split()", "function", "Split string"),
            ("strings.Join()", "function", "Join strings"),
            ("strings.ToLower()", "function", "To lowercase"),
            ("strings.ToUpper()", "function", "To uppercase"),
            ("strings.TrimSpace()", "function", "Trim whitespace"),
            ("strings.Replace()", "function", "Replace substring")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }

    private func createSliceMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("len()", "function", "Slice length"),
            ("cap()", "function", "Slice capacity"),
            ("append()", "function", "Append elements"),
            ("copy()", "function", "Copy slice"),
            ("make()", "function", "Make slice"),
            ("[:]", "operator", "Slice operation")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }

    private func createMapMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("len()", "function", "Map length"),
            ("delete()", "function", "Delete key"),
            ("make()", "function", "Make map"),
            (", ok", "pattern", "Value and exists check")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }

    // MARK: - Package-Specific Members

    private func createFmtPackageCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("Println()", "method", "Print with newline"),
            ("Printf()", "method", "Formatted print"),
            ("Sprintf()", "method", "Format string"),
            ("Print()", "method", "Print values"),
            ("Errorf()", "method", "Format error"),
            ("Fprintf()", "method", "Format to writer"),
            ("Scan()", "method", "Scan input"),
            ("Scanf()", "method", "Scan formatted"),
            ("Fscanf()", "method", "Scan from reader")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }

    private func createStringsPackageCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("Contains()", "method", "Check substring"),
            ("HasPrefix()", "method", "Check prefix"),
            ("HasSuffix()", "method", "Check suffix"),
            ("Join()", "method", "Join strings"),
            ("Split()", "method", "Split string"),
            ("ToLower()", "method", "Convert to lowercase"),
            ("ToUpper()", "method", "Convert to uppercase"),
            ("Trim()", "method", "Trim whitespace"),
            ("Replace()", "method", "Replace substring"),
            ("Fields()", "method", "Split into fields")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }

    private func createTimePackageCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("Now()", "method", "Current time"),
            ("Sleep()", "method", "Sleep duration"),
            ("Since()", "method", "Time since"),
            ("Until()", "method", "Time until"),
            ("Parse()", "method", "Parse time"),
            ("Duration", "type", "Duration type"),
            ("Time", "type", "Time type"),
            ("Second", "constant", "Second duration"),
            ("Minute", "constant", "Minute duration"),
            ("Hour", "constant", "Hour duration")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }

    private func createHttpPackageCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("Get()", "method", "HTTP GET request"),
            ("Post()", "method", "HTTP POST request"),
            ("ListenAndServe()", "method", "Start HTTP server"),
            ("HandleFunc()", "method", "Register handler"),
            ("NewRequest()", "method", "Create request"),
            ("StatusOK", "constant", "200 status"),
            ("StatusNotFound", "constant", "404 status"),
            ("MethodGet", "constant", "GET method"),
            ("MethodPost", "constant", "POST method")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }

    private func createCommonMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("String()", "method", "String representation"),
            ("Error()", "method", "Error string"),
            ("Close()", "method", "Close resource"),
            ("Read()", "method", "Read data"),
            ("Write()", "method", "Write data")
        ]
        return SharedCompletionBuilder.createMemberItems(from: members, filter: filter)
    }
}
