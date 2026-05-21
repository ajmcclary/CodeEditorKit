import Foundation

extension LanguageDescriptor {
    // ── Swift ──────────────────────────────────────────────────────
    static let swiftDescriptor = Self(
            language: .swift,
            displayName: "Swift",
            fileExtensions: ["swift"],
            lspIdentifier: "swift",
            usesRegexHighlighter: false,
            lineComment: "//",
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
                "true", "false", "nil", "self", "Self", "super", "#file", "#line", "#column", "#function"
            ],
            triggerCharacters: [".", "(", "[", "<", " ", ":"],
            snippets: SwiftSnippets.all,
            memberCompletions: SwiftMemberCompletions(),
            commonModules: [
                "Foundation", "UIKit", "AppKit", "SwiftUI", "Combine", "CoreData", "CoreGraphics",
                "QuartzCore", "AVFoundation", "NetworkExtension", "UserNotifications", "StoreKit"
            ],
            parserName: nil,
            shebangIdentifiers: [],
            scriptAliases: ["swift"]
        )
}
