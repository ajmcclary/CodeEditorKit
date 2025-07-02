import Foundation
import os.log

/// LSP-based completion provider that integrates with the CodeEditorView completion system
@MainActor
public final class LSPCompletionProvider: CompletionProvider {
    // MARK: - Properties
    
    public let id: String = "lsp-completion-provider"
    public let displayName: String = "LSP Completion Provider"
    public let supportedLanguages: [Language]
    public let triggerCharacters: [String] = [".", ":", "(", "[", "<", " "]
    
    /// LSP manager reference
    private weak var lspManager: LSPManager?
    
    /// Current file path for completion context
    private var currentFilePath: String?
    
    /// Logger for debugging
    private let logger = Logger(subsystem: "com.codeeditor.lsp", category: "LSPCompletionProvider")
    
    // MARK: - Initialization
    
    public init(lspManager: LSPManager, supportedLanguages: [Language] = []) {
        self.lspManager = lspManager
        // Support all languages if none specified (LSP servers will determine actual support)
        self.supportedLanguages = supportedLanguages.isEmpty ? [] : supportedLanguages
    }
    
    // MARK: - CompletionProvider Protocol
    
    public func completions(for context: CompletionContextModel) async throws -> CompletionResult {
        await requestCompletions(for: context)
    }
    
    public func canProvideCompletion(for language: Language, in _: CompletionContextModel) -> Bool {
        guard let lspManager else { return false }
        
        // Check if we have a language server for this language
        let languageId = languageIdForLanguage(language)
        return lspManager.client(for: languageId) != nil
    }
    
    public func requestCompletions(for context: CompletionContextModel) async -> CompletionResult {
        guard let lspManager,
              let filePath = currentFilePath else {
            return CompletionResult(
                items: [],
                context: context,
                isIncomplete: false,
                processingTime: 0
            )
        }
        
        let languageId = languageIdForLanguage(context.language)
        
        // Check if LSP client is available
        guard lspManager.client(for: languageId) != nil else {
            logger.debug("No LSP client available for language: \(languageId)")
            return CompletionResult(
                items: [],
                context: context,
                isIncomplete: false,
                processingTime: 0
            )
        }
        
        do {
            // Convert cursor position to line/character
            let position = convertPositionToLineCharacter(
                position: context.cursorPosition,
                in: context.text
            )
            
            // Request completion from LSP server
            let lspItems = try await lspManager.requestCompletion(
                filePath: filePath,
                line: position.line,
                character: position.character
            )
            
            // Convert LSP completion items to our completion model
            let completionItems = lspItems.compactMap { lspItem in
                // Extract the actual LSP item from the wrapper
                let actualLSPItem = lspItem
                if let convertedItem = actualLSPItem.item as? CompletionItemAdapter {
                    return convertedItem.model
                }
                return nil
            }
            
            logger.debug("LSP completion returned \(completionItems.count) items")
            
            return CompletionResult(
                items: completionItems,
                context: context,
                isIncomplete: false, // LSP handles incremental completion internally
                processingTime: 0
            )
        } catch {
            logger.error("LSP completion failed: \(error.localizedDescription)")
            return CompletionResult(
                items: [],
                context: context,
                isIncomplete: false,
                processingTime: 0
            )
        }
    }
    
    public func updateContext(filePath: String?, text: String) {
        self.currentFilePath = filePath
        
        // Update document in LSP manager if needed
        guard let lspManager,
              let filePath else { return }
        
        Task {
            do {
                // Check if document is already open, if not open it
                try await lspManager.updateDocument(filePath: filePath, content: text)
            } catch {
                // Document might not be open yet, try opening it
                do {
                    try await lspManager.openDocument(filePath: filePath, content: text)
                } catch {
                    logger.error("Failed to open/update document in LSP: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func languageIdForLanguage(_ language: Language) -> String {
        switch language {
        case .swift:
            return "swift"

        case .javascript:
            return "javascript"

        case .typescript:
            return "typescript"

        case .python:
            return "python"

        case .go:
            return "go"

        case .rust:
            return "rust"

        case .c:
            return "c"

        case .cpp:
            return "cpp"

        case .java:
            return "java"

        case .html:
            return "html"

        case .css:
            return "css"

        case .json:
            return "json"

        case .markdown:
            return "markdown"

        case .yaml:
            return "yaml"

        case .xml:
            return "xml"

        case .sql:
            return "sql"

        case .ruby:
            return "ruby"

        case .php:
            return "php"

        case .shell:
            return "shell"

        case .plainText:
            return "plaintext"
        }
    }
    
    private func convertPositionToLineCharacter(position: Int, in text: String) -> (line: Int, character: Int) {
        let lines = text.prefix(position).components(separatedBy: .newlines)
        let line = max(0, lines.count - 1)
        let character = lines.last?.count ?? 0
        
        return (line: line, character: character)
    }
    
    private func convertLSPItemToCompletionItem(
        _ lspItem: LSPCompletionItem,
        context: CompletionContextModel
    ) -> CompletionItemModel {
        // Convert LSP completion item kind to our kind
        let kind = convertLSPKindToCompletionKind(lspItem.kind)
        
        // Extract documentation
        let documentation = extractDocumentation(from: lspItem.documentation)
        
        // Determine insert text
        let insertText = lspItem.insertText ?? lspItem.label
        
        // Handle text edits
        var textEdit: CompletionTextEdit?
        if let lspTextEdit = lspItem.textEdit {
            textEdit = CompletionTextEdit(
                range: convertLSPRangeToNSRange(lspTextEdit.range, in: context.text),
                newText: lspTextEdit.newText
            )
        }
        
        // Create completion item
        return CompletionItemModel(
            label: lspItem.label,
            insertText: insertText,
            kind: kind,
            detail: lspItem.detail,
            documentation: documentation,
            sortText: lspItem.sortText,
            filterText: lspItem.filterText,
            textEdit: textEdit,
            additionalTextEdits: lspItem.additionalTextEdits.map { lspEdit in
                CompletionTextEdit(
                    range: convertLSPRangeToNSRange(lspEdit.range, in: context.text),
                    newText: lspEdit.newText
                )
            }
        )
    }
    
    private func convertLSPKindToCompletionKind(_ lspKind: LSPCompletionItemKind?) -> CompletionItemKind {
        guard let lspKind else { return .text }
        
        switch lspKind {
        case .text:
            return .text

        case .method:
            return .method

        case .function:
            return .function

        case .constructor:
            return .constructor

        case .field:
            return .field

        case .variable:
            return .variable

        case .class:
            return .class

        case .interface:
            return .interface

        case .module:
            return .module

        case .property:
            return .property

        case .unit:
            return .unit

        case .value:
            return .value

        case .enum:
            return .enum

        case .keyword:
            return .keyword

        case .snippet:
            return .snippet

        case .color:
            return .color

        case .file:
            return .file

        case .reference:
            return .reference

        case .folder:
            return .folder

        case .enumMember:
            return .enumMember

        case .constant:
            return .constant

        case .struct:
            return .struct

        case .event:
            return .event

        case .operator:
            return .operator

        case .typeParameter:
            return .typeParameter
        }
    }
    
    private func extractDocumentation(from lspDoc: CompletionItemDocumentation?) -> String? {
        guard let lspDoc else { return nil }
        
        switch lspDoc {
        case .string(let text):
            return text

        case .markupContent(let markupContent):
            return markupContent.value
        }
    }
    
    private func convertLSPRangeToNSRange(_ lspRange: LSPRange, in text: String) -> NSRange {
        let utf16Count = text.utf16.count
        
        // Convert line/character positions to string indices
        let lines = text.components(separatedBy: .newlines)
        
        // Calculate start position
        var startIndex = 0
        for index in 0..<min(lspRange.start.line, lines.count) {
            startIndex += lines[index].count + 1 // +1 for newline
        }
        startIndex += lspRange.start.character
        startIndex = min(startIndex, utf16Count)
        
        // Calculate end position
        var endIndex = 0
        for index in 0..<min(lspRange.end.line, lines.count) {
            endIndex += lines[index].count + 1 // +1 for newline
        }
        endIndex += lspRange.end.character
        endIndex = min(endIndex, utf16Count)
        
        let location = min(startIndex, utf16Count)
        let length = max(0, min(endIndex - startIndex, utf16Count - location))
        
        return NSRange(location: location, length: length)
    }
}

// MARK: - Extensions for LSP Integration

extension CompletionItemKind {
    /// Convert to LSP completion item kind  
    public var asLSPKind: LSPCompletionItemKind {
        switch self {
        case .text: return .text
        case .method: return .method
        case .function: return .function
        case .constructor: return .constructor
        case .field: return .field
        case .variable: return .variable
        case .class: return .class
        case .interface: return .interface
        case .module: return .module
        case .property: return .property
        case .unit: return .unit
        case .value: return .value
        case .enum: return .enum
        case .keyword: return .keyword
        case .snippet: return .snippet
        case .color: return .color
        case .file: return .file
        case .reference: return .reference
        case .folder: return .folder
        case .enumMember: return .enumMember
        case .constant: return .constant
        case .struct: return .struct
        case .event: return .event
        case .operator: return .operator
        case .typeParameter: return .typeParameter
        }
    }
}
