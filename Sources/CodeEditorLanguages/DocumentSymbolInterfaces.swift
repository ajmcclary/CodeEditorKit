import Foundation

// MARK: - Supporting Types

/// Document symbol representation
public struct DocumentSymbol: Identifiable, Sendable {
    public let id = UUID()
    public var name: String
    public var kind: DocumentSymbolKind
    public var range: NSRange
    public var selectionRange: NSRange
    public var detail: String?
    public var children: [Self] = []

    public init(
        name: String,
        kind: DocumentSymbolKind,
        range: NSRange,
        selectionRange: NSRange? = nil,
        detail: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.range = range
        self.selectionRange = selectionRange ?? range
        self.detail = detail
    }
}

/// Document symbol kinds for navigation
public enum DocumentSymbolKind: String, CaseIterable, Sendable {
    case file
    case module
    case namespace
    case package
    case `class`
    case method
    case property
    case field
    case constructor
    case `enum`
    case interface
    case function
    case variable
    case constant
    case string
    case number
    case boolean
    case array
    case object
    case key
    case null
    case enumMember
    case `struct`
    case event
    case `operator`
    case typeParameter

    package var icon: String {
        switch self {
        case .file: return "📄"
        case .module: return "📦"
        case .namespace: return "🗂"
        case .package: return "📦"
        case .class: return "🏛"
        case .method: return "⚡️"
        case .property: return "🔧"
        case .field: return "📝"
        case .constructor: return "🏗"
        case .enum: return "🔢"
        case .interface: return "🔌"
        case .function: return "ƒ"
        case .variable: return "𝑥"
        case .constant: return "𝐶"
        case .string: return "\"\""
        case .number: return "#"
        case .boolean: return "◉"
        case .array: return "[]"
        case .object: return "{}"
        case .key: return "🔑"
        case .null: return "∅"
        case .enumMember: return "•"
        case .struct: return "◼︎"
        case .event: return "⚡"
        case .operator: return "±"
        case .typeParameter: return "𝑇"
        }
    }

    package var canContainSymbols: Bool {
        switch self {
        case .file, .module, .namespace, .package, .class,
             .interface, .struct, .object, .enum:
            return true

        default:
            return false
        }
    }
}

// MARK: - Document Symbol Provider Protocol

/// Protocol for language-specific symbol providers
public protocol DocumentSymbolProvider: Sendable {
    /// Detects and returns symbols found in the given text
    /// - Parameter text: The source code text to analyze
    /// - Returns: An array of detected document symbols
    func detectSymbols(in text: String) async -> [DocumentSymbol]
}
