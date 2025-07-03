#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import Foundation
import SwiftUI

// MARK: - Main Module Exports

/// CodeEditorPlugin: Production-ready code editor component for Swift applications
///
/// This module provides a comprehensive code editing solution with:
/// - **20 programming languages** with syntax highlighting
/// - **Cross-platform support** for macOS, iOS, and Mac Catalyst
/// - **Modern Swift 6 concurrency** with actor-based architecture
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
/// ### Configuration with Builder Pattern
/// ```swift
/// let config = EditorConfigurationBuilder()
///     .fontSize(16)
///     .theme(.dark)
///     .language(.swift)
///     .build()
///
/// editor.configuration = config
/// ```
///
/// ## Architecture
///
/// The plugin uses a feature-based architecture with clear separation of concerns:
/// - **Core**: Main text view and editing functionality
/// - **Configuration**: Unified configuration system with builder pattern
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
    /// Current version of the CodeEditorPlugin
    public static let version = "1.0.0"
    
    /// Swift version used to build the plugin
    public static let swiftVersion = "6.0"
    
    /// Minimum supported macOS version
    public static let minimumMacOSVersion = "12.0"
    
    /// Minimum supported iOS version
    public static let minimumIOSVersion = "16.0"
    
    /// Supported programming languages count
    public static let supportedLanguagesCount = 17

    private init() {}
}

// MARK: - Essential Type Aliases

// Main text view types (for backward compatibility)
public typealias CodeEditorTextView = CodeEditorView
public typealias CodeEditorDelegate = CodeEditorViewDelegate

// MARK: - CodeEditorPluginModule

public enum CodeEditorPluginModule {
    /// Initialize the CodeEditorPlugin module with default configuration
    public static func initialize() {
        // Perform any necessary module initialization
        // This could include registering default themes, languages, etc.
    }
}
