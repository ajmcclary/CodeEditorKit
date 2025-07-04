#if canImport(UIKit)
import UIKit
import CodeEditorPlugin
import SwiftUI

// MARK: - CodeEditorViewWrapper

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
