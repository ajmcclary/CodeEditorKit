import Foundation

// MARK: - Language Static Metadata

/// Centralized static metadata for all supported programming languages
/// This consolidates language-specific data to eliminate duplicate switch statements
/// across completion providers, syntax highlighters, and language detection
internal struct LanguageStaticMetadata: Sendable {
    // MARK: - Basic Properties

    /// Display name for the language
    let name: String

    /// File extensions associated with this language
    let fileExtensions: [String]

    /// Language Server Protocol identifier
    let lspIdentifier: String

    /// Highlighting strategy to use
    let highlightingStrategy: HighlightingStrategy

    // MARK: - Syntax Properties

    /// Single-line comment prefix (e.g., "//", "#")
    let commentPrefix: String?

    /// Multi-line comment start (e.g., "/*")
    let blockCommentStart: String?

    /// Multi-line comment end (e.g., "*/")
    let blockCommentEnd: String?

    /// Regex pattern for valid identifiers
    let identifierPattern: String

    /// Characters that delimit strings
    let stringDelimiters: [Character]

    // MARK: - Completion Properties

    /// Language keywords
    let keywords: [String]

    /// Built-in types
    let types: [String]

    /// Built-in functions
    let functions: [String]

    /// Literal values (true, false, nil, etc.)
    let literals: [String]

    /// Characters that trigger completion
    let triggerCharacters: [String]

    // MARK: - Static Metadata for All Languages

    /// Complete metadata dictionary for all supported languages
    static let all: [Language: Self] = [
        .swift: Self(
            name: "Swift",
            fileExtensions: ["swift"],
            lspIdentifier: "swift",
            highlightingStrategy: .swiftSyntax,
            commentPrefix: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\""],
            keywords: [
                "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func",
                "import", "init", "inout", "internal", "let", "operator", "private", "protocol",
                "public", "static", "struct", "subscript", "typealias", "var", "break", "case",
                "continue", "default", "defer", "do", "else", "fallthrough", "for", "guard",
                "if", "in", "repeat", "return", "switch", "where", "while", "as", "any", "catch",
                "false", "is", "nil", "rethrows", "super", "self", "Self", "throw", "throws",
                "true", "try", "async", "await", "actor", "@MainActor", "@Sendable"
            ],
            types: [
                "Int", "UInt", "Int8", "Int16", "Int32", "Int64", "UInt8", "UInt16", "UInt32",
                "UInt64", "Float", "Double", "Bool", "String", "Character", "Array", "Dictionary",
                "Set", "Optional", "AnyObject", "AnyClass", "Any", "Void", "Never", "Result",
                "Task", "AsyncStream", "MainActor"
            ],
            functions: [
                "print", "debugPrint", "dump", "assert", "assertionFailure", "precondition",
                "preconditionFailure", "fatalError", "abs", "min", "max", "swap", "stride",
                "zip", "enumerated", "reversed", "sorted", "map", "filter", "reduce", "forEach",
                "compactMap", "flatMap", "first", "last"
            ],
            literals: [
                "true", "false", "nil", "self", "Self", "super", "#file", "#line", "#column",
                "#function"
            ],
            triggerCharacters: [".", "(", "[", "<", " ", ":"]
        ),

        .javascript: Self(
            name: "JavaScript",
            fileExtensions: ["js", "jsx", "mjs"],
            lspIdentifier: "javascript",
            highlightingStrategy: .regex,
            commentPrefix: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_$][a-zA-Z0-9_$]*",
            stringDelimiters: ["\"", "'", "`"],
            keywords: [
                "const", "let", "var", "function", "class", "if", "else", "for", "while", "do",
                "switch", "case", "default", "break", "continue", "return", "try", "catch",
                "finally", "throw", "async", "await", "import", "export", "from", "as", "typeof",
                "instanceof", "new", "this", "super", "static", "extends", "constructor", "get",
                "set", "of", "in", "delete", "void", "yield", "debugger", "with"
            ],
            types: [
                "Object", "Array", "String", "Number", "Boolean", "Function", "Symbol", "Date",
                "RegExp", "Error", "Math", "JSON", "console", "Promise", "Map", "Set", "WeakMap",
                "WeakSet", "Proxy", "Reflect", "BigInt"
            ],
            functions: [
                "parseInt", "parseFloat", "isNaN", "isFinite", "encodeURI", "decodeURI",
                "encodeURIComponent", "decodeURIComponent", "eval", "setTimeout", "clearTimeout",
                "setInterval", "clearInterval", "fetch", "alert", "confirm", "prompt"
            ],
            literals: [
                "true", "false", "null", "undefined", "NaN", "Infinity", "globalThis", "window",
                "document"
            ],
            triggerCharacters: [".", "(", "[", "{", " ", ":"]
        ),

        .typescript: Self(
            name: "TypeScript",
            fileExtensions: ["ts", "tsx"],
            lspIdentifier: "typescript",
            highlightingStrategy: .regex,
            commentPrefix: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_$][a-zA-Z0-9_$]*",
            stringDelimiters: ["\"", "'", "`"],
            keywords: [
                "const", "let", "var", "function", "class", "if", "else", "for", "while", "do",
                "switch", "case", "default", "break", "continue", "return", "try", "catch",
                "finally", "throw", "async", "await", "import", "export", "from", "as", "typeof",
                "instanceof", "new", "this", "super", "static", "extends", "constructor", "get",
                "set", "of", "in", "delete", "void", "yield", "debugger", "type", "interface",
                "enum", "namespace", "module", "declare", "readonly", "abstract", "implements",
                "keyof", "never", "unknown", "any", "private", "protected", "public"
            ],
            types: [
                "string", "number", "boolean", "object", "undefined", "null", "void", "never",
                "unknown", "any", "Array", "Object", "Function", "Date", "RegExp", "Promise",
                "Map", "Set", "Record", "Partial", "Required", "Pick", "Omit", "Exclude",
                "Extract", "NonNullable", "ReturnType", "Parameters"
            ],
            functions: [
                "parseInt", "parseFloat", "isNaN", "isFinite", "encodeURI", "decodeURI",
                "setTimeout", "clearTimeout", "setInterval", "clearInterval", "fetch",
                "console.log", "console.error", "JSON.parse", "JSON.stringify"
            ],
            literals: [
                "true", "false", "null", "undefined", "NaN", "Infinity", "this", "super"
            ],
            triggerCharacters: [".", "(", "[", "{", " ", ":", "<"]
        ),

        .python: Self(
            name: "Python",
            fileExtensions: ["py", "pyw"],
            lspIdentifier: "python",
            highlightingStrategy: .regex,
            commentPrefix: "#",
            blockCommentStart: "\"\"\"",
            blockCommentEnd: "\"\"\"",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\"", "'"],
            keywords: [
                "def", "class", "if", "elif", "else", "for", "while", "try", "except", "finally",
                "with", "as", "import", "from", "return", "yield", "break", "continue", "pass",
                "global", "nonlocal", "lambda", "and", "or", "not", "in", "is", "del", "async",
                "await", "assert", "raise", "match", "case"
            ],
            types: [
                "int", "float", "str", "bool", "list", "tuple", "dict", "set", "frozenset",
                "bytes", "bytearray", "memoryview", "range", "complex", "type", "object",
                "property", "staticmethod", "classmethod", "super"
            ],
            functions: [
                "print", "input", "len", "range", "enumerate", "zip", "map", "filter", "sorted",
                "reversed", "sum", "min", "max", "any", "all", "abs", "round", "pow", "divmod",
                "isinstance", "issubclass", "hasattr", "getattr", "setattr", "delattr", "open",
                "format", "chr", "ord", "bin", "hex", "oct", "eval", "exec", "compile", "globals",
                "locals", "vars", "dir", "help", "id", "hash", "iter", "next", "callable", "repr"
            ],
            literals: [
                "True", "False", "None", "self", "cls", "__name__", "__main__", "__file__"
            ],
            triggerCharacters: [".", "(", "[", " ", ":"]
        ),

        .rust: Self(
            name: "Rust",
            fileExtensions: ["rs"],
            lspIdentifier: "rust",
            highlightingStrategy: .regex,
            commentPrefix: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\""],
            keywords: [
                "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else",
                "enum", "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop",
                "match", "mod", "move", "mut", "pub", "ref", "return", "self", "Self", "static",
                "struct", "super", "trait", "true", "type", "unsafe", "use", "where", "while"
            ],
            types: [
                "bool", "char", "f32", "f64", "i8", "i16", "i32", "i64", "i128", "isize", "str",
                "u8", "u16", "u32", "u64", "u128", "usize", "String", "Vec", "HashMap", "HashSet",
                "Option", "Result", "Box", "Rc", "Arc", "RefCell", "Mutex", "RwLock", "Cell"
            ],
            functions: [
                "println!", "print!", "eprintln!", "eprint!", "format!", "write!", "writeln!",
                "panic!", "assert!", "assert_eq!", "assert_ne!", "debug_assert!", "vec!",
                "include!", "include_str!", "include_bytes!", "concat!", "env!", "todo!",
                "unimplemented!", "unreachable!", "dbg!"
            ],
            literals: [
                "true", "false", "None", "Some", "Ok", "Err"
            ],
            triggerCharacters: [".", "::", "(", "<", " ", "!"]
        ),

        .go: Self(
            name: "Go",
            fileExtensions: ["go"],
            lspIdentifier: "go",
            highlightingStrategy: .regex,
            commentPrefix: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\"", "`"],
            keywords: [
                "break", "case", "chan", "const", "continue", "default", "defer", "else",
                "fallthrough", "for", "func", "go", "goto", "if", "import", "interface", "map",
                "package", "range", "return", "select", "struct", "switch", "type", "var"
            ],
            types: [
                "bool", "byte", "complex64", "complex128", "error", "float32", "float64", "int",
                "int8", "int16", "int32", "int64", "rune", "string", "uint", "uint8", "uint16",
                "uint32", "uint64", "uintptr"
            ],
            functions: [
                "make", "new", "append", "copy", "delete", "len", "cap", "close", "panic",
                "recover", "print", "println", "complex", "real", "imag", "min", "max"
            ],
            literals: [
                "true", "false", "iota", "nil"
            ],
            triggerCharacters: [".", "(", "[", " ", ":"]
        ),

        .c: Self(
            name: "C",
            fileExtensions: ["c", "h"],
            lspIdentifier: "c",
            highlightingStrategy: .regex,
            commentPrefix: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\""],
            keywords: [
                "auto", "break", "case", "char", "const", "continue", "default", "do", "double",
                "else", "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long",
                "register", "restrict", "return", "short", "signed", "sizeof", "static", "struct",
                "switch", "typedef", "union", "unsigned", "void", "volatile", "while", "_Bool",
                "_Complex", "_Imaginary"
            ],
            types: [
                "int", "char", "float", "double", "void", "short", "long", "signed", "unsigned",
                "size_t", "ptrdiff_t", "intptr_t", "uintptr_t", "int8_t", "int16_t", "int32_t",
                "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "bool"
            ],
            functions: [
                "printf", "scanf", "malloc", "free", "realloc", "calloc", "memcpy", "memset",
                "strlen", "strcpy", "strcmp", "strcat", "fopen", "fclose", "fread", "fwrite",
                "fprintf", "fscanf", "exit", "abort", "assert"
            ],
            literals: [
                "NULL", "true", "false", "stdin", "stdout", "stderr"
            ],
            triggerCharacters: [".", "->", "(", " "]
        ),

        .cpp: Self(
            name: "C++",
            fileExtensions: ["cpp", "cc", "cxx", "hpp", "hh", "hxx"],
            lspIdentifier: "cpp",
            highlightingStrategy: .regex,
            commentPrefix: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\""],
            keywords: [
                "alignas", "alignof", "and", "and_eq", "asm", "auto", "bitand", "bitor", "bool",
                "break", "case", "catch", "char", "char8_t", "char16_t", "char32_t", "class",
                "compl", "concept", "const", "consteval", "constexpr", "constinit", "const_cast",
                "continue", "co_await", "co_return", "co_yield", "decltype", "default", "delete",
                "do", "double", "dynamic_cast", "else", "enum", "explicit", "export", "extern",
                "false", "float", "for", "friend", "goto", "if", "inline", "int", "long",
                "mutable", "namespace", "new", "noexcept", "not", "not_eq", "nullptr", "operator",
                "or", "or_eq", "private", "protected", "public", "register", "reinterpret_cast",
                "requires", "return", "short", "signed", "sizeof", "static", "static_assert",
                "static_cast", "struct", "switch", "template", "this", "thread_local", "throw",
                "true", "try", "typedef", "typeid", "typename", "union", "unsigned", "using",
                "virtual", "void", "volatile", "wchar_t", "while", "xor", "xor_eq"
            ],
            types: [
                "string", "vector", "map", "set", "unordered_map", "unordered_set", "list",
                "deque", "queue", "stack", "array", "pair", "tuple", "optional", "variant",
                "any", "span", "string_view", "unique_ptr", "shared_ptr", "weak_ptr"
            ],
            functions: [
                "std::cout", "std::cin", "std::endl", "std::move", "std::forward", "std::make_unique",
                "std::make_shared", "std::swap", "std::sort", "std::find", "std::transform",
                "std::accumulate", "std::copy", "std::fill"
            ],
            literals: [
                "true", "false", "nullptr", "NULL", "this"
            ],
            triggerCharacters: [".", "->", "::", "(", "<", " "]
        ),

        .java: Self(
            name: "Java",
            fileExtensions: ["java"],
            lspIdentifier: "java",
            highlightingStrategy: .regex,
            commentPrefix: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_$][a-zA-Z0-9_$]*",
            stringDelimiters: ["\""],
            keywords: [
                "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char",
                "class", "const", "continue", "default", "do", "double", "else", "enum",
                "extends", "final", "finally", "float", "for", "goto", "if", "implements",
                "import", "instanceof", "int", "interface", "long", "native", "new", "package",
                "private", "protected", "public", "return", "short", "static", "strictfp",
                "super", "switch", "synchronized", "this", "throw", "throws", "transient",
                "try", "void", "volatile", "while", "var", "record", "sealed", "permits", "yield"
            ],
            types: [
                "String", "Integer", "Long", "Double", "Float", "Boolean", "Character", "Byte",
                "Short", "Object", "Class", "ArrayList", "HashMap", "HashSet", "LinkedList",
                "TreeMap", "TreeSet", "Optional", "Stream", "List", "Map", "Set", "Collection"
            ],
            functions: [
                "System.out.println", "System.out.print", "System.err.println", "String.valueOf",
                "Integer.parseInt", "Double.parseDouble", "Arrays.asList", "Collections.sort",
                "Objects.equals", "Objects.requireNonNull"
            ],
            literals: [
                "true", "false", "null", "this", "super"
            ],
            triggerCharacters: [".", "(", " ", "@"]
        ),

        .html: Self(
            name: "HTML",
            fileExtensions: ["html", "htm", "xhtml"],
            lspIdentifier: "html",
            highlightingStrategy: .regex,
            commentPrefix: nil,
            blockCommentStart: "<!--",
            blockCommentEnd: "-->",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_-]*",
            stringDelimiters: ["\"", "'"],
            keywords: [
                "html", "head", "body", "title", "meta", "link", "script", "style", "div", "span",
                "p", "a", "img", "ul", "ol", "li", "table", "tr", "td", "th", "form", "input",
                "button", "select", "option", "textarea", "label", "header", "footer", "nav",
                "main", "section", "article", "aside", "h1", "h2", "h3", "h4", "h5", "h6"
            ],
            types: [],
            functions: [],
            literals: [],
            triggerCharacters: ["<", " ", "=", "\"", "'"]
        ),

        .css: Self(
            name: "CSS",
            fileExtensions: ["css", "scss", "sass", "less"],
            lspIdentifier: "css",
            highlightingStrategy: .regex,
            commentPrefix: nil,
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_-][a-zA-Z0-9_-]*",
            stringDelimiters: ["\"", "'"],
            keywords: [
                "color", "background", "background-color", "margin", "padding", "border", "width",
                "height", "font", "font-size", "font-family", "font-weight", "display", "position",
                "top", "right", "bottom", "left", "flex", "grid", "align-items", "justify-content",
                "z-index", "opacity", "visibility", "overflow", "text-align", "text-decoration",
                "line-height", "box-shadow", "border-radius", "transition", "transform", "animation"
            ],
            types: [],
            functions: [
                "rgb", "rgba", "hsl", "hsla", "url", "var", "calc", "min", "max", "clamp",
                "linear-gradient", "radial-gradient", "translate", "rotate", "scale"
            ],
            literals: [
                "inherit", "initial", "unset", "none", "auto", "normal", "bold", "italic",
                "underline", "solid", "dashed", "dotted", "block", "inline", "inline-block",
                "flex", "grid", "absolute", "relative", "fixed", "sticky"
            ],
            triggerCharacters: [":", " ", ";", "{"]
        ),

        .json: Self(
            name: "JSON",
            fileExtensions: ["json", "jsonc"],
            lspIdentifier: "json",
            highlightingStrategy: .fastJSON,
            commentPrefix: nil,
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\""],
            keywords: [],
            types: [],
            functions: [],
            literals: ["true", "false", "null"],
            triggerCharacters: [":", " ", "\""]
        ),

        .markdown: Self(
            name: "Markdown",
            fileExtensions: ["md", "markdown", "mdown", "mkd"],
            lspIdentifier: "markdown",
            highlightingStrategy: .regex,
            commentPrefix: nil,
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: [],
            keywords: [],
            types: [],
            functions: [],
            literals: [],
            triggerCharacters: ["[", "(", " "]
        ),

        .yaml: Self(
            name: "YAML",
            fileExtensions: ["yaml", "yml"],
            lspIdentifier: "yaml",
            highlightingStrategy: .regex,
            commentPrefix: "#",
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\"", "'"],
            keywords: [],
            types: [],
            functions: [],
            literals: ["true", "false", "null", "yes", "no", "on", "off"],
            triggerCharacters: [":", " "]
        ),

        .xml: Self(
            name: "XML",
            fileExtensions: ["xml", "xsl", "xslt", "svg"],
            lspIdentifier: "xml",
            highlightingStrategy: .regex,
            commentPrefix: nil,
            blockCommentStart: "<!--",
            blockCommentEnd: "-->",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_:-]*",
            stringDelimiters: ["\"", "'"],
            keywords: [],
            types: [],
            functions: [],
            literals: [],
            triggerCharacters: ["<", " ", "=", "\"", "'"]
        ),

        .sql: Self(
            name: "SQL",
            fileExtensions: ["sql"],
            lspIdentifier: "sql",
            highlightingStrategy: .regex,
            commentPrefix: "--",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["'"],
            keywords: [
                "SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE",
                "CREATE", "TABLE", "DROP", "ALTER", "INDEX", "VIEW", "JOIN", "INNER", "LEFT",
                "RIGHT", "OUTER", "ON", "AND", "OR", "NOT", "NULL", "IS", "IN", "LIKE", "BETWEEN",
                "ORDER", "BY", "GROUP", "HAVING", "LIMIT", "OFFSET", "UNION", "ALL", "DISTINCT",
                "AS", "CASE", "WHEN", "THEN", "ELSE", "END", "PRIMARY", "KEY", "FOREIGN",
                "REFERENCES", "CONSTRAINT", "DEFAULT", "AUTO_INCREMENT", "UNIQUE", "CHECK"
            ],
            types: [
                "INT", "INTEGER", "BIGINT", "SMALLINT", "TINYINT", "FLOAT", "DOUBLE", "DECIMAL",
                "NUMERIC", "CHAR", "VARCHAR", "TEXT", "DATE", "TIME", "DATETIME", "TIMESTAMP",
                "BOOLEAN", "BLOB", "CLOB", "JSON"
            ],
            functions: [
                "COUNT", "SUM", "AVG", "MIN", "MAX", "CONCAT", "SUBSTRING", "LENGTH", "UPPER",
                "LOWER", "TRIM", "COALESCE", "NULLIF", "CAST", "CONVERT", "NOW", "CURRENT_DATE",
                "CURRENT_TIME", "CURRENT_TIMESTAMP"
            ],
            literals: ["TRUE", "FALSE", "NULL"],
            triggerCharacters: [" ", "(", ","]
        ),

        .ruby: Self(
            name: "Ruby",
            fileExtensions: ["rb", "rbw"],
            lspIdentifier: "ruby",
            highlightingStrategy: .regex,
            commentPrefix: "#",
            blockCommentStart: "=begin",
            blockCommentEnd: "=end",
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\"", "'"],
            keywords: [
                "def", "class", "module", "end", "if", "elsif", "else", "unless", "case", "when",
                "while", "until", "for", "do", "begin", "rescue", "ensure", "raise", "return",
                "yield", "break", "next", "redo", "retry", "super", "self", "nil", "true", "false",
                "and", "or", "not", "in", "then", "alias", "defined?", "attr_reader", "attr_writer",
                "attr_accessor", "require", "require_relative", "include", "extend", "prepend"
            ],
            types: [
                "String", "Integer", "Float", "Array", "Hash", "Symbol", "Range", "Regexp",
                "Time", "File", "IO", "Class", "Module", "Object", "Proc", "Lambda"
            ],
            functions: [
                "puts", "print", "p", "gets", "chomp", "to_s", "to_i", "to_f", "to_a", "to_h",
                "length", "size", "empty?", "nil?", "is_a?", "respond_to?", "each", "map",
                "select", "reject", "find", "reduce", "inject", "sort", "reverse", "join", "split"
            ],
            literals: ["true", "false", "nil", "self", "__FILE__", "__LINE__", "__dir__"],
            triggerCharacters: [".", "(", " ", ":"]
        ),

        .php: Self(
            name: "PHP",
            fileExtensions: ["php", "phtml", "php3", "php4", "php5"],
            lspIdentifier: "php",
            highlightingStrategy: .regex,
            commentPrefix: "//",
            blockCommentStart: "/*",
            blockCommentEnd: "*/",
            identifierPattern: "[a-zA-Z_\\x80-\\xff][a-zA-Z0-9_\\x80-\\xff]*",
            stringDelimiters: ["\"", "'"],
            keywords: [
                "abstract", "and", "array", "as", "break", "callable", "case", "catch", "class",
                "clone", "const", "continue", "declare", "default", "die", "do", "echo", "else",
                "elseif", "empty", "enddeclare", "endfor", "endforeach", "endif", "endswitch",
                "endwhile", "eval", "exit", "extends", "final", "finally", "fn", "for", "foreach",
                "function", "global", "goto", "if", "implements", "include", "include_once",
                "instanceof", "insteadof", "interface", "isset", "list", "match", "namespace",
                "new", "or", "print", "private", "protected", "public", "require", "require_once",
                "return", "static", "switch", "throw", "trait", "try", "unset", "use", "var",
                "while", "xor", "yield"
            ],
            types: [
                "string", "int", "float", "bool", "array", "object", "callable", "iterable",
                "void", "null", "mixed", "never"
            ],
            functions: [
                "echo", "print", "var_dump", "print_r", "isset", "empty", "unset", "strlen",
                "substr", "str_replace", "strpos", "explode", "implode", "array_push",
                "array_pop", "array_shift", "array_unshift", "array_merge", "array_map",
                "array_filter", "array_reduce", "count", "sizeof", "in_array", "array_key_exists"
            ],
            literals: ["true", "false", "null", "$this", "self", "parent"],
            triggerCharacters: [".", "->", "::", "$", " "]
        ),

        .shell: Self(
            name: "Shell",
            fileExtensions: ["sh", "bash", "zsh", "fish"],
            lspIdentifier: "shellscript",
            highlightingStrategy: .regex,
            commentPrefix: "#",
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\"", "'"],
            keywords: [
                "if", "then", "else", "elif", "fi", "case", "esac", "for", "while", "until", "do",
                "done", "in", "function", "return", "local", "export", "readonly", "declare",
                "typeset", "unset", "shift", "source", "alias", "unalias", "true", "false",
                "break", "continue", "exit", "trap", "eval", "exec"
            ],
            types: [],
            functions: [
                "echo", "printf", "read", "cd", "pwd", "ls", "cat", "grep", "sed", "awk", "find",
                "xargs", "sort", "uniq", "wc", "head", "tail", "cut", "tr", "mkdir", "rm", "cp",
                "mv", "chmod", "chown", "test", "expr"
            ],
            literals: ["true", "false", "$HOME", "$USER", "$PATH", "$PWD", "$?", "$$", "$0"],
            triggerCharacters: [" ", "$", "-"]
        ),

        .dockerfile: Self(
            name: "Dockerfile",
            fileExtensions: ["dockerfile"],
            lspIdentifier: "dockerfile",
            highlightingStrategy: .regex,
            commentPrefix: "#",
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\""],
            keywords: [
                "FROM", "RUN", "CMD", "ENTRYPOINT", "COPY", "ADD", "WORKDIR", "ENV",
                "ARG", "EXPOSE", "VOLUME", "USER", "LABEL", "MAINTAINER", "ONBUILD",
                "STOPSIGNAL", "HEALTHCHECK", "SHELL", "AS"
            ],
            types: [],
            functions: [],
            literals: [],
            triggerCharacters: [" ", "$"]
        ),

        .plainText: Self(
            name: "Plain Text",
            fileExtensions: ["txt", "text", "log"],
            lspIdentifier: "plaintext",
            highlightingStrategy: .noHighlighting,
            commentPrefix: nil,
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: [],
            keywords: [],
            types: [],
            functions: [],
            literals: [],
            triggerCharacters: []
        )
    ]

    // MARK: - Convenience Methods

    /// Gets metadata for a specific language
    static func metadata(for language: Language) -> Self? {
        all[language]
    }

    /// Gets the highlighting strategy for a language
    static func highlightingStrategy(for language: Language) -> HighlightingStrategy {
        all[language]?.highlightingStrategy ?? .noHighlighting
    }

    /// Gets all keywords for a language
    static func keywords(for language: Language) -> [String] {
        all[language]?.keywords ?? []
    }
}
