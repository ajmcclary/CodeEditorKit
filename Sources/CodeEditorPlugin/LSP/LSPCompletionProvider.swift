import Foundation
import os.log

/// LSP-based completion provider that integrates with the CodeEditorView completion system
@MainActor
public final class LSPCompletionProvider: CompletionProvider {
    // MARK: - Properties
    
    public let id: String = "lsp-completion-provider"
    public let displayName: String = "LSP Completion Provider"
    public let supportedLanguages: [Language]
    
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
        self.supportedLanguages = supportedLanguages.isEmpty ? Language.allCases : supportedLanguages
    }
    
    // MARK: - CompletionProvider Protocol
    
    public func canProvideCompletion(for language: Language, in _: CompletionContextModel) -> Bool {
        guard let lspManager else { return false }
        
        // Check if we have a language server for this language
        let languageId = languageIdForLanguage(language)
        return lspManager.client(for: languageId) != nil
    }
    
    public func requestCompletions(for context: CompletionContextModel) async -> CompletionResult {
        guard let lspManager,
              let filePath = currentFilePath else {
            return CompletionResult.failure("No LSP manager or file path available")
        }
        
        let languageId = languageIdForLanguage(context.language)
        
        // Check if LSP client is available
        guard lspManager.client(for: languageId) != nil else {
            logger.debug("No LSP client available for language: \(languageId)")
            return CompletionResult.failure("No LSP client available for \(languageId)")
        }
        
        do {
            // Convert cursor position to line/character
            let position = convertPositionToLineCharacter(
                position: context.triggerPosition,
                in: context.fullText
            )
            
            // Request completion from LSP server
            let lspItems = try await lspManager.requestCompletion(
                filePath: filePath,
                line: position.line,
                character: position.character
            )
            
            // Convert LSP completion items to our completion model
            let completionItems = lspItems.map { lspItem in
                convertLSPItemToCompletionItem(lspItem.item, context: context)
            }
            
            logger.debug("LSP completion returned \(completionItems.count) items")
            
            return CompletionResult.success(
                items: completionItems,
                isIncomplete: false // LSP handles incremental completion internally
            )
        } catch {
            logger.error("LSP completion failed: \(error.localizedDescription)")
            return CompletionResult.failure("LSP completion failed: \(error.localizedDescription)")
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

        case .regex(let pattern):
            // Try to infer language from regex pattern context
            // This is a simplified mapping - could be improved
            if pattern.description.contains("javascript") || pattern.description.contains("js") {
                return "javascript"
            } else if pattern.description.contains("typescript") || pattern.description.contains("ts") {
                return "typescript"
            } else if pattern.description.contains("python") || pattern.description.contains("py") {
                return "python"
            } else {
                return "plaintext"
            }

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
                range: convertLSPRangeToNSRange(lspTextEdit.range, in: context.fullText),
                newText: lspTextEdit.newText
            )
        }
        
        // Create completion item
        return CompletionItemModel(
            label: lspItem.label,
            kind: kind,
            detail: lspItem.detail,
            documentation: documentation,
            insertText: insertText,
            sortText: lspItem.sortText,
            filterText: lspItem.filterText,
            textEdit: textEdit,
            additionalTextEdits: lspItem.additionalTextEdits?.map { lspEdit in
                CompletionTextEdit(
                    range: convertLSPRangeToNSRange(lspEdit.range, in: context.fullText),
                    newText: lspEdit.newText
                )
            },
            commitCharacters: lspItem.commitCharacters,
            data: nil // LSP-specific data could be stored here if needed
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
        let nsString = text as NSString
        
        // Convert line/character positions to string indices
        let lines = text.components(separatedBy: .newlines)
        
        // Calculate start position
        var startIndex = 0
        for i in 0..<min(lspRange.start.line, lines.count) {
            startIndex += lines[i].count + 1 // +1 for newline
        }
        startIndex += lspRange.start.character
        startIndex = min(startIndex, nsString.length)
        
        // Calculate end position
        var endIndex = 0
        for i in 0..<min(lspRange.end.line, lines.count) {
            endIndex += lines[i].count + 1 // +1 for newline
        }
        endIndex += lspRange.end.character
        endIndex = min(endIndex, nsString.length)
        
        let location = min(startIndex, nsString.length)
        let length = max(0, min(endIndex - startIndex, nsString.length - location))
        
        return NSRange(location: location, length: length)
    }
}

// MARK: - Extensions for LSP Integration

extension CompletionItemKind {
    /// Convert to LSP completion item kind  
    public var asLSPKind: CodeEditorPlugin.LSPCompletionItemKind {
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
