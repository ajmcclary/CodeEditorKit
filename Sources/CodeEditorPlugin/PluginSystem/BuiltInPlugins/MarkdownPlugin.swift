import Foundation

/// Built-in plugin providing enhanced Markdown support
@available(macOS 13.0, iOS 16.0, *)
public final class MarkdownPlugin: Plugin {
    public static let identifier = "com.codeeditorplugin.markdown"

    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "MarkdownPlugin")

    public var metadata: PluginMetadata {
        PluginMetadata(
            identifier: Self.identifier,
            name: "Enhanced Markdown Support",
            version: "1.0.0",
            author: "CodeEditorPlugin Team",
            description: "Provides enhanced Markdown editing with live preview and snippets",
            capabilities: [.syntaxHighlighting, .codeCompletion, .commands],
            minimumHostVersion: "1.0.0",
            dependencies: [],
            platforms: [.macOS, .iOS, .catalyst],
            enabledByDefault: true
        )
    }

    // Use a class to wrap mutable state to maintain Sendability
    private final class InternalState: @unchecked Sendable {
        private let lock = NSLock()
        private var _completionProvider: PluginMarkdownCompletionProvider?
        private var _savedSnippets: [String: String] = [:]

        var completionProvider: PluginMarkdownCompletionProvider? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _completionProvider
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _completionProvider = newValue
            }
        }

        var savedSnippets: [String: String] {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _savedSnippets
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _savedSnippets = newValue
            }
        }
    }

    private let state = InternalState()

    public init() {}

    @MainActor
    public func activate(context: PluginContext) async throws {
        logger.info("Activating Markdown plugin")

        // Register enhanced Markdown completion provider
        if context.hasPermission(.completion) {
            let provider = PluginMarkdownCompletionProvider()
            state.completionProvider = provider
            context.completionRegistry.register(provider)
        }

        // Register Markdown commands
        if context.hasPermission(.commands) {
            try await registerCommands(context: context)
        }

        // Subscribe to text changes for live preview
        // Note: This would need to be connected to actual text change events from the editor
    }

    @MainActor
    public func deactivate(context: PluginContext) async throws {
        logger.info("Deactivating Markdown plugin")

        // Unregister completion provider
        if state.completionProvider != nil {
            context.completionRegistry.unregister(providerId: "plugin-markdown")
            state.completionProvider = nil
        }

        // Note: Event system unsubscription would be handled if we were subscribed
    }

    public func saveState() async -> PluginState {
        PluginState(
            strings: state.savedSnippets,
            doubles: ["lastActivated": Date().timeIntervalSince1970]
        )
    }

    public func restoreState(_ state: PluginState) async {
        self.state.savedSnippets = state.strings
    }

    // MARK: - Private Methods

    private func registerCommands(context: PluginContext) async throws {
        // Bold command
        let boldCommand = PluginCommand(
            identifier: "markdown.bold",
            title: "Bold",
            keyboardShortcut: KeyboardShortcut(key: "b", modifiers: .command),
            category: "Markdown"
        )
        try await context.registerCommand(boldCommand) { [weak self] in
            await self?.insertBold()
        }

        // Italic command
        let italicCommand = PluginCommand(
            identifier: "markdown.italic",
            title: "Italic",
            keyboardShortcut: KeyboardShortcut(key: "i", modifiers: .command),
            category: "Markdown"
        )
        try await context.registerCommand(italicCommand) { [weak self] in
            await self?.insertItalic()
        }

        // Link command
        let linkCommand = PluginCommand(
            identifier: "markdown.link",
            title: "Insert Link",
            keyboardShortcut: KeyboardShortcut(key: "k", modifiers: .command),
            category: "Markdown"
        )
        try await context.registerCommand(linkCommand) { [weak self] in
            await self?.insertLink()
        }

        // Code block command
        let codeBlockCommand = PluginCommand(
            identifier: "markdown.codeblock",
            title: "Insert Code Block",
            keyboardShortcut: KeyboardShortcut(key: "c", modifiers: [.command, .shift]),
            category: "Markdown"
        )
        try await context.registerCommand(codeBlockCommand) { [weak self] in
            await self?.insertCodeBlock()
        }
    }

    private func handleTextChange(_ affectedRange: NSRange, replacementText _: String, context _: PluginContext) async {
        // This could trigger live preview updates
        logger.debug("Text changed in range: \(affectedRange)")
    }

    // MARK: - Command Implementations

    @MainActor
    private func insertBold() async {
        // Would interact with the text view to insert **bold** markers
        logger.debug("Inserting bold markers")
    }

    @MainActor
    private func insertItalic() async {
        // Would interact with the text view to insert *italic* markers
        logger.debug("Inserting italic markers")
    }

    @MainActor
    private func insertLink() async {
        // Would show a dialog and insert [text](url)
        logger.debug("Inserting link")
    }

    @MainActor
    private func insertCodeBlock() async {
        // Would insert ```language\n\n```
        logger.debug("Inserting code block")
    }
}

// MARK: - Markdown Completion Provider

@available(macOS 13.0, iOS 16.0, *)
private final class PluginMarkdownCompletionProvider: BaseCompletionProvider {
    init() {
        super.init(
            id: "plugin-markdown",
            supportedLanguages: [.markdown],
            triggerCharacters: ["#", "-", "1", "`", "["],
            supportsSnippets: true
        )
    }

    override func analyzeContext(_ context: CompletionContextModel) -> ContextAnalysisResult {
        let beforeCursor = String(context.text.prefix(context.cursorPosition))
        let lines = beforeCursor.components(separatedBy: .newlines)
        let currentLine = lines.last ?? ""
        let prefix = currentLine.trimmingCharacters(in: .whitespaces)

        // Determine the context type based on the prefix
        if prefix.hasPrefix("#") {
            return ContextAnalysisResult(type: .keyword, filter: prefix)
        } else if prefix.hasPrefix("```") {
            return ContextAnalysisResult(type: .general, filter: prefix) // Snippets are handled in general context
        } else if prefix.isEmpty {
            return ContextAnalysisResult(type: .general, filter: "")
        } else {
            return ContextAnalysisResult(type: .general, filter: prefix)
        }
    }

    override var keywords: [String] {
        ["#", "##", "###", "####", "#####", "######"]
    }

    override var snippets: [SnippetTemplate] {
        [
            SnippetTemplate(
                label: "# Header 1",
                insertText: "# $0",
                description: "First level header"
            ),
            SnippetTemplate(
                label: "## Header 2",
                insertText: "## $0",
                description: "Second level header"
            ),
            SnippetTemplate(
                label: "### Header 3",
                insertText: "### $0",
                description: "Third level header"
            ),
            SnippetTemplate(
                label: "- List item",
                insertText: "- $0",
                description: "Unordered list item"
            ),
            SnippetTemplate(
                label: "1. Numbered item",
                insertText: "1. $0",
                description: "Ordered list item"
            ),
            SnippetTemplate(
                label: "- [ ] Task",
                insertText: "- [ ] $0",
                description: "Task list item"
            ),
            SnippetTemplate(
                label: "```swift",
                insertText: "```swift\n$0\n```",
                description: "Swift code block"
            ),
            SnippetTemplate(
                label: "```python",
                insertText: "```python\n$0\n```",
                description: "Python code block"
            ),
            SnippetTemplate(
                label: "```javascript",
                insertText: "```javascript\n$0\n```",
                description: "JavaScript code block"
            )
        ]
    }
}

// Plugin event types are now defined in PluginEvents.swift
