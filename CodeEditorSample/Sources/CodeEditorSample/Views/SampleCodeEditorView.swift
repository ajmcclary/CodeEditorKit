#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import CodeEditorPlugin
import SwiftUI

class SampleCodeEditorCoordinator {
    var editorView: CodeEditorView?
}

struct SampleCodeEditorView: View {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    private let coordinator = SampleCodeEditorCoordinator()
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
                coordinator.editorView = textView
            }
            .onChangeCompat(of: configuration) { newConfig in
                // Reapply configuration when it changes
                if let editor = coordinator.editorView {
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
                coordinator.editorView = textView
            }
            .onChangeCompat(of: configuration) { newConfig in
                // Reapply configuration when it changes
                if let editor = coordinator.editorView {
                    newConfig.apply(to: editor)
                }
            }
            #endif
            
            // Visual indicators overlay - only show on macOS, not on iOS or Mac Catalyst
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
            #endif
        }
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
