#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import CodeEditorPlugin
import SwiftUI

struct SampleCodeEditorView: View {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String

    var body: some View {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            CodeEditor(text: $text)
                .codeLanguage(detectLanguage(from: language))
                .environment(\.codeEditorConfiguration, configuration)
        } else {
            // Fallback for older macOS versions
            CodeEditorViewWrapper(
                configuration: configuration,
                text: $text,
                language: language,
                onTextViewReady: nil
            )
        }
        #else
        // For iOS, continue using CodeEditorSwiftUIView for now
        CodeEditorSwiftUIView(
            text: $text,
            language: detectLanguage(from: language),
            showLineNumbers: configuration.display.showLineNumbers,
            highlightSelectedLine: configuration.display.highlightSelectedLine,
            isEditable: configuration.behavior.isEditable
        )
        #endif
    }
    
    private func detectLanguage(from fileExtension: String) -> Language {
        switch fileExtension.lowercased() {
        case "swift":
            return .swift
        case "py", "python":
            return .python
        case "js", "javascript":
            return .javascript
        case "json":
            return .json
        case "md", "markdown":
            // Use the coordinator to detect language for markdown files
            let coordinator = SyntaxHighlightingCoordinator()
            return coordinator.detectLanguage(from: fileExtension)
        default:
            return .plainText
        }
    }
}
