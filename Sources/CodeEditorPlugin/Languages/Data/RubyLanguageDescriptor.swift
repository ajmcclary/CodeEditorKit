import Foundation

extension LanguageDescriptor {
    // ── Ruby ───────────────────────────────────────────────────────
    static let rubyDescriptor = Self(
            language: .ruby,
            displayName: "Ruby",
            fileExtensions: ["rb", "rbw"],
            lspIdentifier: "ruby",
            highlightingStrategy: .regex,
            lineComment: "#",
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
            triggerCharacters: [".", "(", " ", ":"],
            snippets: DescriptorSnippetData.ruby,
            memberCompletions: nil,
            commonModules: [],
            parserName: "ruby",
            shebangIdentifiers: ["ruby"],
            scriptAliases: ["ruby", "rb"]
        )
}
