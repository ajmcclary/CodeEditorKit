import Foundation

// MARK: - PHP Completion Provider

/// Built-in completion provider for PHP language
@MainActor
final class PHPCompletionProvider: BaseCompletionProvider {
    // PHP-specific properties
    let phpSuperglobals = [
        "$GLOBALS", "$_SERVER", "$_GET", "$_POST", "$_FILES", "$_COOKIE",
        "$_SESSION", "$_REQUEST", "$_ENV", "$HTTP_RAW_POST_DATA",
        "$http_response_header", "$argc", "$argv"
    ]

    let phpMagicConstants = [
        "__LINE__", "__FILE__", "__DIR__", "__FUNCTION__", "__CLASS__",
        "__TRAIT__", "__METHOD__", "__NAMESPACE__"
    ]

    let phpBuiltinClasses = [
        "Exception", "ErrorException", "Error", "ParseError", "TypeError",
        "ArgumentCountError", "ArithmeticError", "DivisionByZeroError",
        "DateTime", "DateTimeImmutable", "DateInterval", "DateTimeZone",
        "PDO", "PDOStatement", "PDOException", "mysqli", "mysqli_result",
        "DOMDocument", "DOMElement", "DOMNode", "SimpleXMLElement",
        "ArrayObject", "ArrayIterator", "Iterator", "IteratorAggregate",
        "Countable", "Serializable", "JsonSerializable", "Traversable",
        "ReflectionClass", "ReflectionMethod", "ReflectionProperty",
        "SplFileInfo", "SplFileObject", "DirectoryIterator",
        "RecursiveDirectoryIterator", "RecursiveIteratorIterator"
    ]

    // Override base properties
    override var keywords: [String] {
        [
            "abstract", "and", "array", "as", "break", "callable", "case", "catch",
            "class", "clone", "const", "continue", "declare", "default", "die", "do",
            "echo", "else", "elseif", "empty", "enddeclare", "endfor", "endforeach",
            "endif", "endswitch", "endwhile", "eval", "exit", "extends", "final",
            "finally", "fn", "for", "foreach", "function", "global", "goto", "if",
            "implements", "include", "include_once", "instanceof", "insteadof",
            "interface", "isset", "list", "match", "namespace", "new", "or", "print",
            "private", "protected", "public", "readonly", "require", "require_once",
            "return", "static", "switch", "throw", "trait", "try", "unset", "use",
            "var", "while", "xor", "yield", "yield from", "__halt_compiler",
            // PHP 8 keywords
            "enum", "mixed", "never"
        ]
    }

    override var types: [String] {
        [
            "int", "float", "string", "bool", "array", "object", "callable",
            "iterable", "void", "null", "mixed", "never", "false", "true",
            "self", "parent", "static"
        ]
    }

    override var functions: [String] {
        [
        // String functions
        "strlen", "strpos", "strrpos", "substr", "str_replace", "str_repeat",
        "strtolower", "strtoupper", "ucfirst", "ucwords", "trim", "ltrim",
        "rtrim", "explode", "implode", "join", "split", "preg_match",
        "preg_match_all", "preg_replace", "preg_split", "htmlspecialchars",
        "htmlentities", "strip_tags", "addslashes", "stripslashes",
        // Array functions
        "array_push", "array_pop", "array_shift", "array_unshift", "array_slice",
        "array_splice", "array_merge", "array_combine", "array_keys", "array_values",
        "array_flip", "array_reverse", "array_search", "in_array", "array_key_exists",
        "array_unique", "array_filter", "array_map", "array_reduce", "array_walk",
        "sort", "rsort", "asort", "arsort", "ksort", "krsort", "usort", "count",
        "sizeof", "array_sum", "array_product", "array_diff", "array_intersect",
        // File functions
        "fopen", "fclose", "fread", "fwrite", "fgets", "feof", "file_get_contents",
        "file_put_contents", "file_exists", "is_file", "is_dir", "is_readable",
        "is_writable", "filesize", "filetype", "basename", "dirname", "pathinfo",
        "realpath", "unlink", "rename", "copy", "mkdir", "rmdir", "scandir",
        // Date/Time functions
        "time", "date", "mktime", "strtotime", "getdate", "checkdate",
        "date_create", "date_format", "date_diff", "date_add", "date_sub",
        // Math functions
        "abs", "ceil", "floor", "round", "min", "max", "rand", "mt_rand",
        "sqrt", "pow", "exp", "log", "sin", "cos", "tan", "pi",
        // Variable functions
        "isset", "empty", "is_null", "is_bool", "is_int", "is_float", "is_string",
        "is_array", "is_object", "is_numeric", "is_scalar", "is_callable",
        "var_dump", "print_r", "var_export", "serialize", "unserialize",
        "json_encode", "json_decode",
        // Database functions
        "mysqli_connect", "mysqli_query", "mysqli_fetch_array", "mysqli_fetch_assoc",
        "mysqli_num_rows", "mysqli_close", "mysqli_error", "mysqli_real_escape_string",
        // Other common functions
        "header", "setcookie", "session_start", "session_destroy", "mail",
        "filter_var", "filter_input", "hash", "password_hash", "password_verify"
        ]
    }

    override var snippets: [SnippetTemplate] {
        [
        SnippetTemplate(
            label: "php",
            insertText: "<?php\n${1:// code}\n?>",
            description: "PHP tags"
        ),
        SnippetTemplate(
            label: "echo",
            insertText: "<?= ${1:$variable} ?>",
            description: "PHP echo shorthand"
        ),
        SnippetTemplate(
            label: "class",
            insertText: """
class ${1:ClassName}
{
    ${2:// properties and methods}
}
""",
            description: "Class declaration"
        ),
        SnippetTemplate(
            label: "interface",
            insertText: """
interface ${1:InterfaceName}
{
    ${2:// method signatures}
}
""",
            description: "Interface declaration"
        ),
        SnippetTemplate(
            label: "trait",
            insertText: """
trait ${1:TraitName}
{
    ${2:// methods}
}
""",
            description: "Trait declaration"
        ),
        SnippetTemplate(
            label: "function",
            insertText: """
function ${1:functionName}(${2:$params}): ${3:void}
{
    ${4:// function body}
}
""",
            description: "Function declaration"
        ),
        SnippetTemplate(
            label: "method",
            insertText: """
${1:public} function ${2:methodName}(${3:$params}): ${4:void}
{
    ${5:// method body}
}
""",
            description: "Method declaration"
        ),
        SnippetTemplate(
            label: "construct",
            insertText: """
public function __construct(${1:$params})
{
    ${2:// constructor body}
}
""",
            description: "Constructor method"
        ),
        SnippetTemplate(
            label: "if",
            insertText: """
if (${1:$condition}) {
    ${2:// then}
}
""",
            description: "If statement"
        ),
        SnippetTemplate(
            label: "ifelse",
            insertText: """
if (${1:$condition}) {
    ${2:// then}
} else {
    ${3:// else}
}
""",
            description: "If-else statement"
        ),
        SnippetTemplate(
            label: "foreach",
            insertText: """
foreach (${1:$array} as ${2:$key} => ${3:$value}) {
    ${4:// body}
}
""",
            description: "Foreach loop"
        ),
        SnippetTemplate(
            label: "for",
            insertText: """
for (${1:$i = 0}; ${2:$i < 10}; ${3:$i++}) {
    ${4:// body}
}
""",
            description: "For loop"
        ),
        SnippetTemplate(
            label: "while",
            insertText: """
while (${1:$condition}) {
    ${2:// body}
}
""",
            description: "While loop"
        ),
        SnippetTemplate(
            label: "switch",
            insertText: """
switch (${1:$variable}) {
    case ${2:value1}:
        ${3:// code}
        break;

    case ${4:value2}:
        ${5:// code}
        break;

    default:
        ${6:// default code}
        break;
}
""",
            description: "Switch statement"
        ),
        SnippetTemplate(
            label: "try",
            insertText: """
try {
    ${1:// code}
} catch (${2:Exception} $e) {
    ${3:// handle exception}
}
""",
            description: "Try-catch block"
        ),
        SnippetTemplate(
            label: "namespace",
            insertText: """
namespace ${1:App\\\\Controllers};

use ${2:App\\\\Models\\\\Model};

${3:// code}
""",
            description: "Namespace declaration"
        ),
        SnippetTemplate(
            label: "getter",
            insertText: """
public function get${1:Property}(): ${2:?string}
{
    return $this->${3:property};
}
""",
            description: "Getter method"
        ),
        SnippetTemplate(
            label: "setter",
            insertText: """
public function set${1:Property}(${2:?string} $${3:property}): void
{
    $this->${3:property} = $${3:property};
}
""",
            description: "Setter method"
        )
        ]
    }

    init() {
        super.init(
            id: "php-builtin",
            supportedLanguages: [.php],
            triggerCharacters: ["$", "->", "::", "(", " ", "\\", "<?", "=", "["],
            supportsSnippets: true
        )
    }

    // MARK: - Override CompletionProvider

    override func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()

        // Analyze context to determine what kind of completions to provide
        let analysisResult = analyzePHPContext(context)
        var items: [CompletionItemModel] = []

        // Add appropriate completions based on context
        switch analysisResult.type {
        case .keyword:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))

        case .variable:
            items.append(contentsOf: createVariableCompletions(filter: analysisResult.filter))

        case .function:
            items.append(contentsOf: createFunctionCompletions(filter: analysisResult.filter))

        case .method:
            items.append(contentsOf: createMethodCompletions(for: analysisResult.targetType, filter: analysisResult.filter))

        case .class:
            items.append(contentsOf: createClassCompletions(filter: analysisResult.filter))

        case .type:
            items.append(contentsOf: createTypeCompletions(filter: analysisResult.filter))

        case .namespace:
            items.append(contentsOf: createNamespaceCompletions(filter: analysisResult.filter))

        case .superglobal:
            items.append(contentsOf: createSuperglobalCompletions(filter: analysisResult.filter))

        case .magicConstant:
            items.append(contentsOf: createMagicConstantCompletions(filter: analysisResult.filter))

        case .general:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createFunctionCompletions(filter: analysisResult.filter))
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

    // MARK: - PHP Context Analysis

    private func analyzePHPContext(_ context: CompletionContextModel) -> PHPContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = String(context.text.prefix(context.cursorPosition))

        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)

        // Check for PHP tag context
        if beforeCursor.hasSuffix("<?") {
            return PHPContextAnalysisResult(type: .keyword, filter: "php")
        }

        // Check for variable context
        if beforeCursor.hasSuffix("$") || filter.hasPrefix("$") {
            // Check if it's a superglobal
            if filter.hasPrefix("$_") || filter == "$GLOBALS" {
                return PHPContextAnalysisResult(type: .superglobal, filter: filter)
            }
            return PHPContextAnalysisResult(type: .variable, filter: filter)
        }

        // Check for magic constant context
        if filter.hasPrefix("__") && filter.hasSuffix("__") {
            return PHPContextAnalysisResult(type: .magicConstant, filter: filter)
        }

        // Check for method context (->)
        if beforeCursor.hasSuffix("->") {
            let targetType = extractTargetType(from: beforeCursor, separator: "->")
            return PHPContextAnalysisResult(type: .method, filter: "", targetType: targetType)
        }

        // Check for static method/property context (::)
        if beforeCursor.hasSuffix("::") {
            let targetType = extractTargetType(from: beforeCursor, separator: "::")
            return PHPContextAnalysisResult(type: .class, filter: "", targetType: targetType)
        }

        // Check for namespace context
        if beforeCursor.hasSuffix("\\") || lineText.hasPrefix("use ") || lineText.hasPrefix("namespace ") {
            return PHPContextAnalysisResult(type: .namespace, filter: filter)
        }

        // Check for type hint context
        if isInTypeHintContext(beforeCursor) {
            return PHPContextAnalysisResult(type: .type, filter: filter)
        }

        // Check for function context
        if beforeCursor.hasSuffix("(") || isInFunctionCallContext(beforeCursor) {
            return PHPContextAnalysisResult(type: .function, filter: filter)
        }

        return PHPContextAnalysisResult(type: .general, filter: filter)
    }

    override func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$\\")).inverted)
        return components.last ?? ""
    }

    // PHP-specific method for extracting target type
    private func extractTargetType(from text: String, separator: String) -> String? {
        // Extract the object/class before -> or ::
        let pattern = separator == "->" ? #"(\$\w+)\s*->$"# : #"(\w+)\s*::$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }

    private func isInTypeHintContext(_ text: String) -> Bool {
        // Check if we're in a function parameter or return type context
        let patterns = [
            #"function\s+\w+\s*\([^)]*\s+$"#,  // Function parameter
            #":\s*\??$"#,                        // Return type
            #"^\s*(?:public|private|protected)\s+\??$"# // Property type
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                return true
            }
        }

        return false
    }

    private func isInFunctionCallContext(_ text: String) -> Bool {
        // Check if we're inside parentheses
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

    // MARK: - PHP-Specific Completion Creation Methods

    private func createVariableCompletions(filter: String) -> [CompletionItemModel] {
        // Common variable names
        let commonVariables = [
            "$this", "$self", "$parent", "$result", "$data", "$response", "$request",
            "$user", "$id", "$name", "$value", "$key", "$item", "$array", "$object",
            "$string", "$number", "$file", "$path", "$url", "$error", "$message",
            "$status", "$config", "$options", "$params", "$args", "$output", "$input"
        ]

        return commonVariables
            .filter { variable in
                let filterToUse = filter.hasPrefix("$") ? filter : "$\(filter)"
                return variable.localizedCaseInsensitiveContains(filterToUse)
            }
            .map { variable in
                CompletionItemModel(
                    label: variable,
                    insertText: variable,
                    kind: .variable,
                    detail: "Variable",
                    priority: 70
                )
            }
    }

    override func createFunctionCompletions(filter: String) -> [CompletionItemModel] {
        functions
            .filter { function in
                filter.isEmpty || function.localizedCaseInsensitiveContains(filter)
            }
            .map { function in
                CompletionItemModel(
                    label: function,
                    insertText: "\(function)($0)",
                    kind: .function,
                    detail: "PHP function",
                    priority: 75
                )
            }
    }

    private func createMethodCompletions(for _: String?, filter: String) -> [CompletionItemModel] {
        // Common object methods
        let commonMethods = [
            "getId", "setId", "getName", "setName", "getValue", "setValue",
            "toString", "toArray", "toJson", "save", "delete", "update",
            "find", "findAll", "create", "validate", "render", "redirect",
            "get", "set", "has", "add", "remove", "clear", "count", "isEmpty"
        ]

        return commonMethods
            .filter { method in
                filter.isEmpty || method.localizedCaseInsensitiveContains(filter)
            }
            .map { method in
                let insertText = method.hasPrefix("get") || method.hasPrefix("is") || method.hasPrefix("has") ? "\(method)()" : "\(method)($0)"

                return CompletionItemModel(
                    label: method,
                    insertText: insertText,
                    kind: .method,
                    detail: "Method",
                    priority: 75
                )
            }
    }

    private func createClassCompletions(filter: String) -> [CompletionItemModel] {
        phpBuiltinClasses
            .filter { className in
                filter.isEmpty || className.localizedCaseInsensitiveContains(filter)
            }
            .map { className in
                CompletionItemModel(
                    label: className,
                    insertText: className,
                    kind: .class,
                    detail: "PHP class",
                    priority: 70
                )
            }
    }

    private func createNamespaceCompletions(filter: String) -> [CompletionItemModel] {
        // Common PHP namespaces
        let commonNamespaces = [
            "App", "App\\Controllers", "App\\Models", "App\\Views", "App\\Services",
            "App\\Helpers", "App\\Middleware", "App\\Exceptions", "App\\Providers",
            "Illuminate", "Symfony", "Doctrine", "Twig", "Monolog", "Guzzle",
            "PHPUnit", "Carbon", "League", "Psr"
        ]

        return commonNamespaces
            .filter { namespace in
                filter.isEmpty || namespace.localizedCaseInsensitiveContains(filter)
            }
            .map { namespace in
                CompletionItemModel(
                    label: namespace,
                    insertText: namespace.replacingOccurrences(of: "\\", with: "\\\\"),
                    kind: .module,
                    detail: "Namespace",
                    priority: 70
                )
            }
    }

    private func createSuperglobalCompletions(filter: String) -> [CompletionItemModel] {
        phpSuperglobals
            .filter { superglobal in
                let filterToUse = filter.hasPrefix("$") ? filter : "$\(filter)"
                return superglobal.localizedCaseInsensitiveContains(filterToUse)
            }
            .map { superglobal in
                let insertText = superglobal.hasSuffix("]") ? superglobal : "\(superglobal)['$0']"

                return CompletionItemModel(
                    label: superglobal,
                    insertText: insertText,
                    kind: .variable,
                    detail: "PHP superglobal",
                    priority: 85
                )
            }
    }

    private func createMagicConstantCompletions(filter: String) -> [CompletionItemModel] {
        phpMagicConstants
            .filter { constant in
                filter.isEmpty || constant.localizedCaseInsensitiveContains(filter)
            }
            .map { constant in
                CompletionItemModel(
                    label: constant,
                    insertText: constant,
                    kind: .constant,
                    detail: "Magic constant",
                    priority: 80
                )
            }
    }
}

// MARK: - Supporting Types

private struct PHPContextAnalysisResult {
    enum CompletionType {
        case keyword
        case variable
        case function
        case method
        case `class`
        case type
        case namespace
        case superglobal
        case magicConstant
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
