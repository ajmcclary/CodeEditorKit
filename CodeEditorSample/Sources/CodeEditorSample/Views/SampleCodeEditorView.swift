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
    @State private var editorView: CodeEditorView?
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            // Temporarily bypass CodeEditor due to concurrency issues with accessibility
            CodeEditorViewWrapper(
                configuration: configuration,
                text: $text,
                language: language
            ) { textView in
                editorView = textView
            }
            .onChange(of: configuration) { newConfig in
                // Reapply configuration when it changes
                if let editor = editorView {
                    newConfig.apply(to: editor)
                }
            }
            #else
            // For iOS, use CodeEditorViewWrapper with configuration
            CodeEditorViewWrapper(
                configuration: configuration,
                text: $text,
                language: language
            ) { textView in
                editorView = textView
            }
            .onChange(of: configuration) { newConfig in
                // Reapply configuration when it changes
                if let editor = editorView {
                    newConfig.apply(to: editor)
                }
            }
            #endif
            
            // Visual indicators overlay
            VStack {
                HStack {
                    Spacer()
                    if configuration.display.showMinimap {
                        MinimapIndicator()
                    }
                }
                Spacer()
                HStack {
                    if configuration.display.enableAnnotations {
                        AnnotationIndicator()
                    }
                    Spacer()
                }
            }
            .padding()
        }
    }
    
    private func detectLanguage(from fileExtension: String) -> Language {
        let coordinator = SyntaxHighlightingCoordinator()
        return coordinator.detectLanguage(from: fileExtension)
    }
}

// MARK: - Visual Indicators

struct MinimapIndicator: View {
    var body: some View {
        Text("Minimap Active")
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(4)
    }
}

struct AnnotationIndicator: View {
    var body: some View {
        Text("Annotations Active")
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(4)
    }
}
