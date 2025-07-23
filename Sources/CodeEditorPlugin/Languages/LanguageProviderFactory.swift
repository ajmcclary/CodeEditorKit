import Foundation

// MARK: - Language Provider Factory

/// Factory for creating language-specific completion providers with shared logic and reduced duplication
@MainActor
public enum LanguageProviderFactory {
    // MARK: - Shared Language Metadata

    /// Contains all language-specific data in a structured format
    private static let languageMetadata: [Language: LanguageMetadata] = [
        .python: LanguageMetadata(
            keywords: [
                "def", "class", "if", "elif", "else", "for", "while", "try", "except",
                "finally", "with", "as", "import", "from", "return", "yield", "break",
                "continue", "pass", "global", "nonlocal", "lambda", "and", "or", "not",
                "in", "is", "del", "async", "await", "assert", "raise", "match", "case"
            ],
            types: [
                "int", "float", "str", "bool", "list", "tuple", "dict", "set", "frozenset",
                "bytes", "bytearray", "memoryview", "range", "complex", "type", "object",
                "property", "staticmethod", "classmethod", "super"
            ],
            functions: [
                "print", "input", "len", "range", "enumerate", "zip", "map", "filter",
                "sorted", "reversed", "sum", "min", "max", "any", "all", "abs", "round",
                "pow", "divmod", "isinstance", "issubclass", "hasattr", "getattr", "setattr",
                "delattr", "open", "format", "chr", "ord", "bin", "hex", "oct", "eval",
                "exec", "compile", "globals", "locals", "vars", "dir", "help", "id",
                "hash", "iter", "next", "callable", "repr", "ascii", "breakpoint"
            ],
            literals: [
                "True", "False", "None", "self", "__name__", "__main__", "__file__",
                "__doc__", "__dict__", "__class__", "__init__", "__new__", "__del__",
                "__str__", "__repr__", "__eq__", "__ne__", "__lt__", "__le__", "__gt__",
                "__ge__", "__hash__", "__bool__", "__len__", "__getitem__", "__setitem__",
                "__delitem__", "__iter__", "__next__", "__contains__", "__add__", "__sub__",
                "__mul__", "__truediv__", "__floordiv__", "__mod__", "__pow__", "__and__",
                "__or__", "__xor__", "__lshift__", "__rshift__", "__neg__", "__pos__",
                "__abs__", "__invert__", "__enter__", "__exit__", "__call__"
            ],
            triggerCharacters: [".", "(", "[", " ", ":"],
            memberCompletions: PythonMemberCompletions()
        ),

        .javascript: LanguageMetadata(
            keywords: [
                "const", "let", "var", "function", "class", "if", "else", "for", "while",
                "do", "switch", "case", "default", "break", "continue", "return", "try",
                "catch", "finally", "throw", "async", "await", "import", "export", "from",
                "as", "typeof", "instanceof", "new", "this", "super", "static", "extends",
                "constructor", "get", "set", "of", "in", "delete", "void", "yield",
                "debugger", "with"
            ],
            types: [
                "Object", "Array", "String", "Number", "Boolean", "Function", "Symbol",
                "Date", "RegExp", "Error", "Math", "JSON", "console", "Promise", "Map",
                "Set", "WeakMap", "WeakSet", "Proxy", "Reflect", "Intl", "BigInt",
                "ArrayBuffer", "SharedArrayBuffer", "DataView", "Float32Array", "Float64Array",
                "Int8Array", "Int16Array", "Int32Array", "Uint8Array", "Uint16Array",
                "Uint32Array", "Uint8ClampedArray"
            ],
            functions: [
                "parseInt", "parseFloat", "isNaN", "isFinite", "encodeURI", "decodeURI",
                "encodeURIComponent", "decodeURIComponent", "eval", "setTimeout", "clearTimeout",
                "setInterval", "clearInterval", "setImmediate", "clearImmediate", "requestAnimationFrame",
                "cancelAnimationFrame", "fetch", "alert", "confirm", "prompt"
            ],
            literals: [
                "true", "false", "null", "undefined", "NaN", "Infinity", "globalThis",
                "window", "document", "location", "navigator", "history"
            ],
            triggerCharacters: [".", "(", "[", "{", " ", ":"],
            memberCompletions: JavaScriptMemberCompletions()
        ),

        .rust: LanguageMetadata(
            keywords: [
                "as", "async", "await", "break", "const", "continue", "crate", "dyn",
                "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in",
                "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
                "self", "Self", "static", "struct", "super", "trait", "true", "type",
                "unsafe", "use", "where", "while", "abstract", "become", "box", "do",
                "final", "macro", "override", "priv", "typeof", "unsized", "virtual",
                "yield", "try"
            ],
            types: [
                "bool", "char", "f32", "f64", "i8", "i16", "i32", "i64", "i128",
                "isize", "str", "u8", "u16", "u32", "u64", "u128", "usize",
                "String", "Vec", "HashMap", "HashSet", "Option", "Result", "Box",
                "Rc", "Arc", "RefCell", "Mutex", "RwLock", "Cell"
            ],
            functions: [
                "println!", "print!", "eprintln!", "eprint!", "format!", "write!",
                "writeln!", "panic!", "assert!", "assert_eq!", "assert_ne!",
                "debug_assert!", "debug_assert_eq!", "debug_assert_ne!", "vec!",
                "include!", "include_str!", "include_bytes!", "concat!", "env!",
                "option_env!", "cfg!", "line!", "column!", "file!", "module_path!",
                "stringify!", "todo!", "unimplemented!", "unreachable!", "dbg!"
            ],
            literals: [
                "Clone", "Copy", "Debug", "Default", "Display", "Drop", "Eq", "Fn",
                "FnMut", "FnOnce", "From", "Into", "Iterator", "Ord", "PartialEq",
                "PartialOrd", "Send", "Sized", "Sync", "ToString", "AsRef", "AsMut",
                "Borrow", "BorrowMut", "Deref", "DerefMut"
            ],
            triggerCharacters: [".", "::", "(", "<", " ", "!"],
            memberCompletions: RustMemberCompletions()
        )
    ]

    // MARK: - Factory Methods

    /// Creates a completion provider for the specified language
    public static func createProvider(for language: Language) -> CompletionProvider? {
        guard let metadata = languageMetadata[language] else { return nil }

        return UniversalCompletionProvider(
            language: language,
            metadata: metadata
        )
    }

    /// Gets all supported languages
    public static var supportedLanguages: [Language] {
        Array(languageMetadata.keys)
    }
}

// MARK: - Universal Completion Provider

/// Universal completion provider that works with any language metadata
@MainActor
public final class UniversalCompletionProvider: CompletionProvider {
    public let id: String
    public let supportedLanguages: [Language]
    public let triggerCharacters: [String]
    public let supportsSnippets = true

    private let language: Language
    private let metadata: LanguageMetadata

    init(language: Language, metadata: LanguageMetadata) {
        self.language = language
        self.metadata = metadata
        self.id = "\(language.rawValue)-universal"
        self.supportedLanguages = [language]
        self.triggerCharacters = metadata.triggerCharacters
    }

    // MARK: - CompletionProvider Implementation

    public func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()

        // Use shared context analysis
        let analysisResult = SharedContextAnalyzer.analyzeContext(context, for: language)
        var items: [CompletionItemModel] = []

        // Add appropriate completions based on context
        switch analysisResult.type {
        case .keyword:
            items.append(contentsOf: SharedCompletionBuilder.createKeywordCompletions(
                from: metadata.keywords,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))

        case .type:
            items.append(contentsOf: SharedCompletionBuilder.createTypeCompletions(
                from: metadata.types,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))

        case .function:
            items.append(contentsOf: SharedCompletionBuilder.createFunctionCompletions(
                from: metadata.functions,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))

        case .literal:
            items.append(contentsOf: SharedCompletionBuilder.createLiteralCompletions(
                from: metadata.literals,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))

        case .member:
            items.append(contentsOf: metadata.memberCompletions.createMemberCompletions(
                for: analysisResult.targetType,
                filter: analysisResult.filter
            ))

        case .general:
            items.append(contentsOf: SharedCompletionBuilder.createKeywordCompletions(
                from: metadata.keywords,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))
            items.append(contentsOf: SharedCompletionBuilder.createTypeCompletions(
                from: metadata.types,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))
            items.append(contentsOf: SharedCompletionBuilder.createFunctionCompletions(
                from: metadata.functions,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))
            items.append(contentsOf: SharedCompletionBuilder.createLiteralCompletions(
                from: metadata.literals,
                filter: analysisResult.filter,
                languageName: language.rawValue.capitalized
            ))

        case .parameter:
            items.append(contentsOf: SharedCompletionBuilder.createParameterCompletions(
                for: language,
                filter: analysisResult.filter
            ))
        }

        let processingTime = Date().timeIntervalSince(startTime)

        return CompletionResult(
            items: items,
            context: context,
            isIncomplete: false,
            processingTime: processingTime
        )
    }
}

// MARK: - Supporting Types

/// Metadata container for a specific language
public struct LanguageMetadata {
    let keywords: [String]
    let types: [String]
    let functions: [String]
    let literals: [String]
    let triggerCharacters: [String]
    let memberCompletions: LanguageMemberCompletions
}

/// Protocol for language-specific member completions
public protocol LanguageMemberCompletions {
    /// Creates member completion suggestions for a specific type
    /// - Parameters:
    ///   - targetType: The type to get completions for
    ///   - filter: Filter string to narrow results
    /// - Returns: Array of completion items
    func createMemberCompletions(for targetType: String?, filter: String) -> [CompletionItemModel]
}

/// Universal context analysis result
public struct UniversalContextAnalysisResult {
    /// Type of completion being suggested
    public enum CompletionType {
        /// Language keyword completion
        case keyword
        /// Type name completion
        case type
        /// Function or method completion
        case function
        /// Literal value completion
        case literal
        /// Member access completion
        case member
        /// Parameter completion
        case parameter
        /// General purpose completion
        case general
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
