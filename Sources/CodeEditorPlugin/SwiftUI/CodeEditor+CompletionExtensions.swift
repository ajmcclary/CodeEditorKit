#if canImport(SwiftUI)
import Foundation

// MARK: - Completion Types

/// Context information provided to code completion providers.
///
/// Contains the current state of the editor when code completion is triggered,
/// allowing completion providers to generate contextually appropriate suggestions.
public struct CompletionContext: Sendable {
    /// The full text content of the editor
    public let text: String
    
    /// The current cursor position as a character offset
    public let cursorPosition: Int
    
    /// The programming language being edited
    public let language: Language
    
    /// Creates a new completion context.
    ///
    /// - Parameters:
    ///   - text: The full text content of the editor
    ///   - cursorPosition: The current cursor position as a character offset
    ///   - language: The programming language being edited
    public init(text: String, cursorPosition: Int, language: Language) {
        self.text = text
        self.cursorPosition = cursorPosition
        self.language = language
    }
}

/// A code completion item for SwiftUI code editors.
///
/// Represents a single completion suggestion with metadata for display and insertion.
public struct SwiftUICompletionItem {
    /// The display label shown in the completion popup
    public let label: String
    
    /// The type of completion item (affects icon and sorting)
    public let kind: CompletionKind
    
    /// Optional additional detail text shown alongside the label
    public let detail: String?
    
    /// The text to insert when this completion is selected
    public let insertText: String
    
    /// Optional documentation shown in completion details
    public let documentation: String?
    
    /// Creates a new completion item.
    ///
    /// - Parameters:
    ///   - label: The display label shown in the completion popup
    ///   - kind: The type of completion item
    ///   - detail: Optional additional detail text
    ///   - insertText: The text to insert (defaults to label if nil)
    ///   - documentation: Optional documentation for this item
    public init(
        label: String,
        kind: CompletionKind,
        detail: String? = nil,
        insertText: String? = nil,
        documentation: String? = nil
    ) {
        self.label = label
        self.kind = kind
        self.detail = detail
        self.insertText = insertText ?? label
        self.documentation = documentation
    }
}

/// The type of a code completion item.
///
/// Determines the icon displayed and affects sorting order in completion lists.
/// Each kind represents a different type of code element that can be suggested
/// during code completion.
///
/// ## Completion Priority
///
/// Completion items are typically sorted by relevance and then by kind:
/// 1. Context-specific matches (variables in scope, methods on current type)
/// 2. Keywords relevant to the current context
/// 3. Types and modules
/// 4. Snippets and text completions
///
/// ## Example
///
/// ```swift
/// let completion = SwiftUICompletionItem(
///     label: "forEach",
///     kind: .method,
///     detail: "Iterate over elements",
///     insertText: "forEach { <#element#> in\n    <#code#>\n}"
/// )
/// ```
///
/// - SeeAlso: ``SwiftUICompletionItem``, ``CompletionContext``
public enum CompletionKind {
    /// Programming language keywords (if, for, class, etc.).
    ///
    /// Reserved words in the programming language that have special meaning.
    /// Examples: `if`, `else`, `for`, `while`, `return`, `class`, `func`
    case keyword
    
    /// Function definitions.
    ///
    /// Standalone functions or global functions available in the current scope.
    /// Typically shown with parentheses to indicate they're callable.
    case function
    
    /// Method calls on objects.
    ///
    /// Instance or class methods that can be called on objects.
    /// Distinguished from functions as they belong to a type.
    case method
    
    /// Variable references.
    ///
    /// Local variables, parameters, or mutable properties in scope.
    /// Represents values that can be read and modified.
    case variable
    
    /// Constant values.
    ///
    /// Immutable values like constants, enum cases, or read-only properties.
    /// Indicates values that cannot be modified after initialization.
    case constant
    
    /// Class definitions.
    ///
    /// Class types available for instantiation or reference.
    /// Typically shown when completing type annotations or constructors.
    case `class`
    
    /// Struct definitions.
    ///
    /// Value types defined as structs in the codebase.
    /// Common in Swift for defining data models and value semantics.
    case `struct`
    
    /// Enum definitions.
    ///
    /// Enumeration types with their associated cases.
    /// Used for types with a fixed set of possible values.
    case `enum`
    
    /// Interface or protocol definitions.
    ///
    /// Protocol types that define requirements for conforming types.
    /// In Swift, these are protocols; in TypeScript, interfaces.
    case interface
    
    /// Module or namespace references.
    ///
    /// Top-level modules, frameworks, or namespaces that can be imported.
    /// Examples: `Foundation`, `UIKit`, `SwiftUI`
    case module
    
    /// Property access.
    ///
    /// Properties of objects, including computed properties and subscripts.
    /// Distinguished from variables as they belong to a type instance.
    case property
    
    /// Value literals.
    ///
    /// Literal values like numbers, strings, or boolean values.
    /// Often used for suggesting common values in specific contexts.
    case value
    
    /// Reference to other symbols.
    ///
    /// Generic references to symbols that don't fit other categories.
    /// Used as a fallback for completion items of unknown type.
    case reference
    
    /// Code snippets with placeholders.
    ///
    /// Multi-line code templates with placeholders for user input.
    /// Examples: loop structures, guard statements, class templates.
    /// Placeholders are typically in the format `<#placeholder#>`.
    case snippet
    
    /// Plain text completion.
    ///
    /// Simple text completions without special semantic meaning.
    /// Used for comments, strings, or documentation completions.
    case text
}

#endif
