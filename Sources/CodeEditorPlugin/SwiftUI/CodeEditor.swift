#if canImport(SwiftUI)
import SwiftUI

/// Modern, idiomatic SwiftUI code editor view
@available(macOS 13.0, iOS 16.0, *)
public struct CodeEditor: View {
    // MARK: - Properties
    
    @Binding private var text: String
    @State private var internalText: String = ""
    @State private var isUpdatingText = false
    
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
            text: $internalText,
            language: language,
            theme: theme,
            configuration: configuration,
            isFocused: Binding(
                get: { isFocused },
                set: { isFocused = $0 }
            ),
            onTextChange: handleTextChange,
            onSelectionChange: handleSelectionChange
        )
        .searchable(text: $searchText)
        .focusable()
        .focused($isFocused)
        .onAppear {
            if !isUpdatingText {
                internalText = text
            }
        }
        .task(id: text) {
            // Handle external text changes with debouncing
            if text != internalText && !isUpdatingText {
                try? await Task.sleep(for: textDebounceInterval)
                if !Task.isCancelled && !isUpdatingText {
                    await MainActor.run {
                        internalText = text
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleTextChange(_ newText: String) {
        Task { @MainActor in
            isUpdatingText = true
            defer { isUpdatingText = false }
            
            // Update binding with debouncing
            if newText != text {
                text = newText
                onTextChange?(newText)
            }
        }
    }
    
    private func handleSelectionChange(_ selection: NSRange) {
        // Convert NSRange to Range<String.Index>
        guard let range = Range(selection, in: internalText) else { return }
        onSelectionChange?(range)
    }
}

// MARK: - View Modifiers

@available(macOS 13.0, iOS 16.0, *)
public extension CodeEditor {
    /// Set the programming language for syntax highlighting
    func codeLanguage(_ language: Language) -> some View {
        environment(\.codeEditorLanguage, language)
    }
    
    /// Configure line numbers visibility
    func lineNumbers(_ visible: Bool = true) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.display.showLineNumbers = visible
        }
    }
    
    /// Configure line highlighting
    func highlightSelectedLine(_ highlight: Bool = true) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.display.highlightSelectedLine = highlight
        }
    }
    
    /// Set the editor theme
    func codeTheme(_ theme: CodeEditorSwiftUITheme) -> some View {
        environment(\.codeEditorTheme, theme)
    }
    
    /// Configure editor editability
    func editable(_ isEditable: Bool = true) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.behavior.isEditable = isEditable
        }
    }
    
    /// Add text change handler with optional debouncing
    func onTextChange(
        debounce: Duration? = nil,
        perform action: @escaping (String) -> Void
    ) -> CodeEditor {
        var copy = self
        copy.onTextChange = action
        if let debounce {
            copy = CodeEditor(text: _text, debounceInterval: debounce)
            copy.onTextChange = action
        }
        return copy
    }
    
    /// Add selection change handler
    func onSelectionChange(
        perform action: @escaping (Range<String.Index>?) -> Void
    ) -> CodeEditor {
        var copy = self
        copy.onSelectionChange = action
        return copy
    }
    
    /// Configure code completion
    func codeCompletion(
        provider: @escaping (CompletionContext) async -> [SwiftUICompletionItem]
    ) -> CodeEditor {
        var copy = self
        copy.completionProvider = provider
        return copy
    }
    
    /// Configure font size
    func codeFontSize(_ size: CGFloat) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.display.fontSize = size
        }
    }
    
    /// Configure tab width
    func tabWidth(_ width: Int) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.layout.tabWidth = width
        }
    }
    
    /// Show invisible characters
    func showInvisibleCharacters(_ show: Bool = true) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.display.showInvisibleCharacters = show
        }
    }
}

// MARK: - Platform-Specific Representable

@available(macOS 13.0, iOS 16.0, *)
struct CodeEditorRepresentable {
    @Binding var text: String
    let language: Language
    let theme: CodeEditorSwiftUITheme
    let configuration: EditorConfiguration
    @Binding var isFocused: Bool
    let onTextChange: ((String) -> Void)?
    let onSelectionChange: ((NSRange) -> Void)?
}

#if os(macOS)
@available(macOS 13.0, *)
extension CodeEditorRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> CodeEditorView {
        let view = CodeEditorView()
        context.coordinator.setup(view: view)
        return view
    }
    
    func updateNSView(_ nsView: CodeEditorView, context: Context) {
        context.coordinator.update(view: nsView, text: text, language: language, theme: theme, configuration: configuration)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject {
        let parent: CodeEditorRepresentable
        
        init(parent: CodeEditorRepresentable) {
            self.parent = parent
        }
        
        func setup(view _: CodeEditorView) {
            // Initial setup
        }
        
        @MainActor func update(view: CodeEditorView, text: String, language: Language, theme _: CodeEditorSwiftUITheme, configuration: EditorConfiguration) {
            if view.string != text {
                view.string = text
            }
            view.language = language
            // Apply theme
            view.showsLineNumbers = configuration.display.showLineNumbers
            view.highlightSelectedLine = configuration.display.highlightSelectedLine
            view.isEditable = configuration.behavior.isEditable
            view.font = NSFont.monospacedSystemFont(ofSize: configuration.display.fontSize, weight: .regular)
        }
    }
}
#else
@available(iOS 16.0, *)
extension CodeEditorRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> CodeEditorContainerView {
        let container = CodeEditorContainerView()
        context.coordinator.setup(container: container)
        return container
    }
    
    func updateUIView(_ uiView: CodeEditorContainerView, context: Context) {
        context.coordinator.update(container: uiView, text: text, language: language, theme: theme, configuration: configuration)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject {
        let parent: CodeEditorRepresentable
        
        init(parent: CodeEditorRepresentable) {
            self.parent = parent
        }
        
        func setup(container _: CodeEditorContainerView) {
            // Initial setup
        }
        
        @MainActor func update(container: CodeEditorContainerView, text: String, language: Language, theme _: CodeEditorSwiftUITheme, configuration: EditorConfiguration) {
            let view = container.textView
            if view.text != text {
                view.text = text
            }
            view.language = language
            container.showsLineNumbers = configuration.display.showLineNumbers
            view.highlightSelectedLine = configuration.display.highlightSelectedLine
            view.isEditable = configuration.behavior.isEditable
            view.font = UIFont.monospacedSystemFont(ofSize: configuration.display.fontSize, weight: .regular)
        }
    }
}
#endif

// MARK: - Environment Keys

@available(macOS 13.0, iOS 16.0, *)
struct CodeEditorLanguageKey: EnvironmentKey {
    static let defaultValue: Language = .plainText
}

// Note: CodeEditorThemeKey and codeEditorTheme environment value are defined in CodeEditorSwiftUIView.swift

@available(macOS 13.0, iOS 16.0, *)
struct CodeEditorConfigurationKey: EnvironmentKey {
    static let defaultValue = EditorConfiguration()
}

@available(macOS 13.0, iOS 16.0, *)
extension EnvironmentValues {
    public var codeEditorLanguage: Language {
        get { self[CodeEditorLanguageKey.self] }
        set { self[CodeEditorLanguageKey.self] = newValue }
    }
    
    public var codeEditorConfiguration: EditorConfiguration {
        get { self[CodeEditorConfigurationKey.self] }
        set { self[CodeEditorConfigurationKey.self] = newValue }
    }
}

// MARK: - Supporting Types

// Note: Theme functionality is provided by CodeEditorSwiftUITheme in CodeEditorSwiftUIView.swift

// MARK: - Completion Types

public struct CompletionContext: Sendable {
    public let text: String
    public let cursorPosition: Int
    public let language: Language
    
    public init(text: String, cursorPosition: Int, language: Language) {
        self.text = text
        self.cursorPosition = cursorPosition
        self.language = language
    }
}

public struct SwiftUICompletionItem {
    public let label: String
    public let kind: CompletionKind
    public let detail: String?
    public let insertText: String
    public let documentation: String?
    
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

public enum CompletionKind {
    case keyword
    case function
    case method
    case variable
    case constant
    case `class`
    case `struct`
    case `enum`
    case interface
    case module
    case property
    case value
    case reference
    case snippet
    case text
}

#endif
