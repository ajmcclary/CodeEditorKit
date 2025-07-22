import Foundation

/// Bridge implementation that connects the stable PluginAPI to the internal PluginContext
@available(macOS 13.0, iOS 16.0, *)
@MainActor
final class PluginAPIBridge: PluginAPI {
    private let context: PluginContext
    
    init(context: PluginContext) {
        self.context = context
        self.languages = LanguageAPIImpl(context: context)
        self.completion = CompletionAPIImpl(context: context)
        self.commands = CommandAPIImpl(context: context)
        self.themes = ThemeAPIImpl(context: context)
        self.editor = EditorAPIImpl(context: context)
        self.fileSystem = FileSystemAPIImpl(context: context)
        self.diagnostics = DiagnosticAPIImpl(context: context)
    }
    
    var apiVersion: String {
        "1.0.0"
    }
    
    let languages: LanguageAPI
    let completion: CompletionAPI
    let commands: CommandAPI
    let themes: ThemeAPI
    let editor: EditorAPI
    let fileSystem: FileSystemAPI
    let diagnostics: DiagnosticAPI
}

// MARK: - Language API Implementation

@available(macOS 13.0, iOS 16.0, *)
@MainActor
private final class LanguageAPIImpl: LanguageAPI {
    private let context: PluginContext
    
    init(context: PluginContext) {
        self.context = context
    }
    
    func registerHighlighter(_ highlighter: any SyntaxHighlighter, for language: Language) async throws {
        guard context.hasPermission(.languages) else {
            throw PluginError.securityViolation("Missing permission: languages")
        }
        
        // Create a language provider wrapper for the highlighter
        let provider = HighlighterLanguageProvider(language: language, highlighter: highlighter)
        context.languageRegistry.register(provider)
    }
    
    func unregisterHighlighter(for language: Language) async throws {
        guard context.hasPermission(.languages) else {
            throw PluginError.securityViolation("Missing permission: languages")
        }
        
        context.languageRegistry.unregister(identifier: language.rawValue)
    }
    
    func availableLanguages() async -> [Language] {
        // Return all known languages since registry doesn't have a method to list them
        return Language.allCases
    }
    
    func registerLanguageConfiguration(_: LanguageConfiguration, for language: Language) async throws {
        guard context.hasPermission(.languages) else {
            throw PluginError.securityViolation("Missing permission: languages")
        }
        
        // Store configuration for the language
        // This would be implemented with the language registry
        context.logger.info("Registered language configuration for \(language)")
    }
}

// MARK: - Completion API Implementation

@available(macOS 13.0, iOS 16.0, *)
@MainActor
private final class CompletionAPIImpl: CompletionAPI {
    private let context: PluginContext
    
    init(context: PluginContext) {
        self.context = context
    }
    
    func registerProvider(_ provider: any CompletionProvider, for language: Language) async {
        guard context.hasPermission(.completion) else {
            context.logger.warning("Missing permission: completion")
            return
        }
        
        context.completionRegistry.register(provider)
    }
    
    func unregisterProvider(for language: Language) async {
        guard context.hasPermission(.completion) else {
            return
        }
        
        // Unregister all providers for this language
        let providers = context.completionRegistry.providers(for: language)
        for provider in providers {
            context.completionRegistry.unregister(providerId: provider.id)
        }
    }
    
    func triggerCompletion() async {
        // Trigger completion at current cursor position
        // This would interact with the active editor
        context.logger.debug("Triggering completion")
    }
}

// MARK: - Command API Implementation

@available(macOS 13.0, iOS 16.0, *)
@MainActor
private final class CommandAPIImpl: CommandAPI {
    private let context: PluginContext
    private var registeredCommands: [String: PluginCommand] = [:]
    
    init(context: PluginContext) {
        self.context = context
    }
    
    func register(_ command: PluginCommand, handler: @escaping () async throws -> Void) async throws {
        guard context.hasPermission(.commands) else {
            throw PluginError.securityViolation("Missing permission: commands")
        }
        
        try await context.registerCommand(command, handler: handler)
        registeredCommands[command.identifier] = command
    }
    
    func unregister(commandId: String) async {
        registeredCommands.removeValue(forKey: commandId)
        // Unregister from plugin manager
    }
    
    func execute(commandId: String) async throws {
        guard registeredCommands[commandId] != nil else {
            throw PluginError.notFound(identifier: commandId)
        }
        
        // Execute through plugin manager
        context.logger.debug("Executing command: \(commandId)")
    }
    
    func availableCommands() async -> [PluginCommand] {
        Array(registeredCommands.values)
    }
}

// MARK: - Theme API Implementation

@available(macOS 13.0, iOS 16.0, *)
@MainActor
private final class ThemeAPIImpl: ThemeAPI {
    private let context: PluginContext
    private var registeredThemes: [String: EditorTheme] = [:]
    
    init(context: PluginContext) {
        self.context = context
    }
    
    func register(_ theme: EditorTheme) async throws {
        guard context.hasPermission(.themes) else {
            throw PluginError.securityViolation("Missing permission: themes")
        }
        
        registeredThemes[theme.identifier] = theme
        context.logger.info("Registered theme: \(theme.name)")
    }
    
    func unregister(themeId: String) async {
        registeredThemes.removeValue(forKey: themeId)
    }
    
    func availableThemes() async -> [EditorTheme] {
        // Return only registered themes as built-in themes aren't defined yet
        return Array(registeredThemes.values)
    }
    
    func currentTheme() async -> EditorTheme {
        // Create a default theme based on current configuration
        EditorTheme(
            identifier: "current",
            name: "Current Theme",
            isDark: false,
            colors: ThemeColors(
                background: "#FFFFFF",
                foreground: "#000000",
                keyword: "#0000FF",
                string: "#FF0000",
                comment: "#808080",
                type: "#800080",
                function: "#FFA500",
                variable: "#000000",
                number: "#4B0082",
                operator: "#000000",
                punctuation: "#000000",
                selection: "#B4D8FD",
                lineNumber: "#808080",
                currentLine: "#F0F0F0"
            )
        )
    }
    
    func setTheme(_ themeId: String) async throws {
        guard let theme = registeredThemes[themeId] else {
            throw PluginError.notFound(identifier: themeId)
        }
        
        // Store the theme for future reference
        // Note: The actual theme application would need to be handled by the editor view
        context.logger.info("Theme set to: \(theme.name)")
    }
}

// MARK: - Editor API Implementation

@available(macOS 13.0, iOS 16.0, *)
@MainActor
private final class EditorAPIImpl: EditorAPI {
    private let context: PluginContext
    
    init(context: PluginContext) {
        self.context = context
    }
    
    func getText() async -> String {
        // This would need to access the active editor instance
        // For now, return empty string
        ""
    }
    
    func setText(_: String) async throws {
        // Set text in active editor
        context.logger.debug("Setting text")
    }
    
    func getSelectedText() async -> String? {
        // Get selection from active editor
        nil
    }
    
    func getSelection() async -> NSRange {
        // Get selection range from active editor
        NSRange(location: 0, length: 0)
    }
    
    func setSelection(_ range: NSRange) async {
        // Set selection in active editor
        context.logger.debug("Setting selection: \(range)")
    }
    
    func insertText(_: String) async {
        // Insert text at current position
        context.logger.debug("Inserting text")
    }
    
    func replaceText(in range: NSRange, with _: String) async {
        // Replace text in range
        context.logger.debug("Replacing text in range: \(range)")
    }
    
    func getLanguage() async -> Language {
        // Get from active editor
        .plainText
    }
    
    func setLanguage(_ language: Language) async throws {
        // Set language in active editor
        context.logger.debug("Setting language: \(language)")
    }
    
    func getCursorPosition() async -> CursorPosition {
        // Get from active editor
        CursorPosition(line: 0, column: 0, offset: 0)
    }
    
    func setCursorPosition(_ position: CursorPosition) async {
        // Set in active editor
        context.logger.debug("Setting cursor position: line \(position.line), column \(position.column)")
    }
}

// MARK: - File System API Implementation

@available(macOS 13.0, iOS 16.0, *)
@MainActor
private final class FileSystemAPIImpl: FileSystemAPI {
    private let context: PluginContext
    
    init(context: PluginContext) {
        self.context = context
    }
    
    func readFile(_ path: String) async throws -> Data {
        guard context.hasPermission(.fileSystem) else {
            throw PluginError.securityViolation("Missing permission: fileSystem")
        }
        
        return try await context.workspace.readData(filename: path)
    }
    
    func writeFile(_ path: String, data: Data) async throws {
        guard context.hasPermission(.fileSystem) else {
            throw PluginError.securityViolation("Missing permission: fileSystem")
        }
        
        try await context.workspace.writeData(data, filename: path)
    }
    
    func deleteFile(_ path: String) async throws {
        guard context.hasPermission(.fileSystem) else {
            throw PluginError.securityViolation("Missing permission: fileSystem")
        }
        
        try await context.workspace.deleteFile(filename: path)
    }
    
    func listFiles(in _: String?) async throws -> [String] {
        guard context.hasPermission(.fileSystem) else {
            throw PluginError.securityViolation("Missing permission: fileSystem")
        }
        
        return try await context.workspace.listFiles()
    }
    
    func fileExists(_ path: String) async -> Bool {
        guard context.hasPermission(.fileSystem) else {
            return false
        }
        
        do {
            _ = try await readFile(path)
            return true
        } catch {
            return false
        }
    }
    
    var workspaceURL: URL {
        context.workspace.baseDirectory
    }
}

// MARK: - Diagnostic API Implementation

@available(macOS 13.0, iOS 16.0, *)
@MainActor
private final class DiagnosticAPIImpl: DiagnosticAPI {
    private let context: PluginContext
    private var currentDiagnostics: [PluginAPIDiagnostic] = []
    
    init(context: PluginContext) {
        self.context = context
    }
    
    func report(_ diagnostics: [PluginAPIDiagnostic]) async {
        guard context.hasPermission(.diagnostics) else {
            context.logger.warning("Missing permission: diagnostics")
            return
        }
        
        currentDiagnostics = diagnostics
        
        // Post diagnostic event
        let _ = PluginDiagnosticEvent(
            pluginId: context.pluginIdentifier,
            diagnostics: diagnostics.map { diagnostic in
                PluginDiagnostic(
                    range: diagnostic.range,
                    severity: PluginDiagnostic.Severity(rawValue: diagnostic.severity.rawValue) ?? .info,
                    message: diagnostic.message,
                    code: diagnostic.code,
                    source: diagnostic.source
                )
            }
        )
        // TODO: Publish diagnostic event when plugin event support is added to UnifiedEventSystem
        // For now, diagnostics are stored locally and can be queried via the current() method
    }
    
    func clear() async {
        currentDiagnostics.removeAll()
        
        let _ = PluginDiagnosticEvent(
            pluginId: context.pluginIdentifier,
            diagnostics: []
        )
        // TODO: Publish diagnostic event when plugin event support is added to UnifiedEventSystem
        // For now, diagnostics are stored locally and can be queried via the current() method
    }
    
    func current() async -> [PluginAPIDiagnostic] {
        currentDiagnostics
    }
}

// Plugin events are now defined in PluginEvents.swift

// MARK: - Helper Types

/// Wrapper to adapt a SyntaxHighlighter to a LanguageProvider
@available(macOS 13.0, iOS 16.0, *)
@MainActor
private final class HighlighterLanguageProvider: LanguageProvider {
    let identifier: String
    let displayName: String
    let fileExtensions: [String]
    private let highlighter: any SyntaxHighlighter
    
    init(language: Language, highlighter: any SyntaxHighlighter) {
        self.identifier = language.rawValue
        self.displayName = language.rawValue.capitalized
        self.fileExtensions = []  // Plugin highlighters don't provide extensions
        self.highlighter = highlighter
    }
    
    func createHighlighter() -> any SyntaxHighlighter {
        highlighter
    }
}
