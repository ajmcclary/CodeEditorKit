import Foundation

// MARK: - Core LSP Types

/// LSP request message
public struct LSPRequest: Codable {
    public let jsonrpc: String = "2.0"
    public let id: RequestId
    public let method: String
    public let params: AnyCodable
    
    public init(id: RequestId, method: String, params: any Codable) {
        self.id = id
        self.method = method
        self.params = AnyCodable(params)
    }
}

/// LSP notification message
public struct LSPNotification: Codable {
    public let jsonrpc: String = "2.0"
    public let method: String
    public let params: AnyCodable
    
    public init(method: String, params: any Codable) {
        self.method = method
        self.params = AnyCodable(params)
    }
}

/// Request identifier (can be string or number)
public enum RequestId: Codable, Sendable {
    case string(String)
    case number(Int)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .number(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(Self.self, 
                DecodingError.Context(codingPath: decoder.codingPath, 
                                    debugDescription: "Expected string or number"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)

        case .number(let value):
            try container.encode(value)
        }
    }
}

/// Type-erased codable wrapper
public struct AnyCodable: Codable {
    private let value: Any
    
    public init(_ value: any Codable) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([Self].self) {
            value = arrayValue
        } else if let dictValue = try? container.decode([String: Self].self) {
            value = dictValue
        } else {
            throw DecodingError.typeMismatch(Self.self, 
                DecodingError.Context(codingPath: decoder.codingPath, 
                                    debugDescription: "Unsupported type"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let boolValue as Bool:
            try container.encode(boolValue)

        case let intValue as Int:
            try container.encode(intValue)

        case let doubleValue as Double:
            try container.encode(doubleValue)

        case let stringValue as String:
            try container.encode(stringValue)

        case let arrayValue as [Self]:
            try container.encode(arrayValue)

        case let dictValue as [String: Self]:
            try container.encode(dictValue)

        default:
            if let codableValue = value as? any Codable {
                try codableValue.encode(to: encoder)
            } else {
                throw EncodingError.invalidValue(value, 
                    EncodingError.Context(codingPath: encoder.codingPath, 
                                        debugDescription: "Value is not Codable"))
            }
        }
    }
}

// MARK: - Position and Range

/// Position in a text document
public struct Position: Codable, Sendable, Hashable {
    /// Line position (zero-based)
    public let line: Int
    /// Character offset on a line (zero-based)
    public let character: Int
    
    public init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }
}

/// A range in a text document
public struct LSPRange: Codable, Sendable, Hashable {
    /// The range's start position
    public let start: Position
    /// The range's end position
    public let end: Position
    
    public init(start: Position, end: Position) {
        self.start = start
        self.end = end
    }
}

/// A location inside a resource, such as a line inside a text file
public struct Location: Codable, Sendable {
    public let uri: String
    public let range: LSPRange
    
    public init(uri: String, range: LSPRange) {
        self.uri = uri
        self.range = range
    }
}

// MARK: - Text Document Types

/// Text document identifier
public struct TextDocumentIdentifier: Codable, Sendable {
    /// The text document's URI
    public let uri: String
    
    public init(uri: String) {
        self.uri = uri
    }
}

/// Versioned text document identifier
public struct VersionedTextDocumentIdentifier: Codable, Sendable {
    /// The text document's URI
    public let uri: String
    /// The version number of this document
    public let version: Int
    
    public init(uri: String, version: Int) {
        self.uri = uri
        self.version = version
    }
}

/// An item to transfer a text document from the client to the server
public struct TextDocumentItem: Codable, Sendable {
    /// The text document's URI
    public let uri: String
    /// The text document's language identifier
    public let languageId: String
    /// The version number of this document
    public let version: Int
    /// The content of the opened text document
    public let text: String
    
    public init(uri: String, languageId: String, version: Int, text: String) {
        self.uri = uri
        self.languageId = languageId
        self.version = version
        self.text = text
    }
}

/// An event describing a change to a text document
public struct TextDocumentContentChangeEvent: Codable, Sendable {
    /// The range of the document that changed
    public let range: LSPRange?
    /// The length of the range that got replaced
    public let rangeLength: Int?
    /// The new text of the range/document
    public let text: String
    
    public init(range: LSPRange? = nil, rangeLength: Int? = nil, text: String) {
        self.range = range
        self.rangeLength = rangeLength
        self.text = text
    }
}

// MARK: - Capabilities

/// Client capabilities
public struct ClientCapabilities: Codable, Sendable {
    public let textDocument: TextDocumentClientCapabilities?
    public let workspace: WorkspaceClientCapabilities?
    public let window: WindowClientCapabilities?
    
    public init(
        textDocument: TextDocumentClientCapabilities? = nil,
        workspace: WorkspaceClientCapabilities? = nil,
        window: WindowClientCapabilities? = nil
    ) {
        self.textDocument = textDocument
        self.workspace = workspace
        self.window = window
    }
    
    public static let `default` = Self(
        textDocument: TextDocumentClientCapabilities.default,
        workspace: WorkspaceClientCapabilities.default,
        window: WindowClientCapabilities.default
    )
}

/// Text document client capabilities
public struct TextDocumentClientCapabilities: Codable, Sendable {
    public let completion: CompletionClientCapabilities?
    public let hover: HoverClientCapabilities?
    public let definition: DefinitionClientCapabilities?
    public let publishDiagnostics: PublishDiagnosticsClientCapabilities?
    
    public init(
        completion: CompletionClientCapabilities? = nil,
        hover: HoverClientCapabilities? = nil,
        definition: DefinitionClientCapabilities? = nil,
        publishDiagnostics: PublishDiagnosticsClientCapabilities? = nil
    ) {
        self.completion = completion
        self.hover = hover
        self.definition = definition
        self.publishDiagnostics = publishDiagnostics
    }
    
    public static let `default` = Self(
        completion: CompletionClientCapabilities.default,
        hover: HoverClientCapabilities.default,
        definition: DefinitionClientCapabilities.default,
        publishDiagnostics: PublishDiagnosticsClientCapabilities.default
    )
}

/// Completion client capabilities
public struct CompletionClientCapabilities: Codable, Sendable {
    public let dynamicRegistration: Bool?
    public let completionItem: CompletionItemClientCapabilities?
    
    public init(dynamicRegistration: Bool? = nil, completionItem: CompletionItemClientCapabilities? = nil) {
        self.dynamicRegistration = dynamicRegistration
        self.completionItem = completionItem
    }
    
    public static let `default` = Self(
        dynamicRegistration: true,
        completionItem: CompletionItemClientCapabilities.default
    )
}

/// Completion item client capabilities
public struct CompletionItemClientCapabilities: Codable, Sendable {
    public let snippetSupport: Bool?
    public let documentationFormat: [MarkupKind]?
    
    public init(snippetSupport: Bool? = nil, documentationFormat: [MarkupKind]? = nil) {
        self.snippetSupport = snippetSupport
        self.documentationFormat = documentationFormat
    }
    
    public static let `default` = Self(
        snippetSupport: true,
        documentationFormat: [.markdown, .plaintext]
    )
}

/// Hover client capabilities
public struct HoverClientCapabilities: Codable, Sendable {
    public let dynamicRegistration: Bool?
    public let contentFormat: [MarkupKind]?
    
    public init(dynamicRegistration: Bool? = nil, contentFormat: [MarkupKind]? = nil) {
        self.dynamicRegistration = dynamicRegistration
        self.contentFormat = contentFormat
    }
    
    public static let `default` = Self(
        dynamicRegistration: true,
        contentFormat: [.markdown, .plaintext]
    )
}

/// Definition client capabilities
public struct DefinitionClientCapabilities: Codable, Sendable {
    public let dynamicRegistration: Bool?
    
    public init(dynamicRegistration: Bool? = nil) {
        self.dynamicRegistration = dynamicRegistration
    }
    
    public static let `default` = Self(dynamicRegistration: true)
}

/// Publish diagnostics client capabilities
public struct PublishDiagnosticsClientCapabilities: Codable, Sendable {
    public let relatedInformation: Bool?
    public let tagSupport: DiagnosticTagSupport?
    
    public init(relatedInformation: Bool? = nil, tagSupport: DiagnosticTagSupport? = nil) {
        self.relatedInformation = relatedInformation
        self.tagSupport = tagSupport
    }
    
    public static let `default` = Self(
        relatedInformation: true,
        tagSupport: DiagnosticTagSupport.default
    )
}

/// Diagnostic tag support
public struct DiagnosticTagSupport: Codable, Sendable {
    public let valueSet: [DiagnosticTag]
    
    public init(valueSet: [DiagnosticTag]) {
        self.valueSet = valueSet
    }
    
    public static let `default` = Self(valueSet: [.unnecessary, .deprecated])
}

/// Workspace client capabilities
public struct WorkspaceClientCapabilities: Codable, Sendable {
    public let workspaceFolders: Bool?
    public let configuration: Bool?
    
    public init(workspaceFolders: Bool? = nil, configuration: Bool? = nil) {
        self.workspaceFolders = workspaceFolders
        self.configuration = configuration
    }
    
    public static let `default` = Self(
        workspaceFolders: true,
        configuration: true
    )
}

/// Window client capabilities
public struct WindowClientCapabilities: Codable, Sendable {
    public let showMessage: ShowMessageRequestClientCapabilities?
    
    public init(showMessage: ShowMessageRequestClientCapabilities? = nil) {
        self.showMessage = showMessage
    }
    
    public static let `default` = Self(
        showMessage: ShowMessageRequestClientCapabilities.default
    )
}

/// Show message request client capabilities
public struct ShowMessageRequestClientCapabilities: Codable, Sendable {
    public let messageActionItem: MessageActionItemClientCapabilities?
    
    public init(messageActionItem: MessageActionItemClientCapabilities? = nil) {
        self.messageActionItem = messageActionItem
    }
    
    public static let `default` = Self(
        messageActionItem: MessageActionItemClientCapabilities.default
    )
}

/// Message action item client capabilities
public struct MessageActionItemClientCapabilities: Codable, Sendable {
    public let additionalPropertiesSupport: Bool?
    
    public init(additionalPropertiesSupport: Bool? = nil) {
        self.additionalPropertiesSupport = additionalPropertiesSupport
    }
    
    public static let `default` = Self(additionalPropertiesSupport: true)
}

/// Server capabilities
public struct ServerCapabilities: Codable, Sendable {
    public let textDocumentSync: TextDocumentSyncOptions?
    public let completionProvider: CompletionOptions?
    public let hoverProvider: Bool?
    public let definitionProvider: Bool?
    public let documentSymbolProvider: Bool?
    
    public init(
        textDocumentSync: TextDocumentSyncOptions? = nil,
        completionProvider: CompletionOptions? = nil,
        hoverProvider: Bool? = nil,
        definitionProvider: Bool? = nil,
        documentSymbolProvider: Bool? = nil
    ) {
        self.textDocumentSync = textDocumentSync
        self.completionProvider = completionProvider
        self.hoverProvider = hoverProvider
        self.definitionProvider = definitionProvider
        self.documentSymbolProvider = documentSymbolProvider
    }
}

/// Text document sync options
public struct TextDocumentSyncOptions: Codable, Sendable {
    public let openClose: Bool?
    public let change: TextDocumentSyncKind?
    
    public init(openClose: Bool? = nil, change: TextDocumentSyncKind? = nil) {
        self.openClose = openClose
        self.change = change
    }
}

/// Text document sync kind
public enum TextDocumentSyncKind: Int, Codable, Sendable {
    case none = 0
    case full = 1
    case incremental = 2
}

/// Completion options
public struct CompletionOptions: Codable, Sendable {
    public let triggerCharacters: [String]?
    public let allCommitCharacters: [String]?
    public let resolveProvider: Bool?
    
    public init(
        triggerCharacters: [String]? = nil,
        allCommitCharacters: [String]? = nil,
        resolveProvider: Bool? = nil
    ) {
        self.triggerCharacters = triggerCharacters
        self.allCommitCharacters = allCommitCharacters
        self.resolveProvider = resolveProvider
    }
}

// MARK: - Markup

/// Markup content kind
public enum MarkupKind: String, Codable, Sendable {
    case plaintext = "plaintext"
    case markdown = "markdown"
}

/// Markup content
public struct MarkupContent: Codable, Sendable {
    public let kind: MarkupKind
    public let value: String
    
    public init(kind: MarkupKind, value: String) {
        self.kind = kind
        self.value = value
    }
}

// MARK: - Diagnostic Types

/// Diagnostic severity
public enum DiagnosticSeverity: Int, Codable, Sendable {
    case error = 1
    case warning = 2
    case information = 3
    case hint = 4
}

/// Diagnostic tag
public enum DiagnosticTag: Int, Codable, Sendable {
    case unnecessary = 1
    case deprecated = 2
}

/// Represents a diagnostic, such as a compiler error or warning
public struct Diagnostic: Codable, Sendable {
    public let range: LSPRange
    public let severity: DiagnosticSeverity?
    public let code: DiagnosticCode?
    public let source: String?
    public let message: String
    public let tags: [DiagnosticTag]?
    public let relatedInformation: [DiagnosticRelatedInformation]?
    
    public init(
        range: LSPRange,
        severity: DiagnosticSeverity? = nil,
        code: DiagnosticCode? = nil,
        source: String? = nil,
        message: String,
        tags: [DiagnosticTag]? = nil,
        relatedInformation: [DiagnosticRelatedInformation]? = nil
    ) {
        self.range = range
        self.severity = severity
        self.code = code
        self.source = source
        self.message = message
        self.tags = tags
        self.relatedInformation = relatedInformation
    }
}

/// Diagnostic code (can be string or number)
public enum DiagnosticCode: Codable, Sendable {
    case string(String)
    case number(Int)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .number(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(Self.self, 
                DecodingError.Context(codingPath: decoder.codingPath, 
                                    debugDescription: "Expected string or number"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)

        case .number(let value):
            try container.encode(value)
        }
    }
}

/// Diagnostic related information
public struct DiagnosticRelatedInformation: Codable, Sendable {
    public let location: Location
    public let message: String
    
    public init(location: Location, message: String) {
        self.location = location
        self.message = message
    }
}

// MARK: - Workspace Types

/// Workspace folder
public struct WorkspaceFolder: Codable, Sendable {
    public let uri: String
    public let name: String
    
    public init(uri: String, name: String) {
        self.uri = uri
        self.name = name
    }
}
