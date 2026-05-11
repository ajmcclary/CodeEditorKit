import Foundation

// MARK: - Errors

/// Errors that can occur during completion request operations
public enum CompletionRequestError: Error {
    case noActiveRequest
}

// MARK: - Completion Item Model

/// Represents a code completion item with comprehensive metadata.
///
/// `CompletionItemModel` encapsulates all information needed to display and insert
/// a code completion suggestion. It supports advanced features like snippets,
/// text edits, and documentation.
///
/// ## Example
///
/// ```swift
/// let completion = CompletionItemModel(
///     label: "forEach",
///     insertText: "forEach { <#element#> in\n    <#code#>\n}",
///     kind: .method,
///     detail: "(body: (Element) -> Void) -> Void",
///     documentation: "Calls the given closure on each element in the sequence.",
///     snippetSupport: true,
///     priority: 100
/// )
/// ```
///
/// - SeeAlso: ``CompletionItemKind``, ``CompletionProvider``, ``CompletionManager``
public struct CompletionItemModel: Identifiable, Sendable {
    public let id: String

    // Core completion data
    public let label: String
    public let insertText: String
    public let kind: CompletionItemKind
    public let detail: String?
    public let documentation: String?

    // Advanced features
    public let sortText: String?
    public let filterText: String?
    public let priority: Int
    public let snippetSupport: Bool

    // Visual presentation
    public let deprecated: Bool
    public let preselect: Bool

    // Text editing
    public let textEdit: CompletionTextEdit?
    public let additionalTextEdits: [CompletionTextEdit]

    public init(
        label: String,
        insertText: String? = nil,
        kind: CompletionItemKind = .text,
        detail: String? = nil,
        documentation: String? = nil,
        sortText: String? = nil,
        filterText: String? = nil,
        priority: Int = 0,
        snippetSupport: Bool = false,
        deprecated: Bool = false,
        preselect: Bool = false,
        textEdit: CompletionTextEdit? = nil,
        additionalTextEdits: [CompletionTextEdit] = [],
        id: String? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.label = label
        self.insertText = insertText ?? label
        self.kind = kind
        self.detail = detail
        self.documentation = documentation
        self.sortText = sortText
        self.filterText = filterText
        self.priority = priority
        self.snippetSupport = snippetSupport
        self.deprecated = deprecated
        self.preselect = preselect
        self.textEdit = textEdit
        self.additionalTextEdits = additionalTextEdits
    }
}

// MARK: - Completion Kind

/// Types of completion items, compatible with LSP.
///
/// Each kind represents a different type of code element and affects how the
/// completion is displayed (icon) and sorted (priority).
///
/// ## Icons and Priority
///
/// Each kind has an associated icon for visual representation and a default
/// priority that affects sorting in the completion list.
///
/// - SeeAlso: ``CompletionItemModel``, ``CompletionProvider``
public enum CompletionItemKind: String, CaseIterable, Sendable {
    case text = "Text"
    case method = "Method"
    case function = "Function"
    case constructor = "Constructor"
    case field = "Field"
    case variable = "Variable"
    case `class` = "Class"
    case interface = "Interface"
    case module = "Module"
    case property = "Property"
    case unit = "Unit"
    case value = "Value"
    case `enum` = "Enum"
    case keyword = "Keyword"
    case snippet = "Snippet"
    case color = "Color"
    case file = "File"
    case reference = "Reference"
    case folder = "Folder"
    case enumMember = "EnumMember"
    case constant = "Constant"
    case `struct` = "Struct"
    case event = "Event"
    case `operator` = "Operator"
    case typeParameter = "TypeParameter"

    /// Icon character for visual representation
    public var icon: String {
        switch self {
        case .text: return "𝘛"
        case .method: return "𝘮"
        case .function: return "𝑓"
        case .constructor: return "𝘤"
        case .field: return "𝘍"
        case .variable: return "𝘷"
        case .class: return "𝘊"
        case .interface: return "𝘐"
        case .module: return "𝘔"
        case .property: return "𝘱"
        case .unit: return "𝘜"
        case .value: return "𝘝"
        case .enum: return "𝘌"
        case .keyword: return "𝘬"
        case .snippet: return "𝘚"
        case .color: return "🎨"
        case .file: return "📄"
        case .reference: return "🔗"
        case .folder: return "📁"
        case .enumMember: return "𝘦"
        case .constant: return "𝘊"
        case .struct: return "𝘴"
        case .event: return "⚡"
        case .operator: return "⊕"
        case .typeParameter: return "𝘛"
        }
    }

    /// Priority for sorting (higher is better)
    public var defaultPriority: Int {
        switch self {
        case .keyword: return 100
        case .snippet: return 90
        case .method, .function: return 80
        case .property, .field: return 70
        case .variable: return 60
        case .class, .struct, .enum: return 50
        case .constant: return 40
        case .interface: return 30
        case .module: return 20
        default: return 10
        }
    }
}

// MARK: - Text Edit

/// Represents a text edit for completion insertion.
///
/// Defines how text should be modified when a completion is accepted.
/// Supports replacing existing text ranges, not just insertion at cursor.
///
/// ## Example
///
/// ```swift
/// // Replace "pri" with "private"
/// let edit = CompletionTextEdit(
///     range: NSRange(location: 10, length: 3),
///     newText: "private"
/// )
/// ```
///
/// - SeeAlso: ``CompletionItemModel``
public struct CompletionTextEdit: Sendable {
    public let range: NSRange
    public let newText: String

    public init(range: NSRange, newText: String) {
        self.range = range
        self.newText = newText
    }
}

// MARK: - Completion Context

/// Context information for code completion requests.
///
/// Provides all necessary information about the editor state when completion
/// was triggered, including cursor position, surrounding text, and trigger type.
///
/// ## Example
///
/// ```swift
/// let context = CompletionContextModel(
///     text: "let name = user.",
///     cursorPosition: 16,
///     language: .swift,
///     triggerKind: .character,
///     triggerCharacter: ".",
///     lineText: "let name = user.",
///     wordRange: NSRange(location: 11, length: 4)
/// )
/// ```
///
/// - SeeAlso: ``CompletionTriggerKind``, ``CompletionProvider``
public struct CompletionContextModel: Sendable {
    public let text: String
    public let cursorPosition: Int
    public let language: Language
    public let triggerKind: CompletionTriggerKind
    public let triggerCharacter: String?
    public let lineText: String
    public let wordRange: NSRange?
    public let timestamp: Date

    public init(
        text: String,
        cursorPosition: Int,
        language: Language,
        triggerKind: CompletionTriggerKind = .manual,
        triggerCharacter: String? = nil,
        lineText: String = "",
        wordRange: NSRange? = nil
    ) {
        self.text = text
        self.cursorPosition = cursorPosition
        self.language = language
        self.triggerKind = triggerKind
        self.triggerCharacter = triggerCharacter
        self.lineText = lineText
        self.wordRange = wordRange
        self.timestamp = Date()
    }

    /// Get the current word being typed
    public var currentWord: String {
        guard let wordRange,
              wordRange.location != NSNotFound,
              NSMaxRange(wordRange) <= TextRangeUtilities.utf16Length(of: text) else {
            return ""
        }

        return TextRangeUtilities.substring(inUTF16Range: wordRange, from: text) ?? ""
    }

    /// Text before the cursor, treating `cursorPosition` as a UTF-16 offset.
    public var textBeforeCursor: String {
        TextRangeUtilities.substring(upToUTF16Offset: cursorPosition, in: text)
    }

    /// Current line content before the cursor, treating `cursorPosition` as a UTF-16 offset.
    public var lineTextBeforeCursor: String {
        textBeforeCursor.components(separatedBy: .newlines).last ?? ""
    }
}

// MARK: - Completion Trigger Kind

/// How completion was triggered.
///
/// Indicates whether the user explicitly requested completion or it was
/// triggered automatically by typing certain characters.
///
/// - SeeAlso: ``CompletionContextModel``
public enum CompletionTriggerKind: String, Sendable {
    case manual = "Manual"              // User explicitly requested (Ctrl+Space)
    case character = "Character"        // Triggered by typing a character
    case retrigger = "Retrigger"       // Re-triggered for filtered results
}

// MARK: - Completion Result

/// Result of a completion request.
///
/// Contains the completion items along with metadata about the request,
/// including whether more results are available and processing time.
///
/// ## Example
///
/// ```swift
/// let result = CompletionResult(
///     items: completionItems,
///     context: context,
///     isIncomplete: hasMoreResults,
///     processingTime: 0.05
/// )
/// ```
///
/// - SeeAlso: ``CompletionItemModel``, ``CompletionProvider``
public struct CompletionResult: Sendable {
    public let items: [CompletionItemModel]
    public let isIncomplete: Bool
    public let context: CompletionContextModel
    public let processingTime: TimeInterval

    public init(
        items: [CompletionItemModel],
        context: CompletionContextModel,
        isIncomplete: Bool = false,
        processingTime: TimeInterval = 0
    ) {
        self.items = items
        self.isIncomplete = isIncomplete
        self.context = context
        self.processingTime = processingTime
    }
}
