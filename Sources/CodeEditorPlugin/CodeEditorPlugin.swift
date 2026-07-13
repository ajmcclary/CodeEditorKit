// Umbrella re-exports: `import CodeEditorPlugin` is the single entry the
// Quick Start docstring promises, so the six sibling targets it visibly uses
// (CodeEditor / CodeEditorView / EditorConfiguration / Language / theme tokens
// / CodeEditorError) must come along automatically. Opt-in subsystems
// (Annotations, Completion, LSP, Search, Workspace, etc.) stay
// explicit-import — consumers reach for them by name when they want them.
@_exported import CodeEditorCommon
@_exported import CodeEditorConfiguration
@_exported import CodeEditorLanguages
@_exported import CodeEditorSwiftUI
@_exported import DesignKitThemes
@_exported import CodeEditorView

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Main Module Exports

/// CodeEditorPlugin: Production-ready code editor component for Swift applications
///
/// This module provides a comprehensive code editing solution with:
/// - **25 concrete programming languages plus plain text** with syntax highlighting
/// - **Cross-platform support** for native macOS and iOS / iPadOS
/// - **Modern Swift 6.3 concurrency** with actor-based architecture
/// - **SwiftUI and UIKit/AppKit integration**
/// - **Performance optimizations** for large files
/// - **Comprehensive error handling** with recovery mechanisms
///
/// ## Quick Start
///
/// ### SwiftUI Integration
/// ```swift
/// import SwiftUI
/// import CodeEditorPlugin
///
/// struct ContentView: View {
///     @State private var code = "logger.debug(\"Hello, World!\")"
///
///     var body: some View {
///         CodeEditor(text: $code)
///             .codeLanguage(.swift)
///             .showsLineNumbers(true)
///     }
/// }
/// ```
///
/// ### UIKit/AppKit Integration
/// ```swift
/// let editor = CodeEditorView()
/// editor.language = .swift
/// editor.showsLineNumbers = true
/// editor.text = "logger.debug(\"Hello, World!\")"
/// ```
///
/// ### Configuration
/// ```swift
/// var config = EditorConfiguration()
/// config.display.fontSize = 16
/// config.display.theme = .dark
///
/// editor.configuration = config
/// editor.language = .swift
/// ```
///
/// ## Architecture
///
/// The plugin uses a modular target architecture with clear separation of concerns:
/// - **CodeEditorView**: TextKit2 editor surface and view-coupled services
/// - **CodeEditorSwiftUI**: SwiftUI `CodeEditor` wrapper and environment integration
/// - **CodeEditorConfiguration**: Unified nested configuration values and presets
/// - **CodeEditorSyntaxHighlighting / CodeEditorLanguages**: Multi-language highlighting with SwiftSyntax integration
/// - **CodeEditorPlatform / CodeEditorCommon / CodeEditorTextModel**: Shared platform, utility, and text-model primitives
/// - **Focused products**: Diagnostics, LSP, layout, UI chrome, project search, and workspace APIs
///
/// ## Performance
///
/// - **Viewport-based rendering** for large files
/// - **Hardware acceleration** support
/// - **Actor-based concurrency** for thread safety
/// - **Memory limits** with automatic cleanup
/// - **Background processing** with cancellation support
///
/// ## Error Handling
///
/// Comprehensive error handling with `CodeEditorError` enum:
/// ```swift
/// do {
///     try editor.setText(content)
///     try editor.setLanguage(.python)
/// } catch let error as CodeEditorError {
///     logger.error("Error: \(error.localizedDescription)")
///     editor.attemptErrorRecovery(from: error)
/// }
/// ```
public struct CodeEditorPlugin {
    private init() {}
}
