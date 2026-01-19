import Foundation

// MARK: - Ruby Completion Provider

/// Built-in completion provider for Ruby language
///
/// - Important: This individual provider is deprecated. Use `LanguageProviderFactory.createProvider(for: .ruby)`
///   which returns a `UniversalCompletionProvider` with centralized metadata from `LanguageStaticMetadata`.
@available(*, deprecated, message: "Use LanguageProviderFactory.createProvider(for: .ruby) instead")
@MainActor
public final class RubyCompletionProvider: BaseCompletionProvider {
    // MARK: - Language Elements

    override public var keywords: [String] {
        [
            "alias", "and", "begin", "break", "case", "class", "def", "defined?",
            "do", "else", "elsif", "end", "ensure", "false", "for", "if", "in",
            "module", "next", "nil", "not", "or", "redo", "rescue", "retry",
            "return", "self", "super", "then", "true", "undef", "unless", "until",
            "when", "while", "yield", "__FILE__", "__LINE__", "__ENCODING__"
        ]
    }

    override public var types: [String] {
        // Ruby built-in classes
        [
            "Array", "BasicObject", "Binding", "Class", "Complex", "Dir", "Encoding",
            "Enumerator", "Exception", "FalseClass", "Fiber", "File", "Float",
            "Hash", "Integer", "IO", "Kernel", "MatchData", "Method", "Module",
            "NilClass", "Numeric", "Object", "Proc", "Range", "Rational", "Regexp",
            "String", "Struct", "Symbol", "Thread", "Time", "TracePoint", "TrueClass",
            "UnboundMethod", "StandardError", "RuntimeError", "ArgumentError",
            "IndexError", "KeyError", "NameError", "NoMethodError", "TypeError"
        ] + [
            // Ruby modules (also act as types)
            "Comparable", "Enumerable", "Errno", "FileUtils", "Find", "GC", "JSON",
            "Kernel", "Marshal", "Math", "ObjectSpace", "Open3", "Process", "Signal",
            "Singleton", "Warning"
        ]
    }

    override public var functions: [String] {
        // Common Ruby methods
        [
        // Object methods
        "new", "initialize", "class", "is_a?", "kind_of?", "instance_of?",
        "respond_to?", "send", "public_send", "method", "methods", "nil?",
        "empty?", "blank?", "present?", "tap", "try", "to_s", "to_i", "to_f",
        "to_a", "to_h", "inspect", "dup", "clone", "freeze", "frozen?",
        // Array methods
        "each", "map", "select", "reject", "find", "detect", "collect", "inject",
        "reduce", "all?", "any?", "none?", "one?", "first", "last", "push",
        "pop", "shift", "unshift", "insert", "delete", "delete_at", "compact",
        "flatten", "uniq", "sort", "sort_by", "reverse", "shuffle", "sample",
        "join", "split", "slice", "take", "drop", "zip", "transpose",
        // Hash methods
        "keys", "values", "has_key?", "has_value?", "key?", "value?", "fetch",
        "store", "delete", "merge", "merge!", "update", "transform_keys",
        "transform_values", "select", "reject", "compact", "invert",
        // String methods
        "length", "size", "empty?", "include?", "start_with?", "end_with?",
        "match", "scan", "gsub", "gsub!", "sub", "sub!", "upcase", "downcase",
        "capitalize", "swapcase", "strip", "lstrip", "rstrip", "chomp", "chop",
        "squeeze", "tr", "count", "index", "rindex", "partition", "rpartition",
        // Enumerable methods
        "each_with_index", "each_with_object", "map", "flat_map", "filter_map",
        "find_all", "reject", "partition", "group_by", "sort", "sort_by",
        "min", "max", "minmax", "min_by", "max_by", "minmax_by"
        ]
    }

    // Rails-specific methods (common in Ruby development)
    private let railsMethods = [
        "validates", "validates_presence_of", "validates_uniqueness_of",
        "belongs_to", "has_many", "has_one", "has_and_belongs_to_many",
        "before_action", "after_action", "around_action", "before_save",
        "after_save", "before_create", "after_create", "before_destroy",
        "after_destroy", "scope", "default_scope", "where", "order", "limit",
        "offset", "includes", "joins", "find_by", "find_or_create_by",
        "create", "update", "destroy", "save", "save!", "valid?", "errors",
        "render", "redirect_to", "params", "session", "cookies", "flash",
        "respond_to", "format"
    ]

    override public var literals: [String] {
        ["true", "false", "nil", "self", "super", "__FILE__", "__LINE__", "__ENCODING__"]
    }

    // Ruby global variables
    private let globalVariables = [
        "$!", "$@", "$&", "$`", "$'", "$+", "$1", "$2", "$3", "$4", "$5",
        "$6", "$7", "$8", "$9", "$~", "$=", "$/", "$\\", "$,", "$;", "$.",
        "$<", "$>", "$_", "$0", "$*", "$$", "$?", "$:", "$\"", "$LOAD_PATH",
        "$LOADED_FEATURES", "$DEBUG", "$FILENAME", "$PROGRAM_NAME", "$SAFE",
        "$stdin", "$stdout", "$stderr", "$VERBOSE", "$-0", "$-a", "$-d",
        "$-F", "$-i", "$-I", "$-l", "$-p", "$-v", "$-w"
    ]

    override public var snippets: [SnippetTemplate] {
        [
        SnippetTemplate(
            label: "class",
            insertText: """
class ${1:ClassName}
  ${2:# class body}
end
""",
            description: "Class definition"
        ),
        SnippetTemplate(
            label: "module",
            insertText: """
module ${1:ModuleName}
  ${2:# module body}
end
""",
            description: "Module definition"
        ),
        SnippetTemplate(
            label: "def",
            insertText: """
def ${1:method_name}(${2:args})
  ${3:# method body}
end
""",
            description: "Method definition"
        ),
        SnippetTemplate(
            label: "initialize",
            insertText: """
def initialize(${1:args})
  ${2:# constructor}
end
""",
            description: "Constructor method"
        ),
        SnippetTemplate(
            label: "attr",
            insertText: "attr_${1:accessor} :${2:attribute}",
            description: "Attribute accessor"
        ),
        SnippetTemplate(
            label: "if",
            insertText: """
if ${1:condition}
  ${2:# then}
end
""",
            description: "If statement"
        ),
        SnippetTemplate(
            label: "unless",
            insertText: """
unless ${1:condition}
  ${2:# then}
end
""",
            description: "Unless statement"
        ),
        SnippetTemplate(
            label: "case",
            insertText: """
case ${1:expression}
when ${2:value1}
  ${3:# code}
when ${4:value2}
  ${5:# code}
else
  ${6:# default}
end
""",
            description: "Case statement"
        ),
        SnippetTemplate(
            label: "while",
            insertText: """
while ${1:condition}
  ${2:# body}
end
""",
            description: "While loop"
        ),
        SnippetTemplate(
            label: "until",
            insertText: """
until ${1:condition}
  ${2:# body}
end
""",
            description: "Until loop"
        ),
        SnippetTemplate(
            label: "for",
            insertText: """
for ${1:item} in ${2:collection}
  ${3:# body}
end
""",
            description: "For loop"
        ),
        SnippetTemplate(
            label: "each",
            insertText: """
${1:collection}.each do |${2:item}|
  ${3:# body}
end
""",
            description: "Each iterator"
        ),
        SnippetTemplate(
            label: "map",
            insertText: """
${1:collection}.map { |${2:item}| ${3:# transform} }
""",
            description: "Map iterator"
        ),
        SnippetTemplate(
            label: "select",
            insertText: """
${1:collection}.select { |${2:item}| ${3:# condition} }
""",
            description: "Select iterator"
        ),
        SnippetTemplate(
            label: "begin",
            insertText: """
begin
  ${1:# code}
rescue ${2:StandardError} => e
  ${3:# handle error}
ensure
  ${4:# cleanup}
end
""",
            description: "Exception handling"
        ),
        SnippetTemplate(
            label: "lambda",
            insertText: "lambda { |${1:args}| ${2:# body} }",
            description: "Lambda expression"
        ),
        SnippetTemplate(
            label: "proc",
            insertText: "Proc.new { |${1:args}| ${2:# body} }",
            description: "Proc object"
        ),
        SnippetTemplate(
            label: "block",
            insertText: """
do |${1:args}|
  ${2:# body}
end
""",
            description: "Block syntax"
        ),
        SnippetTemplate(
            label: "require",
            insertText: "require '${1:library}'",
            description: "Require statement"
        ),
        SnippetTemplate(
            label: "test",
            insertText: """
describe '${1:description}' do
  it '${2:does something}' do
    ${3:# test code}
  end
end
""",
            description: "RSpec test"
        )
        ]
    }

    // MARK: - Computed Properties for Completion

    private var builtinClasses: [String] {
        // Extract classes from types (first part of the types array)
        [
            "Array", "BasicObject", "Binding", "Class", "Complex", "Dir", "Encoding",
            "Enumerator", "Exception", "FalseClass", "Fiber", "File", "Float",
            "Hash", "Integer", "IO", "Kernel", "MatchData", "Method", "Module",
            "NilClass", "Numeric", "Object", "Proc", "Range", "Rational", "Regexp",
            "String", "Struct", "Symbol", "Thread", "Time", "TracePoint", "TrueClass",
            "UnboundMethod", "StandardError", "RuntimeError", "ArgumentError",
            "IndexError", "KeyError", "NameError", "NoMethodError", "TypeError"
        ]
    }

    private var builtinModules: [String] {
        // Extract modules from types (second part of the types array)
        [
            "Comparable", "Enumerable", "Errno", "FileUtils", "Find", "GC", "JSON",
            "Kernel", "Marshal", "Math", "ObjectSpace", "Open3", "Process", "Signal",
            "Singleton", "Warning"
        ]
    }

    private var commonMethods: [String] {
        // Use the functions array as common methods
        functions
    }

    // MARK: - Initialization

    public init() {
        super.init(
            id: "ruby-builtin",
            supportedLanguages: [.ruby],
            triggerCharacters: [".", ":", "@", "$", " ", "(", "[", "{", "|"],
            supportsSnippets: true
        )
    }

    // MARK: - CompletionProvider Implementation

    override public func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        let startTime = Date()

        // Analyze context to determine what kind of completions to provide
        let analysisResult = analyzeRubyContext(context)
        var items: [CompletionItemModel] = []

        // Add appropriate completions based on context
        switch analysisResult.type {
        case .keyword:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))

        case .method:
            items.append(contentsOf: createMethodCompletions(for: analysisResult.targetType, filter: analysisResult.filter))

        case .class:
            items.append(contentsOf: createClassCompletions(filter: analysisResult.filter))

        case .module:
            items.append(contentsOf: createModuleCompletions(filter: analysisResult.filter))

        case .instanceVariable:
            items.append(contentsOf: createInstanceVariableCompletions(filter: analysisResult.filter))

        case .classVariable:
            items.append(contentsOf: createClassVariableCompletions(filter: analysisResult.filter))

        case .globalVariable:
            items.append(contentsOf: createGlobalVariableCompletions(filter: analysisResult.filter))

        case .symbol:
            items.append(contentsOf: createSymbolCompletions(filter: analysisResult.filter))

        case .general:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createClassCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createCommonMethodCompletions(filter: analysisResult.filter))
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

    private func analyzeRubyContext(_ context: CompletionContextModel) -> RubyContextAnalysisResult {
        let lineText = context.lineText.trimmingCharacters(in: .whitespaces)
        let beforeCursor = String(context.text.prefix(context.cursorPosition))

        // Extract current word being typed
        let filter = extractCurrentWord(from: beforeCursor)

        // Check for instance variable context
        if beforeCursor.hasSuffix("@") || filter.hasPrefix("@") {
            return RubyContextAnalysisResult(type: .instanceVariable, filter: filter)
        }

        // Check for class variable context
        if beforeCursor.hasSuffix("@@") || filter.hasPrefix("@@") {
            return RubyContextAnalysisResult(type: .classVariable, filter: filter)
        }

        // Check for global variable context
        if beforeCursor.hasSuffix("$") || filter.hasPrefix("$") {
            return RubyContextAnalysisResult(type: .globalVariable, filter: filter)
        }

        // Check for symbol context
        if beforeCursor.hasSuffix(":") && !beforeCursor.hasSuffix("::") {
            return RubyContextAnalysisResult(type: .symbol, filter: filter)
        }

        // Check for method context (after .)
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return RubyContextAnalysisResult(type: .method, filter: "", targetType: targetType)
        }

        // Check for class/module context (after ::)
        if beforeCursor.hasSuffix("::") {
            return RubyContextAnalysisResult(type: .class, filter: "")
        }

        // Check for class definition context
        if lineText.hasPrefix("class ") && !lineText.contains("end") {
            return RubyContextAnalysisResult(type: .class, filter: filter)
        }

        // Check for module definition context
        if lineText.hasPrefix("module ") && !lineText.contains("end") {
            return RubyContextAnalysisResult(type: .module, filter: filter)
        }

        return RubyContextAnalysisResult(type: .general, filter: filter)
    }

    override public func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_@$!?")).inverted)
        return components.last ?? ""
    }

    override public func extractTargetType(from text: String) -> String? {
        CompletionParsingHelpers.extractTargetForDotNotation(from: text)
    }

    // MARK: - Completion Creation Methods

    override public func createKeywordCompletions(filter: String) -> [CompletionItemModel] {
        keywords
            .filter { keyword in
                filter.isEmpty || keyword.localizedCaseInsensitiveContains(filter)
            }
            .map { keyword in
                CompletionItemModel(
                    label: keyword,
                    insertText: keyword,
                    kind: .keyword,
                    detail: "Ruby keyword",
                    priority: 80,
                    preselect: keyword == filter
                )
            }
    }

    private func createClassCompletions(filter: String) -> [CompletionItemModel] {
        builtinClasses
            .filter { className in
                filter.isEmpty || className.localizedCaseInsensitiveContains(filter)
            }
            .map { className in
                CompletionItemModel(
                    label: className,
                    insertText: className,
                    kind: .class,
                    detail: "Ruby class",
                    priority: 70
                )
            }
    }

    private func createModuleCompletions(filter: String) -> [CompletionItemModel] {
        builtinModules
            .filter { moduleName in
                filter.isEmpty || moduleName.localizedCaseInsensitiveContains(filter)
            }
            .map { moduleName in
                CompletionItemModel(
                    label: moduleName,
                    insertText: moduleName,
                    kind: .module,
                    detail: "Ruby module",
                    priority: 70
                )
            }
    }

    private func createMethodCompletions(for targetType: String?, filter: String) -> [CompletionItemModel] {
        var methods = commonMethods

        // Add Rails methods if it looks like Rails code
        if targetType?.lowercased().contains("active") ?? false || targetType?.lowercased().contains("action") ?? false {
            methods += railsMethods
        }

        return methods
            .filter { method in
                filter.isEmpty || method.localizedCaseInsensitiveContains(filter)
            }
            .map { method in
                let insertText: String
                if method.hasSuffix("?") || method.hasSuffix("!") {
                    insertText = method
                } else if ["new", "create", "find", "where", "order"].contains(method) {
                    insertText = "\(method)($0)"
                } else {
                    insertText = method
                }

                return CompletionItemModel(
                    label: method,
                    insertText: insertText,
                    kind: .method,
                    detail: "Ruby method",
                    priority: 75
                )
            }
    }

    private func createCommonMethodCompletions(filter: String) -> [CompletionItemModel] {
        commonMethods
            .filter { method in
                filter.isEmpty || method.localizedCaseInsensitiveContains(filter)
            }
            .map { method in
                CompletionItemModel(
                    label: method,
                    insertText: method,
                    kind: .method,
                    detail: "Common method",
                    priority: 65
                )
            }
    }

    private func createInstanceVariableCompletions(filter: String) -> [CompletionItemModel] {
        // Common instance variable names
        let commonInstanceVars = ["@id", "@name", "@value", "@data", "@options", "@params", "@errors", "@attributes"]

        return commonInstanceVars
            .filter { variable in
                let filterToUse = filter.hasPrefix("@") ? filter : "@\(filter)"
                return variable.localizedCaseInsensitiveContains(filterToUse)
            }
            .map { variable in
                CompletionItemModel(
                    label: variable,
                    insertText: variable,
                    kind: .variable,
                    detail: "Instance variable",
                    priority: 70
                )
            }
    }

    private func createClassVariableCompletions(filter: String) -> [CompletionItemModel] {
        // Common class variable names
        let commonClassVars = ["@@instances", "@@count", "@@all", "@@cache", "@@config"]

        return commonClassVars
            .filter { variable in
                let filterToUse = filter.hasPrefix("@@") ? filter : "@@\(filter)"
                return variable.localizedCaseInsensitiveContains(filterToUse)
            }
            .map { variable in
                CompletionItemModel(
                    label: variable,
                    insertText: variable,
                    kind: .variable,
                    detail: "Class variable",
                    priority: 70
                )
            }
    }

    private func createGlobalVariableCompletions(filter: String) -> [CompletionItemModel] {
        globalVariables
            .filter { variable in
                let filterToUse = filter.hasPrefix("$") ? filter : "$\(filter)"
                return variable.localizedCaseInsensitiveContains(filterToUse)
            }
            .map { variable in
                CompletionItemModel(
                    label: variable,
                    insertText: variable,
                    kind: .variable,
                    detail: "Global variable",
                    priority: 65
                )
            }
    }

    private func createSymbolCompletions(filter: String) -> [CompletionItemModel] {
        // Common symbols in Ruby
        let commonSymbols = [
            "id", "name", "value", "key", "type", "status", "created_at", "updated_at",
            "email", "username", "password", "token", "url", "path", "message", "error",
            "success", "failure", "pending", "active", "inactive", "enabled", "disabled"
        ]

        return commonSymbols
            .filter { symbol in
                filter.isEmpty || symbol.localizedCaseInsensitiveContains(filter)
            }
            .map { symbol in
                CompletionItemModel(
                    label: ":\(symbol)",
                    insertText: symbol,
                    kind: .constant,
                    detail: "Symbol",
                    priority: 70
                )
            }
    }

    override public func createSnippetCompletions(filter: String) -> [CompletionItemModel] {
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

private struct RubyContextAnalysisResult {
    enum CompletionType {
        case keyword
        case method
        case `class`
        case module
        case instanceVariable
        case classVariable
        case globalVariable
        case symbol
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
