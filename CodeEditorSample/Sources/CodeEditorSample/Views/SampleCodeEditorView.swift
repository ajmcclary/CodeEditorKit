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
/// This coordinator maintains a reference to the underlying ``editorView``
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
/// - SeeAlso: ``dragConfiguration(_:)`` for configuration options
struct SampleCodeEditorView: View {
    @EnvironmentObject var appState: AppState
    @Binding var text: String
    let language: String
    private let coordinator = SampleCodeEditorCoordinator()
    
    // Force view updates when configuration changes
    @State private var configurationHash: Int = 0
    @State private var viewID = UUID()

    var body: some View {
        ZStack {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            // macOS Native: Use NSViewRepresentable wrapper
            CodeEditorViewWrapper(
                configuration: appState.coordinator.configuration,
                text: $text,
                language: language
            ) { textView in
                coordinator.editorView = textView
            }
            .id(viewID)
            #else
            // iOS/iPadOS/Mac Catalyst: Use SwiftUI CodeEditor directly
            // IMPORTANT: Do NOT use .id() here as it forces view recreation
            // The CodeEditor handles configuration updates internally
            CodeEditor(text: $text)
                .codeLanguage(detectLanguage(from: language))
                .environment(\.codeEditorConfiguration, appState.coordinator.configuration)
                .onAppear {
                    // iOS CodeEditor appeared
                }
            #endif
            
            // Visual indicators overlay - only show on macOS, not on iOS or Mac Catalyst
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            VStack {
                HStack {
                    Spacer()
                    if appState.coordinator.configuration.display.showMinimap {
                        MinimapIndicator()
                    }
                }
                Spacer()
                HStack {
                    if appState.coordinator.configuration.display.enableAnnotations {
                        AnnotationIndicator()
                    }
                    Spacer()
                }
            }
            .padding()
            #endif
        }
        .onAppear {
            updateConfigurationHash()
        }
        .onChangeCompat(of: appState.coordinator.configuration) { _ in
            updateConfigurationHash()
        }
    }
    
    private func updateConfigurationHash() {
        // Create a hash from configuration properties to force view updates
        var hasher = Hasher()
        hasher.combine(appState.coordinator.configuration.display.showLineNumbers)
        hasher.combine(appState.coordinator.configuration.display.fontSize)
        hasher.combine(appState.coordinator.configuration.display.enableSyntaxHighlighting)
        hasher.combine(appState.coordinator.configuration.display.enableAnnotations)
        hasher.combine(appState.coordinator.configuration.display.showMinimap)
        hasher.combine(appState.coordinator.configuration.layout.tabWidth)
        hasher.combine(appState.coordinator.configuration.layout.wrapLines)
        hasher.combine(appState.coordinator.configuration.behavior.isEditable)
        let newHash = hasher.finalize()
        
        // Only update if hash actually changed
        if newHash != configurationHash {
            configurationHash = newHash
            
            // For iOS/Catalyst, do NOT force view recreation
            // The CodeEditor handles configuration updates internally via environment
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            // Only force recreation on macOS native where we use NSViewRepresentable
            viewID = UUID()
            #endif
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
