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
/// - **20 programming languages** with syntax highlighting
/// - **Cross-platform support** for macOS, iOS, and Mac Catalyst
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
/// The plugin uses a feature-based architecture with clear separation of concerns:
/// - **Core**: Main text view and editing functionality
/// - **Configuration**: Unified nested configuration values and presets
/// - **SyntaxHighlighting**: Multi-language highlighting with SwiftSyntax integration
/// - **Platform**: Cross-platform abstraction layer
/// - **Extensions**: Utility extensions and helpers
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
