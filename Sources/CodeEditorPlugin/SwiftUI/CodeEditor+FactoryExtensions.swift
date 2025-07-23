#if canImport(SwiftUI)
@preconcurrency import SwiftUI

// MARK: - Convenience Factory Methods

@available(macOS 13.0, iOS 16.0, *)
extension CodeEditor {
    /// Creates a code editor with the specified language and theme.
    ///
    /// This factory method ensures the environment values are properly set for the
    /// provided language and theme parameters.
    ///
    /// - Parameters:
    ///   - text: A binding to the text content
    ///   - language: The programming language for syntax highlighting
    ///   - theme: The color theme to apply (default: .default)
    ///   - debounceInterval: Time interval to debounce text changes (default: 100ms)
    /// - Returns: A CodeEditor view with the specified environment values
    public static func withLanguage(
        _ text: Binding<String>,
        language: Language,
        theme: CodeEditorSwiftUITheme = .default,
        debounceInterval: Duration = .milliseconds(100)
    ) -> some View {
        CodeEditor(text: text, debounceInterval: debounceInterval)
            .environment(\.codeEditorLanguage, language)
            .environment(\.codeEditorTheme, theme)
    }

    /// Creates a code editor with the specified configuration.
    ///
    /// This factory method ensures the environment values are properly set for the
    /// provided configuration parameters.
    ///
    /// - Parameters:
    ///   - text: A binding to the text content
    ///   - configuration: The complete editor configuration
    ///   - language: The programming language (default: .plainText)
    ///   - theme: The color theme (default: .default)
    ///   - debounceInterval: Time interval to debounce text changes (default: 100ms)
    /// - Returns: A CodeEditor view with the specified environment values
    public static func withConfiguration(
        _ text: Binding<String>,
        configuration: EditorConfiguration,
        language: Language = .plainText,
        theme: CodeEditorSwiftUITheme = .default,
        debounceInterval: Duration = .milliseconds(100)
    ) -> some View {
        CodeEditor(text: text, debounceInterval: debounceInterval)
            .environment(\.codeEditorConfiguration, configuration)
            .environment(\.codeEditorLanguage, language)
            .environment(\.codeEditorTheme, theme)
    }
}

#endif
