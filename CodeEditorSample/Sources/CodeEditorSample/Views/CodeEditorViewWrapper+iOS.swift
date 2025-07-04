#if canImport(UIKit)
import CodeEditorPlugin
import SwiftUI
import UIKit

// MARK: - CodeEditorViewWrapper

/// Wrapper for CodeEditor on iOS/iPadOS/Mac Catalyst platforms.
///
/// This is a thin wrapper that forwards to the SwiftUI `CodeEditor` component.
/// It exists to provide API compatibility with the macOS version, which requires
/// a more complex NSViewRepresentable implementation.
///
/// - Note: On iOS/Catalyst, we don't have direct access to the underlying text view
///   through the SwiftUI component, so `onTextViewReady` callback is not supported.
///
/// ## Why Different from macOS?
///
/// The iOS/Catalyst version uses the SwiftUI CodeEditor component directly because:
/// 1. **Built-in Container Management**: iOS UITextView includes built-in scroll view
///    functionality, eliminating the need for manual scroll view setup.
/// 2. **SwiftUI Integration**: The CodeEditor SwiftUI component handles all the
///    UIViewRepresentable complexity internally, providing a cleaner API.
/// 3. **Platform Conventions**: iOS apps typically don't need the low-level text view
///    access that macOS apps require for advanced features.
/// 4. **Simplified Architecture**: Using the SwiftUI component reduces complexity and
///    maintenance burden while providing all necessary functionality for iOS.
/// 5. **Container View Separation**: On iOS, the CodeEditorContainerView handles
///    gutter management separately, while macOS integrates it into the scroll view.
struct CodeEditorViewWrapper: View {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    let onTextViewReady: ((CodeEditorView) -> Void)?

    init(
        configuration: EditorConfiguration,
        text: Binding<String>,
        language: String,
        onTextViewReady: ((CodeEditorView) -> Void)? = nil
    ) {
        self.configuration = configuration
        self._text = text
        self.language = language
        self.onTextViewReady = onTextViewReady
    }

    var body: some View {
        // On iOS/Catalyst, use the CodeEditor SwiftUI component directly
        CodeEditor(text: $text)
            .codeLanguage(detectLanguage(from: language))
            .environment(\.codeEditorConfiguration, configuration)
            .onAppear {
                // Note: On iOS, we don't have direct access to the underlying text view
                // through the SwiftUI component
            }
    }
    
    private func detectLanguage(from fileExtension: String) -> Language {
        let coordinator = SyntaxHighlightingCoordinator()
        return coordinator.detectLanguage(from: fileExtension)
    }
}

#endif
