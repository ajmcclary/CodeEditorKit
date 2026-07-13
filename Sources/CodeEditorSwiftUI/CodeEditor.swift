import CodeEditorCommon
import CodeEditorCompletion
import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorLanguages
import CodeEditorLayout
import DesignKitThemes
#if canImport(SwiftUI)
import CodeEditorView
import SwiftUI

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
///             print("Hello, \\(name)!")
///         }
///         """
///     
///     var body: some View {
///         CodeEditor(text: $code)
///             .codeLanguage(.swift)
///             .lineNumbers(true)
///             .isSelectedLineHighlighted(true)
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
///     .designTheme(.lcarsDark)
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
///         .designTheme(.default)
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
///     .isSelectedLineHighlighted(true)
///     .editable(true)
///     .codeFontSize(16)
///     .tabWidth(4)
///     .areInvisibleCharactersVisible(false)
///     .onTextChange { newText in
///         print("Text changed: \\(newText.count) characters")
///     }
///     .onSelectionChange { range in
///         print("Selection changed: \\(range?.description ?? "nil")")
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
/// - **macOS**: native NSTextView-based implementation
/// - **iOS / iPadOS**: native UITextView-based implementation
@available(macOS 13.0, iOS 16.0, *)
public struct CodeEditor: View {
    // MARK: - Properties

    @Binding private var text: String

    // Environment - Using consolidated environment
    @Environment(\.codeEditorEnvironment) private var environment

    // Host-provided theme (DesignKit environment key).
    @Environment(\.designTheme) private var designTheme

    // Shared editor state surfaced by chrome (status bar, breadcrumb, title).
    // Defaults to the process-wide sentinel `EditorStateEnvironmentKey.defaultValue`
    // when the host does not inject one — writes against the sentinel are
    // inert (no chrome view reads it) and the coordinator holds it weakly.
    @Environment(\.editorState) private var hostEditorState

    // EditorDocuments manager wired by `.activeDocument(in:)`. When set,
    // body uses the manager's text and interaction-state bindings instead
    // of the receiver's stored ones.
    @Environment(\.activeDocumentManager) private var activeDocumentManager

    // Default memory monitor created on MainActor
    @State private var defaultMemoryMonitor = MemoryMonitor()

    // Fallback runtime dependencies used when the host hasn't injected one
    // via `\.codeEditorEnvironment.runtimeDependencies`. Cached in `@State`
    // so heavy components inside `EditorRuntimeDependencies.live()`
    // (MemoryMonitor, ActorCoordinator, UnifiedPerformanceSystem, etc.)
    // are constructed once per editor lifetime rather than once per body
    // call. Per-render env overrides (workspaceRoot, eventSystem,
    // memoryMonitor) are applied on a local copy so the cached struct
    // isn't mutated and stays stable across calls.
    @State private var fallbackRuntimeDependencies: EditorRuntimeDependencies = .live()

    // Initial values from convenience initializers
    private var initialLanguage: Language?
    private var initialTheme: Theme?

    // Intent populated by the modifier chain (.onTextChange,
    // .editorController, …). Read by body to wire callbacks and
    // references into the representable. Replaces the five stored
    // properties (onTextChange, onSelectionChange, completionProvider,
    // editorController, interactionState) that previously lived on
    // this struct. See docs/superpowers/specs/2026-05-14-swiftui-modifier-return-types-design.md.
    @Environment(\.codeEditorIntent) private var codeEditorIntent

    // Debouncing
    private let textDebounceInterval: Duration?

    // MARK: - Initialization

    /// Creates a new code editor with no explicit text binding.
    ///
    /// Use with `.activeDocument(in:)` to drive the text and interaction
    /// state from an `EditorDocuments` collection; the modifier supplies
    /// the bindings through the environment, and `body` reads them
    /// instead of this receiver's placeholder bindings.
    ///
    /// Standalone usage (without `.activeDocument(in:)`) renders an
    /// empty, read-only editor — useful only as a placeholder.
    public init() {
        self._text = .constant("")
        self.textDebounceInterval = nil
        self.initialLanguage = nil
        self.initialTheme = nil
    }

    /// Creates a new code editor with text binding and optional debouncing.
    ///
    /// - Parameters:
    ///   - text: A binding to the text content of the editor
    ///   - debounceInterval: Time interval to debounce text change events.
    ///     Pass `nil` (the default) to use the value from `EditorConfiguration.performance.textChangeDebounceInterval`.
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
        debounceInterval: Duration? = nil
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
    ///   - debounceInterval: Time interval to debounce text change events.
    ///     Pass `nil` (the default) to use the value from `EditorConfiguration.performance.textChangeDebounceInterval`.
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
        debounceInterval: Duration? = nil
    ) {
        self._text = text
        self.textDebounceInterval = debounceInterval
        self.initialLanguage = language
        self.initialTheme = theme
    }

    // MARK: - Configuration overlay

    /// Produces the configuration value `body` actually passes downstream,
    /// after overlaying environment-driven knobs that are wired through
    /// SwiftUI modifiers rather than the configuration struct directly.
    ///
    /// Currently overlays:
    /// - `performanceObservation.system` →
    ///   `performance.unifiedPerformanceSystem` (so framework producers
    ///   like `AsyncSyntaxHighlighter` record into the same system the
    ///   host observes via `.performanceObserver(_:)`).
    ///
    /// Extracted as a `static` helper so it's unit-testable without
    /// rendering the view.
    static func makeEffectiveConfiguration(
        from environment: CodeEditorEnvironment
    ) -> EditorConfiguration {
        var configuration = environment.configuration
        if let observation = environment.performanceObservation {
            configuration.performance.unifiedPerformanceSystem = observation.system
        }
        return configuration
    }

    // MARK: - Active-document binding resolution

    /// Returns the text `Binding` `body` should pass downstream.
    ///
    /// When `manager` is non-nil and has an `activeID`, returns
    /// `manager.textBinding(for: activeID)`. Otherwise returns `stored`.
    /// Extracted as a `static` helper so it's unit-testable without
    /// rendering the view.
    static func resolveTextBinding(
        stored: Binding<String>,
        manager: EditorDocuments?
    ) -> Binding<String> {
        if let manager, let activeID = manager.activeID {
            return manager.textBinding(for: activeID)
        }
        return stored
    }

    /// Returns the interaction-state `Binding` `body` should pass
    /// downstream. Same resolution rules as `resolveTextBinding`.
    static func resolveInteractionBinding(
        stored: Binding<EditorInteractionState>,
        manager: EditorDocuments?
    ) -> Binding<EditorInteractionState> {
        if let manager, let activeID = manager.activeID {
            return manager.interactionBinding(for: activeID)
        }
        return stored
    }

    // MARK: - Intent-driven callback wrapping

    /// Builds the `onTextChange` / `onSelectionChange` closures that
    /// `body` passes to the representable, given the env-supplied
    /// intent and the effective text binding.
    ///
    /// `selectionCallback` converts `NSRange` → `Range<String.Index>?`
    /// against the binding's current value; ranges that fail to map
    /// (e.g., past-end selections) silently drop. This matches the
    /// pre-migration behavior of `handleSelectionChange`.
    ///
    /// Extracted as a `static` helper so it's unit-testable without
    /// rendering the view.
    static func makeRepresentableCallbacks(
        from intent: CodeEditorIntent,
        textBinding: Binding<String>
    ) -> (
        textCallback: ((String) -> Void)?,
        selectionCallback: ((NSRange) -> Void)?
    ) {
        let textCallback: ((String) -> Void)? = intent.onTextChange.map { handler in
            { newText in handler(newText) }
        }
        let selectionCallback: ((NSRange) -> Void)? = intent.onSelectionChange.map { handler in
            { nsRange in
                guard let range = Range(nsRange, in: textBinding.wrappedValue) else { return }
                handler(range)
            }
        }
        return (textCallback, selectionCallback)
    }

    // MARK: - Body

    public var body: some View {
        let effectiveLanguage = initialLanguage ?? environment.language
        let effectiveTheme = initialTheme ?? designTheme

        var effectiveRuntimeDependencies: EditorRuntimeDependencies
        if let provided = environment.runtimeDependencies {
            effectiveRuntimeDependencies = provided
            if let memoryMonitor = environment.memoryMonitor {
                effectiveRuntimeDependencies.memoryMonitor = memoryMonitor
            }
        } else {
            // Reuse cached components (MemoryMonitor, ActorCoordinator, etc.)
            // and overlay the per-render env knobs onto a local copy.
            effectiveRuntimeDependencies = fallbackRuntimeDependencies
            effectiveRuntimeDependencies.workspaceRoot = environment.workspaceRoot
            effectiveRuntimeDependencies.eventSystem = environment.eventSystem
            if let memoryMonitor = environment.memoryMonitor {
                effectiveRuntimeDependencies.memoryMonitor = memoryMonitor
            } else {
                effectiveRuntimeDependencies.memoryMonitor = defaultMemoryMonitor
            }
        }

        // Overlay env-driven knobs onto a local copy of configuration.
        // Currently: performanceObservation → performance.unifiedPerformanceSystem.
        let effectiveConfiguration = Self.makeEffectiveConfiguration(from: environment)

        // Use configuration's debounce interval when no explicit override was passed.
        let effectiveDebounceInterval = textDebounceInterval
            ?? effectiveConfiguration.performance.textChangeDebounceInterval

        let effectiveTextBinding = Self.resolveTextBinding(
            stored: $text,
            manager: activeDocumentManager
        )
        CodeEditorRenderingDiagnostics.logBodyResolution(
            "body.resolveTextBinding",
            manager: activeDocumentManager,
            storedTextLength: text.count,
            effectiveTextLength: effectiveTextBinding.wrappedValue.count,
            language: effectiveLanguage,
            configuration: effectiveConfiguration
        )
        let storedInteraction = codeEditorIntent.interactionState
            ?? .constant(EditorInteractionState())
        let effectiveInteractionBinding = Self.resolveInteractionBinding(
            stored: storedInteraction,
            manager: activeDocumentManager
        )

        let (textCallback, selectionCallback) = Self.makeRepresentableCallbacks(
            from: codeEditorIntent,
            textBinding: effectiveTextBinding
        )

        return CodeEditorRepresentable(
            text: effectiveTextBinding,
            language: effectiveLanguage,
            theme: effectiveTheme,
            configuration: effectiveConfiguration,
            runtimeDependencies: effectiveRuntimeDependencies,
            textDebounceInterval: effectiveDebounceInterval,
            interactionState: effectiveInteractionBinding,
            editorController: codeEditorIntent.editorController,
            hostEditorState: hostEditorState,
            onTextChange: textCallback,
            onSelectionChange: selectionCallback,
            swiftUICompletionProvider: codeEditorIntent.completionProvider
        )
        // No `.searchable(...)` here on purpose. The old wrapper added a
        // toolbar search field that competes for first responder on macOS,
        // which made the editor appear read-only at launch even with a
        // valid `becomeFirstResponder: .yes` request. Hosts that want
        // searchable chrome can layer it outside the editor.
        .environment(\.codeEditorLanguage, effectiveLanguage)
        .transformEnvironment(\.codeEditorEnvironment) { $0 = $0.with(theme: effectiveTheme) }
        .environment(\.designTheme, effectiveTheme)
        .environment(\.codeEditorConfiguration, effectiveConfiguration)
        #if canImport(AppKit)
        .environment(\.editorEventBus, codeEditorIntent.editorController?.editorEventBus)
        #endif
        .onAppear {
            // Start monitoring if using default memory monitor
            if environment.memoryMonitor == nil && environment.runtimeDependencies == nil {
                defaultMemoryMonitor.startMonitoring()
            }
        }
        .onDisappear {
            // Stop monitoring if using default memory monitor
            if environment.memoryMonitor == nil && environment.runtimeDependencies == nil {
                defaultMemoryMonitor.stopMonitoring()
            }
        }
    }

    // View modifiers have been moved to CodeEditor+ModifiersExtensions.swift.
    // Callback wrapping for the representable lives in
    // `makeRepresentableCallbacks(from:textBinding:)` above.
}

// Factory methods have been moved to CodeEditor+Factory.swift

// Completion types have been moved to CodeEditor+Completion.swift

// MARK: - ActiveDocument environment key

@available(macOS 13.0, iOS 16.0, *)
private struct ActiveDocumentManagerEnvironmentKey: EnvironmentKey {
    static let defaultValue: EditorDocuments? = nil
}

@available(macOS 13.0, iOS 16.0, *)
extension EnvironmentValues {
    /// Active `EditorDocuments` manager installed by `.activeDocument(in:)`.
    /// `CodeEditor.body` reads this to override the receiver's stored text
    /// and interaction bindings with the manager's per-active-id bindings.
    var activeDocumentManager: EditorDocuments? {
        get { self[ActiveDocumentManagerEnvironmentKey.self] }
        set { self[ActiveDocumentManagerEnvironmentKey.self] = newValue }
    }
}

#endif
