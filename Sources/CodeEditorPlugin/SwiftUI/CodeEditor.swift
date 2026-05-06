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
/// ## Setting Language and Theme
///
/// Use modifiers or factory methods to configure language and theme:
///
/// ```swift
/// // Using modifiers (recommended)
/// CodeEditor(text: $code)
///     .codeLanguage(.swift)
///     .codeTheme(.dark)
///
/// // Using factory method
/// CodeEditor.withLanguage($code, language: .swift, theme: .dark)
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

    // Environment - Using consolidated environment
    @Environment(\.codeEditorEnvironment) private var environment

    // Default memory monitor created on MainActor
    @State private var defaultMemoryMonitor = MemoryMonitor()

    // Initial values from convenience initializers
    private var initialLanguage: Language?
    private var initialTheme: Theme?

    // Callbacks
    internal var onTextChange: (@Sendable (String) -> Void)?
    internal var onSelectionChange: (@Sendable (Range<String.Index>?) -> Void)?
    internal var completionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?

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
        self.initialLanguage = nil
        self.initialTheme = nil
    }

    /// Creates a new code editor with text binding, language, and theme.
    ///
    /// This convenience initializer allows you to specify the language and theme
    /// directly without using environment modifiers or factory methods.
    ///
    /// - Parameters:
    ///   - text: A binding to the text content of the editor
    ///   - language: The programming language for syntax highlighting
    ///   - theme: The color theme to apply
    ///   - debounceInterval: Time interval to debounce text change events (default: 100ms)
    ///
    /// ## Example
    ///
    /// ```swift
    /// @State private var code = "// Hello, World!"
    /// 
    /// var body: some View {
    ///     CodeEditor(
    ///         text: $code,
    ///         language: .swift,
    ///         theme: .dark
    ///     )
    /// }
    /// ```
    public init(
        text: Binding<String>,
        language: Language,
        theme: Theme = .default,
        debounceInterval: Duration = .milliseconds(100)
    ) {
        self._text = text
        self.textDebounceInterval = debounceInterval
        self.initialLanguage = language
        self.initialTheme = theme
    }

    // MARK: - Body

    public var body: some View {
        let effectiveLanguage = initialLanguage ?? environment.language
        let effectiveTheme = initialTheme ?? environment.theme
        let effectiveMemoryMonitor = environment.memoryMonitor ?? defaultMemoryMonitor

        // Update configuration with event system if provided
        var effectiveConfiguration = environment.configuration
        if let eventSystem = environment.eventSystem {
            effectiveConfiguration.eventSystem = eventSystem
        }

        // Use configuration's debounce interval if not overridden
        let effectiveDebounceInterval = textDebounceInterval == .milliseconds(100)
            ? effectiveConfiguration.performance.textChangeDebounceInterval
            : textDebounceInterval

        return CodeEditorRepresentable(
            text: $text,  // Pass the binding directly
            language: effectiveLanguage,
            theme: effectiveTheme,
            configuration: effectiveConfiguration,
            memoryMonitor: effectiveMemoryMonitor,
            isFocused: Binding(
                get: { isFocused },
                set: { isFocused = $0 }
            ),
            textDebounceInterval: effectiveDebounceInterval,
            onTextChange: handleTextChange,
            onSelectionChange: handleSelectionChange
        )
        .searchable(text: $searchText)
        .codeEditorFocusable()
        .focused($isFocused)
        .environment(\.codeEditorLanguage, effectiveLanguage)
        .environment(\.codeEditorTheme, effectiveTheme)
        .environment(\.codeEditorConfiguration, environment.configuration)
        .onAppear {
            // Start monitoring if using default memory monitor
            if environment.memoryMonitor == nil {
                defaultMemoryMonitor.startMonitoring()
            }
        }
        .onDisappear {
            // Stop monitoring if using default memory monitor
            if environment.memoryMonitor == nil {
                defaultMemoryMonitor.stopMonitoring()
            }
        }
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

    // View modifiers have been moved to CodeEditor+Modifiers.swift
}

// Factory methods have been moved to CodeEditor+Factory.swift

// Completion types have been moved to CodeEditor+Completion.swift

#endif
