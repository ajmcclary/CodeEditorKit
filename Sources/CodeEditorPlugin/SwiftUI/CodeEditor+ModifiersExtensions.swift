#if canImport(SwiftUI)
@preconcurrency import SwiftUI

// MARK: - View Modifiers

@available(macOS 13.0, iOS 16.0, *)
extension View {
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

    /// Sets the workspace root URL for LSP and file operations.
    ///
    /// - Parameter url: The workspace root URL
    /// - Returns: A view with the workspace root set in the configuration
    ///
    /// Setting a workspace root enables Language Server Protocol (LSP) features
    /// like code completion, hover information, and diagnostics.
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .codeWorkspaceRoot(projectURL)
    /// ```
    public func codeWorkspaceRoot(_ url: URL?) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            config.workspaceRoot = url
        }
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
            config.display.isLineNumbersEnabled = visible
        }
    }

    /// Requests that the code editor become the first responder (keyboard focus).
    ///
    /// This is a more intuitive API than using the environment key directly.
    /// When called, the editor will attempt to become the first responder on the
    /// next view update cycle.
    ///
    /// - Returns: A view that will request focus when displayed
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .becomeFirstResponder()
    ///     .onAppear {
    ///         // Editor will automatically gain focus when view appears
    ///     }
    /// ```
    ///
    /// - Note: On iOS, the keyboard will appear when the editor gains focus.
    ///         On macOS, the editor will receive keyboard input.
    public func becomeFirstResponder() -> some View {
        environment(\.codeEditorBecomeFirstResponder, true)
    }

    /// Requests the code editor to become (or resign) first responder with an explicit state.
    ///
    /// Use this modifier to programmatically control when the editor gains or loses focus
    /// based on the boolean parameter.
    ///
    /// - Parameter shouldBecomeFirstResponder: Whether the editor should become first responder
    /// - Returns: A view with the first responder state set
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct ContentView: View {
    ///     @State private var code = ""
    ///     @State private var isEditing = false
    ///     
    ///     var body: some View {
    ///         VStack {
    ///             Button("Toggle Focus") {
    ///                 isEditing.toggle()
    ///             }
    ///             
    ///             CodeEditor(text: $code)
    ///                 .becomeFirstResponder(isEditing)
    ///         }
    ///     }
    /// }
    /// ```
    public func becomeFirstResponder(_ shouldBecomeFirstResponder: Bool) -> some View {
        environment(\.codeEditorBecomeFirstResponder, shouldBecomeFirstResponder)
    }
}

@available(macOS 13.0, iOS 16.0, *)
extension CodeEditor {
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
    ///   - action: Closure called when text changes
    /// - Returns: A new view with the text change handler attached
    ///
    /// The handler is called whenever the text content changes. Use debouncing
    /// to reduce the frequency of calls for performance-sensitive operations.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Use default debouncing (100ms)
    /// CodeEditor(text: $code)
    ///     .onTextChange { newText in
    ///         logger.debug("Text changed: \(newText.count) characters")
    ///     }
    /// 
    /// // Or specify custom debouncing in initializer
    /// CodeEditor(text: $code, debounceInterval: .milliseconds(500))
    ///     .onTextChange { newText in
    ///         saveToDatabase(newText)
    ///     }
    /// ```
    public func onTextChange(
        perform action: @escaping @Sendable (String) -> Void
    ) -> CodeEditor {
        var copy = self
        copy.onTextChange = action
        // Note: If a custom debounce is needed, users should pass it to the initializer
        // This avoids recreating the view and losing other modifier state
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
        perform action: @escaping @Sendable (Range<String.Index>?) -> Void
    ) -> CodeEditor {
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
    /// a `SwiftUICompletionContext` with the current text, cursor position, and language.
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
        provider: @escaping @Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem]
    ) -> CodeEditor {
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

    /// Requests that the code editor become the first responder (keyboard focus).
    ///
    /// This is a more intuitive API than using the environment key directly.
    /// When called, the editor will attempt to become the first responder on the
    /// next view update cycle.
    ///
    /// - Returns: A view that will request focus when displayed
    ///
    /// ## Example
    ///
    /// ```swift
    /// CodeEditor(text: $code)
    ///     .becomeFirstResponder()
    ///     .onAppear {
    ///         // Editor will automatically gain focus when view appears
    ///     }
    /// ```
    ///
    /// - Note: On iOS, the keyboard will appear when the editor gains focus.
    ///         On macOS, the editor will receive keyboard input.

    /// Configures a custom memory monitor for the editor.
    ///
    /// - Parameter monitor: The memory monitor instance to use
    /// - Returns: A view with the custom memory monitor environment value
    ///
    /// Use this modifier to inject a custom memory monitor for testing or to share
    /// a single monitor instance across multiple editor instances.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let sharedMonitor = MemoryMonitor()
    /// 
    /// var body: some View {
    ///     VStack {
    ///         CodeEditor(text: $code1)
    ///             .memoryMonitor(sharedMonitor)
    ///         
    ///         CodeEditor(text: $code2)
    ///             .memoryMonitor(sharedMonitor)
    ///     }
    /// }
    /// ```
    ///
    /// ## Testing Example
    ///
    /// ```swift
    /// let testMonitor = MemoryMonitor()
    /// testMonitor.isUnderPressure = true  // Simulate memory pressure
    /// 
    /// CodeEditor(text: $code)
    ///     .memoryMonitor(testMonitor)
    /// ```
    public func memoryMonitor(_ monitor: MemoryMonitor) -> some View {
        environment(\.codeEditorMemoryMonitor, monitor)
    }

    /// Sets a custom event system for publishing and subscribing to editor events.
    ///
    /// By default, CodeEditor does not publish events unless an event system is provided.
    /// Use this modifier to inject a custom event system instance for better testability
    /// and isolation between multiple editors.
    ///
    /// - Parameter eventSystem: The event system to use for this editor
    /// - Returns: A new view with the event system set
    ///
    /// ## Example
    ///
    /// ```swift
    /// let customEventSystem = UnifiedEventSystem()
    /// 
    /// CodeEditor(text: $code)
    ///     .eventSystem(customEventSystem)
    ///     .onAppear {
    ///         // Subscribe to events from this specific editor
    ///         customEventSystem.subscribe(to: TextChangeEvent.self) { event in
    ///             // Handle text change: event.newText
    ///         }
    ///     }
    /// ```
    public func eventSystem(_ eventSystem: UnifiedEventSystem) -> some View {
        environment(\.codeEditorEventSystem, eventSystem)
            .transformEnvironment(\.codeEditorConfiguration) { config in
                config.eventSystem = eventSystem
            }
    }
}

#endif
