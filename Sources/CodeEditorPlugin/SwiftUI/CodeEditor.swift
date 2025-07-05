#if canImport(SwiftUI)
@preconcurrency import SwiftUI

extension View {
    @ViewBuilder
    func codeEditorFocusable() -> some View {
        if #available(macOS 14.0, iOS 17.0, macCatalyst 17.0, *) {
            self.focusable()
        } else {
            self
        }
    }
}

/// Modern, idiomatic SwiftUI code editor with declarative configuration.
///
/// `CodeEditor` provides a native SwiftUI interface for code editing with full integration
/// into the SwiftUI environment system. It offers a declarative API for configuration
/// and seamless data binding.
///
/// ## Basic Usage
///
/// ```swift
/// struct ContentView: View {
///     @State private var code = """
///         func greet(name: String) {
///             logger.debug("Hello, \\(name)!")
///         }
///         """
///     
///     var body: some View {
///         CodeEditor(text: $code)
///             .codeLanguage(.swift)
///             .lineNumbers(true)
///             .highlightSelectedLine(true)
///             .frame(height: 400)
///     }
/// }
/// ```
///
/// ## Environment-Based Configuration
///
/// Configure the editor using SwiftUI environment values:
///
/// ```swift
/// @State private var config = EditorConfiguration()
/// 
/// var body: some View {
///     CodeEditor(text: $code)
///         .environment(\\.codeEditorConfiguration, config)
///         .environment(\\.codeEditorLanguage, .swift)
///         .environment(\\.codeEditorTheme, .default)
/// }
/// ```
///
/// ## Modifier Chain Configuration
///
/// Use fluent modifier methods for inline configuration:
///
/// ```swift
/// CodeEditor(text: $code)
///     .codeLanguage(.swift)
///     .lineNumbers(true)
///     .highlightSelectedLine(true)
///     .editable(true)
///     .codeFontSize(16)
///     .tabWidth(4)
///     .showInvisibleCharacters(false)
///     .onTextChange { newText in
///         logger.debug("Text changed: \\(newText.count) characters")
///     }
///     .onSelectionChange { range in
///         logger.debug("Selection changed: \\(range?.description ?? "nil")")
///     }
/// ```
///
/// ## Code Completion
///
/// Add custom code completion providers:
///
/// ```swift
/// CodeEditor(text: $code)
///     .codeCompletion { context in
///         // Return completion items based on context
///         return [
///             SwiftUICompletionItem(
///                 label: "func",
///                 kind: .keyword,
///                 insertText: "func ${1:name}(${2:parameters}) {\n    ${3:body}\n}"
///             )
///         ]
///     }
/// ```
///
/// ## Text Change Debouncing
///
/// Control text change event frequency:
///
/// ```swift
/// CodeEditor(text: $code, debounceInterval: .milliseconds(300))
///     .onTextChange(debounce: .milliseconds(500)) { text in
///         // Called with debouncing
///         performExpensiveOperation(text)
///     }
/// ```
///
/// ## Language Support
///
/// Supported programming languages with syntax highlighting:
/// - Swift (AST-based highlighting)
/// - Python, JavaScript/TypeScript, Rust, C/C++
/// - HTML/CSS, JSON/YAML, Markdown
/// - Go, Java, Ruby, PHP, SQL, XML
///
/// ## Performance Considerations
///
/// - Text changes are debounced by default (100ms) for performance
/// - Large files automatically disable syntax highlighting
/// - Use `EditorConfiguration.performance` to customize limits
/// - Selection changes are not debounced for responsive UI
///
/// ## Platform Support
///
/// - **macOS**: 13.0+ (native NSTextView-based implementation)
/// - **iOS**: 16.0+ (native UITextView-based implementation) 
/// - **Mac Catalyst**: 16.0+ (UIKit implementation)
///
/// For older platform versions (macOS 12.0+, iOS 15.0+), this view may have limited functionality.
@available(macOS 13.0, iOS 16.0, *)
public struct CodeEditor: View {
    // MARK: - Properties
    
    @Binding private var text: String
    
    // Focus management
    @FocusState private var isFocused: Bool
    
    // Search
    @State private var searchText = ""
    @State private var isSearching = false
    
    // Environment
    @Environment(\.codeEditorLanguage) private var language
    @Environment(\.codeEditorTheme) private var theme
    @Environment(\.codeEditorConfiguration) private var configuration
    
    // Callbacks
    private var onTextChange: ((String) -> Void)?
    private var onSelectionChange: ((Range<String.Index>?) -> Void)?
    private var completionProvider: ((CompletionContext) async -> [SwiftUICompletionItem])?
    
    // Debouncing
    private let textDebounceInterval: Duration
    
    // MARK: - Initialization
    
    /// Creates a new code editor with text binding and optional debouncing.
    ///
    /// - Parameters:
    ///   - text: A binding to the text content of the editor
    ///   - debounceInterval: Time interval to debounce text change events (default: 100ms)
    ///
    /// ## Example
    ///
    /// ```swift
    /// @State private var code = "// Enter code here"
    /// 
    /// var body: some View {
    ///     CodeEditor(
    ///         text: $code,
    ///         debounceInterval: .milliseconds(200)
    ///     )
    /// }
    /// ```
    public init(
        text: Binding<String>,
        debounceInterval: Duration = .milliseconds(100)
    ) {
        self._text = text
        self.textDebounceInterval = debounceInterval
    }
    
    // MARK: - Body
    
    public var body: some View {
        CodeEditorRepresentable(
            text: $text,  // Pass the binding directly
            language: language,
            theme: theme,
            configuration: configuration,
            isFocused: Binding(
                get: { isFocused },
                set: { isFocused = $0 }
            ),
            textDebounceInterval: textDebounceInterval,
            onTextChange: handleTextChange,
            onSelectionChange: handleSelectionChange
        )
        .searchable(text: $searchText)
        .codeEditorFocusable()
        .focused($isFocused)
    }
    
    // MARK: - Private Methods
    
    private func handleTextChange(_ newText: String) {
        // The coordinator will handle this, so this can be simplified
        // The text binding is updated directly by the coordinator
        onTextChange?(newText)
    }
    
    private func handleSelectionChange(_ selection: NSRange) {
        // Convert NSRange to Range<String.Index>
        guard let range = Range(selection, in: text) else { return }
        onSelectionChange?(range)
    }
    
    // MARK: - View Modifiers
    
    /// Sets the programming language for syntax highlighting.
    ///
    /// - Parameter language: The programming language to use for syntax highlighting
    /// - Returns: A view with the specified language environment value
    ///
    /// ## Supported Languages
    ///
    /// - Swift (AST-based highlighting with SwiftSyntax)
    /// - Python, JavaScript, TypeScript, Rust, C/C++
    /// - HTML, CSS, JSON, YAML, Markdown
    /// - Go, Java, Ruby, PHP, SQL, XML, and more
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $swiftCode)
    ///     .codeLanguage(.swift)
    /// 
    /// CodeEditor(text: $pythonCode)
    ///     .codeLanguage(.python)
    /// ```
    public func codeLanguage(_ language: Language) -> some View {
        environment(\.codeEditorLanguage, language)
    }
    
    /// Configures the visibility of line numbers in the gutter.
    ///
    /// - Parameter visible: Whether to show line numbers (default: true)
    /// - Returns: A view with updated line number configuration
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .lineNumbers(true)  // Show line numbers
    ///     .lineNumbers(false) // Hide line numbers
    /// ```
    public func lineNumbers(_ visible: Bool = true) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.display.showLineNumbers = visible
        }
    }
    
    /// Configures highlighting of the currently selected line.
    ///
    /// - Parameter highlight: Whether to highlight the selected line (default: true)
    /// - Returns: A view with updated line highlighting configuration
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .highlightSelectedLine(true)  // Highlight current line
    ///     .highlightSelectedLine(false) // No line highlighting
    /// ```
    public func highlightSelectedLine(_ highlight: Bool = true) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.display.highlightSelectedLine = highlight
        }
    }
    
    /// Sets the color theme for the editor.
    ///
    /// - Parameter theme: The theme to apply to the editor
    /// - Returns: A view with the specified theme environment value
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .codeTheme(.default)
    ///     .codeTheme(.monokai)
    ///     .codeTheme(customTheme)
    /// ```
    public func codeTheme(_ theme: CodeEditorSwiftUITheme) -> some View {
        environment(\.codeEditorTheme, theme)
    }
    
    /// Configures whether the editor text is editable.
    ///
    /// - Parameter isEditable: Whether the editor should be editable (default: true)
    /// - Returns: A view with updated editability configuration
    ///
    /// Use `false` for read-only display of code.
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .editable(true)   // Editable editor
    ///     .editable(false)  // Read-only display
    /// ```
    public func editable(_ isEditable: Bool = true) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.behavior.isEditable = isEditable
        }
    }
    
    /// Adds a text change handler with optional debouncing.
    ///
    /// - Parameters:
    ///   - debounce: Optional debounce interval to control callback frequency
    ///   - action: Closure called when text changes
    /// - Returns: A new view with the text change handler attached
    ///
    /// The handler is called whenever the text content changes. Use debouncing
    /// to reduce the frequency of calls for performance-sensitive operations.
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .onTextChange { newText in
    ///         logger.debug("Text changed: \(newText.count) characters")
    ///     }
    ///     .onTextChange(debounce: .milliseconds(500)) { newText in
    ///         // Called with 500ms debouncing
    ///         saveToDatabase(newText)
    ///     }
    /// ```
    public func onTextChange(
        debounce: Duration? = nil,
        perform action: @escaping (String) -> Void
    ) -> Self {
        var copy = self
        copy.onTextChange = action
        if let debounce {
            copy = Self(text: _text, debounceInterval: debounce)
            copy.onTextChange = action
        }
        return copy
    }
    
    /// Adds a selection change handler.
    ///
    /// - Parameter action: Closure called when the text selection changes
    /// - Returns: A new view with the selection change handler attached
    ///
    /// The handler provides the selected range as `Range<String.Index>` or `nil`
    /// if no text is selected. Selection changes are not debounced.
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .onSelectionChange { range in
    ///         if let range = range {
    ///             let selectedText = String(code[range])
    ///             logger.debug("Selected: \(selectedText)")
    ///         } else {
    ///             logger.debug("No selection")
    ///         }
    ///     }
    /// ```
    public func onSelectionChange(
        perform action: @escaping (Range<String.Index>?) -> Void
    ) -> Self {
        var copy = self
        copy.onSelectionChange = action
        return copy
    }
    
    /// Configures a custom code completion provider.
    ///
    /// - Parameter provider: Async closure that returns completion items
    /// - Returns: A new view with the completion provider attached
    ///
    /// The provider is called when the user triggers code completion and receives
    /// a `CompletionContext` with the current text, cursor position, and language.
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .codeCompletion { context in
    ///         let items = await fetchCompletions(
    ///             for: context.language,
    ///             at: context.cursorPosition,
    ///             in: context.text
    ///         )
    ///         return items.map { item in
    ///             SwiftUICompletionItem(
    ///                 label: item.label,
    ///                 kind: item.kind,
    ///                 insertText: item.insertText
    ///             )
    ///         }
    ///     }
    /// ```
    public func codeCompletion(
        provider: @escaping (CompletionContext) async -> [SwiftUICompletionItem]
    ) -> Self {
        var copy = self
        copy.completionProvider = provider
        return copy
    }
    
    /// Configures the font size for the editor text.
    ///
    /// - Parameter size: Font size in points
    /// - Returns: A view with updated font size configuration
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .codeFontSize(12)  // Small text
    ///     .codeFontSize(16)  // Medium text
    ///     .codeFontSize(20)  // Large text (presentation mode)
    /// ```
    public func codeFontSize(_ size: CGFloat) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.display.fontSize = size
        }
    }
    
    /// Configures the tab width in spaces.
    ///
    /// - Parameter width: Number of spaces per tab
    /// - Returns: A view with updated tab width configuration
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .tabWidth(2)  // Compact indentation
    ///     .tabWidth(4)  // Standard indentation
    ///     .tabWidth(8)  // Wide indentation
    /// ```
    public func tabWidth(_ width: Int) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.layout.tabWidth = width
        }
    }
    
    /// Configures the visibility of invisible characters.
    ///
    /// - Parameter show: Whether to show invisible characters (default: true)
    /// - Returns: A view with updated invisible character visibility
    ///
    /// When enabled, displays visual indicators for spaces, tabs, and line endings.
    /// Useful for debugging whitespace issues in code.
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .showInvisibleCharacters(true)   // Show whitespace characters
    ///     .showInvisibleCharacters(false)  // Hide whitespace characters
    /// ```
    public func showInvisibleCharacters(_ show: Bool = true) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.display.showInvisibleCharacters = show
        }
    }
    
    /// Configures the visibility of the minimap.
    ///
    /// - Parameter show: Whether to show the minimap (default: true)
    /// - Returns: A view with updated minimap visibility
    ///
    /// The minimap provides a bird's-eye view of the entire document,
    /// useful for navigation in large files.
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .showMinimap(true)   // Show minimap for navigation
    ///     .showMinimap(false)  // Hide minimap to save space
    /// ```
    public func showMinimap(_ show: Bool = true) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.display.showMinimap = show
        }
    }
    
    /// Configures automatic scrolling to cursor position.
    ///
    /// - Parameter enable: Whether to automatically scroll to cursor (default: false)
    /// - Returns: A view with updated auto-scroll behavior
    ///
    /// When enabled, the editor automatically scrolls to make the cursor
    /// visible when navigating to a specific line or position (e.g., via
    /// minimap clicks, symbol navigation, or search results).
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .autoScrollToCursor(true)   // Enable automatic scrolling
    ///     .autoScrollToCursor(false)  // Disable automatic scrolling (default)
    /// ```
    public func autoScrollToCursor(_ enable: Bool = false) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.behavior.autoScrollToCursor = enable
        }
    }
    
    /// Configures code folding behavior.
    ///
    /// - Parameter enable: Whether to enable code folding (default: true)
    /// - Returns: A view with updated code folding configuration
    ///
    /// When enabled, allows collapsing and expanding code sections like functions,
    /// classes, blocks, and comments for better navigation. Supports 17+ programming
    /// languages with language-specific folding rules.
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .enableCodeFolding(true)   // Enable code folding
    ///     .enableCodeFolding(false)  // Disable code folding
    /// ```
    public func enableCodeFolding(_ enable: Bool = true) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.display.enableCodeFolding = enable
        }
    }
    
    /// Configures the visibility of folding controls in the gutter.
    ///
    /// - Parameter show: Whether to show fold/unfold controls in the gutter (default: true)
    /// - Returns: A view with updated folding controls configuration
    ///
    /// When enabled, displays ▶️/▼ fold/unfold buttons in the gutter next to
    /// foldable code regions. Allows interactive folding control via clicking.
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .showFoldingControls(true)   // Show folding controls
    ///     .showFoldingControls(false)  // Hide folding controls
    /// ```
    public func showFoldingControls(_ show: Bool = true) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.display.showFoldingControls = show
        }
    }
    
    /// Sets the minimum number of lines required for a code region to be foldable.
    ///
    /// - Parameter lineCount: The minimum line count for foldable regions (default: 3)
    /// - Returns: A view with updated minimum foldable lines configuration
    ///
    /// Code sections with fewer lines than this threshold will not be considered
    /// foldable. This prevents folding of very small blocks that provide little benefit.
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .minimumFoldableLines(2)  // Allow folding of 2+ line blocks
    ///     .minimumFoldableLines(5)  // Only fold 5+ line blocks
    /// ```
    public func minimumFoldableLines(_ lineCount: Int) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.display.minimumFoldableLines = max(1, lineCount)
        }
    }
    
    /// Configures code folding animation behavior.
    ///
    /// - Parameter animate: Whether to animate code folding operations (default: true)
    /// - Returns: A view with updated folding animation configuration
    ///
    /// When enabled, folding and unfolding operations are animated for a smoother
    /// visual experience. Disable for better performance with very large files.
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .animateCodeFolding(true)   // Smooth folding animations
    ///     .animateCodeFolding(false)  // Instant folding (better performance)
    /// ```
    public func animateCodeFolding(_ animate: Bool = true) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.performance.animateCodeFolding = animate
        }
    }
}

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
