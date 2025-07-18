#if canImport(AppKit) && !targetEnvironment(macCatalyst)
// LSP functionality is only available on macOS

import Foundation

// MARK: - Initialize Request/Response

/// Parameters for the initialize request
public struct InitializeParams: Codable, Sendable {
    public let processId: Int32?
    public let rootUri: String?
    public let capabilities: ClientCapabilities
    public let workspaceFolders: [WorkspaceFolder]
    
    public init(
        processId: Int32?,
        rootUri: String?,
        capabilities: ClientCapabilities,
        workspaceFolders: [WorkspaceFolder] = []
    ) {
        self.processId = processId
        self.rootUri = rootUri
        self.capabilities = capabilities
        self.workspaceFolders = workspaceFolders
    }
}

/// Result of the initialize request
public struct InitializeResult: Codable, Sendable {
    public let capabilities: ServerCapabilities
    public let serverInfo: ServerInfo?
    
    public init(capabilities: ServerCapabilities, serverInfo: ServerInfo? = nil) {
        self.capabilities = capabilities
        self.serverInfo = serverInfo
    }
}

/// Server information
public struct ServerInfo: Codable, Sendable {
    public let name: String
    public let version: String?
    
    public init(name: String, version: String? = nil) {
        self.name = name
        self.version = version
    }
}

// MARK: - Document Lifecycle

/// Parameters for textDocument/didOpen notification
public struct DidOpenTextDocumentParams: Codable, Sendable {
    public let textDocument: TextDocumentItem
    
    public init(textDocument: TextDocumentItem) {
        self.textDocument = textDocument
    }
}

/// Parameters for textDocument/didChange notification
public struct DidChangeTextDocumentParams: Codable, Sendable {
    public let textDocument: VersionedTextDocumentIdentifier
    public let contentChanges: [TextDocumentContentChangeEvent]
    
    public init(
        textDocument: VersionedTextDocumentIdentifier,
        contentChanges: [TextDocumentContentChangeEvent]
    ) {
        self.textDocument = textDocument
        self.contentChanges = contentChanges
    }
}

/// Parameters for textDocument/didClose notification
public struct DidCloseTextDocumentParams: Codable, Sendable {
    public let textDocument: TextDocumentIdentifier
    
    public init(textDocument: TextDocumentIdentifier) {
        self.textDocument = textDocument
    }
}

// MARK: - Completion

/// Parameters for textDocument/completion request
public struct CompletionParams: Codable, Sendable {
    public let textDocument: TextDocumentIdentifier
    public let position: Position
    public let context: LSPCompletionContext?
    
    public init(
        textDocument: TextDocumentIdentifier,
        position: Position,
        context: LSPCompletionContext? = nil
    ) {
        self.textDocument = textDocument
        self.position = position
        self.context = context
    }
}

/// LSP completion context
public struct LSPCompletionContext: Codable, Sendable {
    public let triggerKind: LSPCompletionTriggerKind
    public let triggerCharacter: String?
    
    public init(triggerKind: LSPCompletionTriggerKind, triggerCharacter: String? = nil) {
        self.triggerKind = triggerKind
        self.triggerCharacter = triggerCharacter
    }
}

/// LSP Completion trigger kind
public enum LSPCompletionTriggerKind: Int, Codable, Sendable {
    case invoked = 1
    case triggerCharacter = 2
    case triggerForIncompleteCompletions = 3
}

/// Completion list
public struct CompletionList: Codable, Sendable {
    public let isIncomplete: Bool
    public let items: [LSPCompletionItem]
    
    public init(isIncomplete: Bool, items: [LSPCompletionItem]) {
        self.isIncomplete = isIncomplete
        self.items = items
    }
}

/// LSP Completion item
public struct LSPCompletionItem: Codable, Sendable {
    public let label: String
    public let kind: LSPCompletionItemKind?
    public let detail: String?
    public let documentation: CompletionItemDocumentation?
    public let sortText: String?
    public let filterText: String?
    public let insertText: String?
    public let insertTextFormat: InsertTextFormat?
    public let textEdit: LSPTextEdit?
    public let additionalTextEdits: [LSPTextEdit]
    public let commitCharacters: [String]
    public let data: AnyCodable?
    
    public init(
        label: String,
        kind: LSPCompletionItemKind? = nil,
        detail: String? = nil,
        documentation: CompletionItemDocumentation? = nil,
        sortText: String? = nil,
        filterText: String? = nil,
        insertText: String? = nil,
        insertTextFormat: InsertTextFormat? = nil,
        textEdit: LSPTextEdit? = nil,
        additionalTextEdits: [LSPTextEdit] = [],
        commitCharacters: [String] = [],
        data: AnyCodable? = nil
    ) {
        self.label = label
        self.kind = kind
        self.detail = detail
        self.documentation = documentation
        self.sortText = sortText
        self.filterText = filterText
        self.insertText = insertText
        self.insertTextFormat = insertTextFormat
        self.textEdit = textEdit
        self.additionalTextEdits = additionalTextEdits
        self.commitCharacters = commitCharacters
        self.data = data
    }
}

/// LSP Completion item kind
public enum LSPCompletionItemKind: Int, Codable, Sendable {
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

/// Completion item documentation
public enum CompletionItemDocumentation: Codable, Sendable {
    case string(String)
    case markupContent(MarkupContent)
    
    public init(from decoder: Decoder) throws {
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
    
    public func encode(to encoder: Encoder) throws {
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
public enum InsertTextFormat: Int, Codable, Sendable {
    case plainText = 1
    case snippet = 2
}

/// LSP Text edit
public struct LSPTextEdit: Codable, Sendable {
    public let range: LSPRange
    public let newText: String
    
    public init(range: LSPRange, newText: String) {
        self.range = range
        self.newText = newText
    }
}

// MARK: - Hover

/// Parameters for textDocument/hover request
public struct HoverParams: Codable, Sendable {
    public let textDocument: TextDocumentIdentifier
    public let position: Position
    
    public init(textDocument: TextDocumentIdentifier, position: Position) {
        self.textDocument = textDocument
        self.position = position
    }
}

/// Hover information
public struct Hover: Codable, Sendable {
    public let contents: HoverContents
    public let range: LSPRange?
    
    public init(contents: HoverContents, range: LSPRange? = nil) {
        self.contents = contents
        self.range = range
    }
}

/// Hover contents
public enum HoverContents: Codable, Sendable {
    case string(String)
    case markupContent(MarkupContent)
    case markedStrings([MarkedString])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let markupValue = try? container.decode(MarkupContent.self) {
            self = .markupContent(markupValue)
        } else if let markedStringsValue = try? container.decode([MarkedString].self) {
            self = .markedStrings(markedStringsValue)
        } else {
            throw DecodingError.typeMismatch(
                Self.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected string, MarkupContent, or [MarkedString]"
                )
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)

        case .markupContent(let value):
            try container.encode(value)

        case .markedStrings(let value):
            try container.encode(value)
        }
    }
}

/// Marked string
public enum MarkedString: Codable, Sendable {
    case string(String)
    case codeBlock(language: String, value: String)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            let dict = try container.decode([String: String].self)
            guard let language = dict["language"], let value = dict["value"] else {
                throw DecodingError.typeMismatch(
                    Self.self,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected language and value keys"
                    )
                )
            }
            self = .codeBlock(language: language, value: value)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)

        case let .codeBlock(language, value):
            try container.encode(["language": language, "value": value])
        }
    }
}

// MARK: - Definition

/// Parameters for textDocument/definition request
public struct DefinitionParams: Codable, Sendable {
    public let textDocument: TextDocumentIdentifier
    public let position: Position
    
    public init(textDocument: TextDocumentIdentifier, position: Position) {
        self.textDocument = textDocument
        self.position = position
    }
}

// MARK: - Document Symbols

/// Parameters for textDocument/documentSymbol request
public struct DocumentSymbolParams: Codable, Sendable {
    public let textDocument: TextDocumentIdentifier
    
    public init(textDocument: TextDocumentIdentifier) {
        self.textDocument = textDocument
    }
}

/// LSP Document symbol
public struct LSPDocumentSymbol: Codable, Sendable {
    public let name: String
    public let detail: String?
    public let kind: SymbolKind
    public let tags: [SymbolTag]
    public let range: LSPRange
    public let selectionRange: LSPRange
    public let children: [Self]
    
    public init(
        name: String,
        kind: SymbolKind,
        range: LSPRange,
        selectionRange: LSPRange,
        detail: String? = nil,
        tags: [SymbolTag] = [],
        children: [Self] = []
    ) {
        self.name = name
        self.detail = detail
        self.kind = kind
        self.tags = tags
        self.range = range
        self.selectionRange = selectionRange
        self.children = children
    }
}

/// Symbol kind
public enum SymbolKind: Int, Codable, Sendable {
    case file = 1
    case module = 2
    case namespace = 3
    case package = 4
    case `class` = 5
    case method = 6
    case property = 7
    case field = 8
    case constructor = 9
    case `enum` = 10
    case interface = 11
    case function = 12
    case variable = 13
    case constant = 14
    case string = 15
    case number = 16
    case boolean = 17
    case array = 18
    case object = 19
    case key = 20
    case null = 21
    case enumMember = 22
    case `struct` = 23
    case event = 24
    case `operator` = 25
    case typeParameter = 26
}

/// Symbol tag
public enum SymbolTag: Int, Codable, Sendable {
    case deprecated = 1
}

// MARK: - Diagnostics

/// Parameters for textDocument/publishDiagnostics notification
public struct PublishDiagnosticsParams: Codable, Sendable {
    public let uri: String
    public let version: Int?
    public let diagnostics: [Diagnostic]
    
    public init(uri: String, diagnostics: [Diagnostic], version: Int? = nil) {
        self.uri = uri
        self.version = version
        self.diagnostics = diagnostics
    }
}

// MARK: - Window Messages

/// Message type for log/show messages
public enum MessageType: Int, Codable, Sendable {
    case error = 1
    case warning = 2
    case info = 3
    case log = 4
}

/// Parameters for window/logMessage notification
public struct LogMessageParams: Codable, Sendable {
    public let type: MessageType
    public let message: String
    
    public init(type: MessageType, message: String) {
        self.type = type
        self.message = message
    }
}

/// Parameters for window/showMessage notification
public struct ShowMessageParams: Codable, Sendable {
    public let type: MessageType
    public let message: String
    
    public init(type: MessageType, message: String) {
        self.type = type
        self.message = message
    }
}

// MARK: - Error Types

/// LSP error types
public enum LSPError: Error, LocalizedError, Sendable {
    case notConnected
    case alreadyConnected
    case transportNotConfigured
    case serverError(code: Int, message: String, data: String?)
    case invalidResponse(String)
    case decodingError(String)
    case connectionFailed(String)
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to LSP server"

        case .alreadyConnected:
            return "Already connected to LSP server"

        case .transportNotConfigured:
            return "No transport configured for LSP connection"

        case let .serverError(code, message, _):
            return "LSP server error (\(code)): \(message)"

        case .invalidResponse(let message):
            return "Invalid LSP response: \(message)"

        case .decodingError(let message):
            return "LSP decoding error: \(message)"

        case .connectionFailed(let message):
            return "LSP connection failed: \(message)"

        case .timeout:
            return "LSP request timeout"
        }
    }
}

#endif
