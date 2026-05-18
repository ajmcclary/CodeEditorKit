#if canImport(AppKit)
// LSP test helpers are only available on macOS

import CodeEditorCompletion
import CodeEditorLanguages
@testable import CodeEditorPlugin
import Foundation

// MARK: - LSP Test Helpers

/// Adapter to bridge LSP completion items with the completion system for testing.
///
/// Renamed from `CompletionItemAdapter` (LSP-test-local) to avoid colliding
/// with the framework's internal `CompletionItemAdapter` (`@testable import`
/// brings the framework type into scope; unqualified resolution otherwise
/// preferred this helper). Only used inside this file.
struct LSPTestCompletionItem {
    let model: CompletionItemModel

    init(label: String, kind: CompletionItemKind = .text) {
        self.model = CompletionItemModel(
            label: label,
            insertText: label,
            kind: kind,
            detail: nil,
            documentation: nil,
            sortText: nil,
            filterText: nil,
            textEdit: nil,
            additionalTextEdits: []
        )
    }
}

/// Mock LSP completion item for testing
struct MockLSPCompletionItem {
    let item: Any

    init(label: String, kind: CompletionItemKind = .text) {
        self.item = LSPTestCompletionItem(label: label, kind: kind)
    }
}

// MARK: - LSP Completion Item Extensions

/// LSP completion item kinds
enum LSPCompletionItemKind: Int, Codable, Sendable {
    case text = 1
    case method = 2
    case function = 3
    case constructor = 4
    case field = 5
    case variable = 6
    case `class` = 7
    case interface = 8
    case module = 9
    case property = 10
    case unit = 11
    case value = 12
    case `enum` = 13
    case keyword = 14
    case snippet = 15
    case color = 16
    case file = 17
    case reference = 18
    case folder = 19
    case enumMember = 20
    case constant = 21
    case `struct` = 22
    case event = 23
    case `operator` = 24
    case typeParameter = 25
}

/// LSP text edit
struct LSPTextEdit: Codable, Sendable {
    let range: LSPRange
    let newText: String
}

/// LSP completion item
struct LSPCompletionItem: Codable, Sendable {
    let label: String
    let kind: LSPCompletionItemKind?
    let detail: String?
    let documentation: CompletionItemDocumentation?
    let deprecated: Bool
    let preselect: Bool
    let sortText: String?
    let filterText: String?
    let insertText: String?
    let insertTextFormat: InsertTextFormat?
    let textEdit: LSPTextEdit?
    let additionalTextEdits: [LSPTextEdit]
    let commitCharacters: [String]
    let command: Command?
    let data: AnyCodable?

    init(
        label: String,
        kind: LSPCompletionItemKind? = nil,
        detail: String? = nil,
        documentation: CompletionItemDocumentation? = nil,
        deprecated: Bool = false,
        preselect: Bool = false,
        sortText: String? = nil,
        filterText: String? = nil,
        insertText: String? = nil,
        insertTextFormat: InsertTextFormat? = nil,
        textEdit: LSPTextEdit? = nil,
        additionalTextEdits: [LSPTextEdit] = [],
        commitCharacters: [String] = [],
        command: Command? = nil,
        data: AnyCodable? = nil
    ) {
        self.label = label
        self.kind = kind
        self.detail = detail
        self.documentation = documentation
        self.deprecated = deprecated
        self.preselect = preselect
        self.sortText = sortText
        self.filterText = filterText
        self.insertText = insertText
        self.insertTextFormat = insertTextFormat
        self.textEdit = textEdit
        self.additionalTextEdits = additionalTextEdits
        self.commitCharacters = commitCharacters
        self.command = command
        self.data = data
    }
}

/// Completion item documentation
enum CompletionItemDocumentation: Codable, Sendable {
    case string(String)
    case markupContent(MarkupContent)

    enum CodingKeys: String, CodingKey {
        case string
        case markupContent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let markupValue = try? container.decode(MarkupContent.self) {
            self = .markupContent(markupValue)
        } else {
            throw DecodingError.typeMismatch(
                Self.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected string or MarkupContent"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)

        case .markupContent(let value):
            try container.encode(value)
        }
    }
}

/// Insert text format
enum InsertTextFormat: Int, Codable, Sendable {
    case plainText = 1
    case snippet = 2
}

/// Command
struct Command: Codable, Sendable {
    let title: String
    let command: String
    let arguments: [AnyCodable]
}

/// Completion list
struct CompletionList: Codable, Sendable {
    let isIncomplete: Bool
    let items: [LSPCompletionItem]
}

// MARK: - Completion Helper Extensions

extension LSPCompletionProvider {
    /// Get trigger characters for testing
    func triggerCharacters() -> [String] {
        triggerCharacters
    }
}

#endif // canImport(AppKit)
