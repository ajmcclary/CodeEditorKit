import Foundation

// MARK: - Rust Completion Provider

/// Built-in completion provider for Rust language
@MainActor
public final class RustCompletionProvider: CompletionProvider, @unchecked Sendable {
    public let id = "rust-builtin"
    public let supportedLanguages: [Language] = [.rust]
    public let triggerCharacters = [".", "::", "(", "<", " ", "!"]
    public let supportsSnippets = true
    
    // Rust language elements
    private let keywords = [
        "as", "async", "await", "break", "const", "continue", "crate", "dyn",
        "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in",
        "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
        "self", "Self", "static", "struct", "super", "trait", "true", "type",
        "unsafe", "use", "where", "while", "abstract", "become", "box", "do",
        "final", "macro", "override", "priv", "typeof", "unsized", "virtual",
        "yield", "try"
    ]
    
    private let types = [
        "bool", "char", "f32", "f64", "i8", "i16", "i32", "i64", "i128",
        "isize", "str", "u8", "u16", "u32", "u64", "u128", "usize",
        "String", "Vec", "HashMap", "HashSet", "Option", "Result", "Box",
        "Rc", "Arc", "RefCell", "Mutex", "RwLock", "Cell"
    ]
    
    private let macros = [
        "println!", "print!", "eprintln!", "eprint!", "format!", "write!",
        "writeln!", "panic!", "assert!", "assert_eq!", "assert_ne!",
        "debug_assert!", "debug_assert_eq!", "debug_assert_ne!", "vec!",
        "include!", "include_str!", "include_bytes!", "concat!", "env!",
        "option_env!", "cfg!", "line!", "column!", "file!", "module_path!",
        "stringify!", "todo!", "unimplemented!", "unreachable!", "dbg!"
    ]
    
    private let traits = [
        "Clone", "Copy", "Debug", "Default", "Display", "Drop", "Eq", "Fn",
        "FnMut", "FnOnce", "From", "Into", "Iterator", "Ord", "PartialEq",
        "PartialOrd", "Send", "Sized", "Sync", "ToString", "AsRef", "AsMut",
        "Borrow", "BorrowMut", "Deref", "DerefMut"
    ]
    
    private let commonModules = [
        "std", "std::io", "std::fs", "std::path", "std::env", "std::process",
        "std::thread", "std::sync", "std::time", "std::collections",
        "std::vec", "std::string", "std::option", "std::result", "std::error",
        "std::fmt", "std::mem", "std::ptr", "std::slice", "std::str",
        "std::iter", "std::ops", "std::cmp", "std::convert", "std::marker"
    ]
    
    private let snippets: [SnippetTemplate] = [
        SnippetTemplate(
            label: "fn",
            insertText: "fn ${1:function_name}(${2:params}) -> ${3:ReturnType} {\n    ${4:// body}\n}",
            description: "Function declaration"
        ),
        SnippetTemplate(
            label: "pub fn",
            insertText: "pub fn ${1:function_name}(${2:params}) -> ${3:ReturnType} {\n    ${4:// body}\n}",
            description: "Public function"
        ),
        SnippetTemplate(
            label: "struct",
            insertText: "struct ${1:Name} {\n    ${2:field}: ${3:Type},\n}",
            description: "Struct declaration"
        ),
        SnippetTemplate(
            label: "enum",
            insertText: "enum ${1:Name} {\n    ${2:Variant1},\n    ${3:Variant2},\n}",
            description: "Enum declaration"
        ),
        SnippetTemplate(
            label: "impl",
            insertText: "impl ${1:Type} {\n    ${2:// methods}\n}",
            description: "Implementation block"
        ),
        SnippetTemplate(
            label: "impl trait",
            insertText: "impl ${1:Trait} for ${2:Type} {\n    ${3:// trait methods}\n}",
            description: "Trait implementation"
        ),
        SnippetTemplate(
            label: "trait",
            insertText: "trait ${1:Name} {\n    fn ${2:method}(&self) -> ${3:ReturnType};\n}",
            description: "Trait declaration"
        ),
        SnippetTemplate(
            label: "match",
            insertText: "match ${1:expression} {\n    ${2:pattern} => ${3:result},\n    _ => ${4:default},\n}",
            description: "Match expression"
        ),
        SnippetTemplate(
            label: "if let",
            insertText: "if let ${1:Some(value)} = ${2:expression} {\n    ${3:// use value}\n}",
            description: "If let pattern"
        ),
        SnippetTemplate(
            label: "while let",
            insertText: "while let ${1:Some(value)} = ${2:expression} {\n    ${3:// use value}\n}",
            description: "While let loop"
        ),
        SnippetTemplate(
            label: "for",
            insertText: "for ${1:item} in ${2:iterator} {\n    ${3:// body}\n}",
            description: "For loop"
        ),
        SnippetTemplate(
            label: "loop",
            insertText: "loop {\n    ${1:// body}\n    ${2:break;}\n}",
            description: "Infinite loop"
        ),
        SnippetTemplate(
            label: "test",
            insertText: "#[test]\nfn ${1:test_name}() {\n    ${2:// test body}\n}",
            description: "Test function"
        ),
        SnippetTemplate(
            label: "derive",
            insertText: "#[derive(${1:Debug, Clone})]",
            description: "Derive macro"
        ),
        SnippetTemplate(
            label: "Result",
            insertText: "Result<${1:T}, ${2:E}>",
            description: "Result type"
        ),
        SnippetTemplate(
            label: "Option",
            insertText: "Option<${1:T}>",
            description: "Option type"
        ),
        SnippetTemplate(
            label: "Vec",
            insertText: "Vec<${1:T}>",
            description: "Vector type"
        ),
        SnippetTemplate(
            label: "main",
            insertText: "fn main() {\n    ${1:// main code}\n}",
            description: "Main function"
        ),
        SnippetTemplate(
            label: "mod",
            insertText: "mod ${1:module_name} {\n    ${2:// module content}\n}",
            description: "Module declaration"
        ),
        SnippetTemplate(
            label: "use",
            insertText: "use ${1:std::}${2:module};",
            description: "Use statement"
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
        case .use:
            items.append(contentsOf: createUseCompletions(filter: analysisResult.filter))
            
        case .keyword:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            
        case .type:
            items.append(contentsOf: createTypeCompletions(filter: analysisResult.filter))
            
        case .macro:
            items.append(contentsOf: createMacroCompletions(filter: analysisResult.filter))
            
        case .trait:
            items.append(contentsOf: createTraitCompletions(filter: analysisResult.filter))
            
        case .member:
            items.append(contentsOf: createMemberCompletions(for: analysisResult.targetType, filter: analysisResult.filter))
            
        case .general:
            items.append(contentsOf: createKeywordCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createTypeCompletions(filter: analysisResult.filter))
            items.append(contentsOf: createMacroCompletions(filter: analysisResult.filter))
            if supportsSnippets {
                items.append(contentsOf: createSnippetCompletions(filter: analysisResult.filter))
            }
            
        case .lifetime:
            items.append(contentsOf: createLifetimeCompletions(filter: analysisResult.filter))
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
        
        // Check for use statements
        if lineText.hasPrefix("use ") {
            return ContextAnalysisResult(type: .use, filter: filter)
        }
        
        // Check for macro context
        if beforeCursor.hasSuffix("!") || filter.hasSuffix("!") {
            return ContextAnalysisResult(type: .macro, filter: filter)
        }
        
        // Check for trait context
        if lineText.contains("impl ") && lineText.contains(" for ") {
            return ContextAnalysisResult(type: .trait, filter: filter)
        }
        
        // Check for type context
        if lineText.contains(": ") || lineText.contains("-> ") || lineText.contains("let ") {
            return ContextAnalysisResult(type: .type, filter: filter)
        }
        
        // Check for member access
        if beforeCursor.hasSuffix(".") {
            let targetType = extractTargetType(from: beforeCursor)
            return ContextAnalysisResult(type: .member, filter: "", targetType: targetType)
        }
        
        // Check for module access
        if beforeCursor.hasSuffix("::") {
            let targetModule = extractTargetModule(from: beforeCursor)
            return ContextAnalysisResult(type: .member, filter: "", targetType: targetModule)
        }
        
        // Check for lifetime context
        if beforeCursor.hasSuffix("'") || beforeCursor.hasSuffix("<'") {
            return ContextAnalysisResult(type: .lifetime, filter: filter)
        }
        
        return ContextAnalysisResult(type: .general, filter: filter)
    }
    
    private func extractCurrentWord(from text: String) -> String {
        let components = text.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_!'")).inverted)
        return components.last ?? ""
    }
    
    private func extractTargetType(from text: String) -> String? {
        // Extract the object before the dot
        let pattern = #"(\w+)\s*\.\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let range = Range(match.range(at: 1), in: text)!
            return String(text[range])
        }
        return nil
    }
    
    private func extractTargetModule(from text: String) -> String? {
        // Extract the module before ::
        let pattern = #"([\w:]+)::\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let range = Range(match.range(at: 1), in: text)!
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
                    detail: "Rust keyword",
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
                let isGeneric = ["Vec", "HashMap", "HashSet", "Option", "Result", "Box", "Rc", "Arc", "RefCell", "Mutex", "RwLock"].contains(type)
                return CompletionItemModel(
                    label: type,
                    insertText: isGeneric ? "\(type)<$0>" : type,
                    kind: .struct,
                    detail: "Rust type",
                    priority: 70
                )
            }
    }
    
    private func createMacroCompletions(filter: String) -> [CompletionItemModel] {
        macros
            .filter { macro in
                filter.isEmpty || macro.localizedCaseInsensitiveContains(filter)
            }
            .map { macro in
                CompletionItemModel(
                    label: macro,
                    insertText: macro.hasSuffix("!") ? "\(macro)($0)" : "\(macro)!($0)",
                    kind: .function,
                    detail: "Rust macro",
                    priority: 75
                )
            }
    }
    
    private func createTraitCompletions(filter: String) -> [CompletionItemModel] {
        traits
            .filter { trait in
                filter.isEmpty || trait.localizedCaseInsensitiveContains(filter)
            }
            .map { trait in
                CompletionItemModel(
                    label: trait,
                    insertText: trait,
                    kind: .interface,
                    detail: "Rust trait",
                    priority: 72
                )
            }
    }
    
    private func createUseCompletions(filter: String) -> [CompletionItemModel] {
        commonModules
            .filter { module in
                filter.isEmpty || module.localizedCaseInsensitiveContains(filter)
            }
            .map { module in
                CompletionItemModel(
                    label: module,
                    insertText: module,
                    kind: .module,
                    detail: "Rust module",
                    priority: 85
                )
            }
    }
    
    private func createLifetimeCompletions(filter: String) -> [CompletionItemModel] {
        // Common lifetime names
        let lifetimes = ["'a", "'b", "'c", "'static", "'_"]
        
        return lifetimes
            .filter { lifetime in
                filter.isEmpty || lifetime.localizedCaseInsensitiveContains(filter)
            }
            .map { lifetime in
                CompletionItemModel(
                    label: lifetime,
                    insertText: lifetime,
                    kind: .typeParameter,
                    detail: "Lifetime parameter",
                    priority: 60
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
        
        // Provide member completions based on type or module
        switch targetType.lowercased() {
        case "string", "str":
            return createStringMemberCompletions(filter: filter)
            
        case "vec":
            return createVecMemberCompletions(filter: filter)
            
        case "option":
            return createOptionMemberCompletions(filter: filter)
            
        case "result":
            return createResultMemberCompletions(filter: filter)
            
        case "std":
            return createStdModuleCompletions(filter: filter)
            
        default:
            return createCommonMemberCompletions(filter: filter)
        }
    }
    
    // MARK: - Type-Specific Members
    
    private func createStringMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("len()", "method", "Get string length"),
            ("is_empty()", "method", "Check if empty"),
            ("chars()", "method", "Iterator over chars"),
            ("bytes()", "method", "Iterator over bytes"),
            ("contains()", "method", "Check substring"),
            ("starts_with()", "method", "Check prefix"),
            ("ends_with()", "method", "Check suffix"),
            ("find()", "method", "Find substring"),
            ("replace()", "method", "Replace substring"),
            ("trim()", "method", "Trim whitespace"),
            ("to_lowercase()", "method", "Convert to lowercase"),
            ("to_uppercase()", "method", "Convert to uppercase"),
            ("split()", "method", "Split string"),
            ("lines()", "method", "Iterator over lines"),
            ("parse()", "method", "Parse string")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createVecMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("len()", "method", "Get vector length"),
            ("is_empty()", "method", "Check if empty"),
            ("push()", "method", "Add element"),
            ("pop()", "method", "Remove last element"),
            ("insert()", "method", "Insert at index"),
            ("remove()", "method", "Remove at index"),
            ("clear()", "method", "Remove all elements"),
            ("get()", "method", "Get element option"),
            ("first()", "method", "Get first element"),
            ("last()", "method", "Get last element"),
            ("iter()", "method", "Get iterator"),
            ("iter_mut()", "method", "Get mutable iterator"),
            ("sort()", "method", "Sort elements"),
            ("reverse()", "method", "Reverse elements"),
            ("contains()", "method", "Check if contains")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createOptionMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("is_some()", "method", "Check if Some"),
            ("is_none()", "method", "Check if None"),
            ("unwrap()", "method", "Extract value or panic"),
            ("unwrap_or()", "method", "Extract or default"),
            ("unwrap_or_else()", "method", "Extract or compute"),
            ("map()", "method", "Transform value"),
            ("and_then()", "method", "Chain operations"),
            ("or()", "method", "Provide alternative"),
            ("or_else()", "method", "Compute alternative"),
            ("filter()", "method", "Filter by predicate"),
            ("take()", "method", "Take ownership"),
            ("as_ref()", "method", "Convert to reference"),
            ("as_mut()", "method", "Convert to mutable ref"),
            ("ok_or()", "method", "Convert to Result"),
            ("expect()", "method", "Extract with message")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createResultMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("is_ok()", "method", "Check if Ok"),
            ("is_err()", "method", "Check if Err"),
            ("ok()", "method", "Convert to Option"),
            ("err()", "method", "Get error as Option"),
            ("unwrap()", "method", "Extract value or panic"),
            ("unwrap_or()", "method", "Extract or default"),
            ("unwrap_or_else()", "method", "Extract or compute"),
            ("expect()", "method", "Extract with message"),
            ("map()", "method", "Transform Ok value"),
            ("map_err()", "method", "Transform Err value"),
            ("and_then()", "method", "Chain operations"),
            ("or()", "method", "Provide alternative"),
            ("or_else()", "method", "Compute alternative"),
            ("as_ref()", "method", "Convert to reference"),
            ("as_mut()", "method", "Convert to mutable ref")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createStdModuleCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("io", "module", "I/O operations"),
            ("fs", "module", "File system"),
            ("path", "module", "Path operations"),
            ("env", "module", "Environment"),
            ("process", "module", "Process control"),
            ("thread", "module", "Threading"),
            ("sync", "module", "Synchronization"),
            ("time", "module", "Time operations"),
            ("collections", "module", "Collections"),
            ("vec", "module", "Vector module"),
            ("string", "module", "String module"),
            ("fmt", "module", "Formatting"),
            ("error", "module", "Error handling"),
            ("mem", "module", "Memory operations")
        ]
        
        return createMemberItems(from: members, filter: filter)
    }
    
    private func createCommonMemberCompletions(filter: String) -> [CompletionItemModel] {
        let members = [
            ("clone()", "method", "Clone value"),
            ("to_string()", "method", "Convert to String"),
            ("fmt()", "method", "Format value"),
            ("eq()", "method", "Equality check"),
            ("cmp()", "method", "Ordering comparison"),
            ("hash()", "method", "Hash value")
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
                    kind: type == "method" ? .method : (type == "module" ? .module : .property),
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
        case `use`
        case macro
        case trait
        case member
        case general
        case lifetime
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
