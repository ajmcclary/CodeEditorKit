#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import CodeEditorPlugin
import SwiftUI

/// Coordinator for managing the editor view lifecycle and configuration updates.
///
/// This coordinator maintains a reference to the underlying ``CodeEditorView``
/// instance to enable configuration updates and maintain editor state across
/// SwiftUI view updates.
///
/// ## Purpose
///
/// - Maintains reference to the native editor view
/// - Enables dynamic configuration updates
/// - Provides a bridge between SwiftUI and the underlying editor
///
/// - SeeAlso: ``SampleCodeEditorView`` for the SwiftUI wrapper
class SampleCodeEditorCoordinator {
    /// Reference to the underlying CodeEditorView instance.
    var editorView: CodeEditorView?
}

/// A SwiftUI wrapper for the CodeEditorPlugin with sample app specific features.
///
/// `SampleCodeEditorView` provides a comprehensive SwiftUI interface to the
/// CodeEditorPlugin with dynamic configuration updates, cross-platform support,
/// and integration with the sample app's state management system.
///
/// ## Features
///
/// - **Dynamic Configuration**: Live updates when settings change
/// - **Cross-Platform Support**: Optimized for both macOS and iOS
/// - **State Integration**: Connected to the app's state management
/// - **Language Support**: Automatic syntax highlighting based on language
///
/// ## Platform Adaptations
///
/// The view automatically adapts its behavior based on the platform:
/// - **macOS**: Uses native CodeEditorView with full feature support
/// - **iOS**: Optimized for touch interaction with appropriate controls
/// - **Mac Catalyst**: Hybrid approach combining desktop and touch features
///
/// ## Usage
///
/// ```swift
/// SampleCodeEditorView(
///     configuration: appState.currentConfiguration,
///     text: $appState.code,
///     language: "swift"
/// )
/// .environmentObject(appState)
/// ```
///
/// ## Configuration Updates
///
/// The view automatically responds to configuration changes and applies
/// them to the underlying editor without disrupting the editing experience.
///
/// - Note: The view uses ``CodeEditorViewWrapper`` internally to handle
///   platform-specific editor instantiation and management.
///
/// - SeeAlso: ``CodeEditorViewWrapper`` for the underlying wrapper
/// - SeeAlso: ``AppState`` for state management integration
/// - SeeAlso: ``EditorConfiguration`` for configuration options
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
