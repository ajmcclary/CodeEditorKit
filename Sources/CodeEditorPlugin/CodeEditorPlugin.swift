import Foundation
import AppKit
import SwiftUI

// MARK: - Main Module Exports

// Re-export key types for easy access
@_exported import Foundation
@_exported import AppKit
@_exported import SwiftUI

// MARK: - Module Documentation

/**
 # CodeEditorPlugin
 
 A unified Swift package that provides comprehensive text editing capabilities with syntax highlighting,
 annotations, and advanced text processing features.
 
 ## Key Features
 
 - **TextKit2-based Text Editing**: Modern text view implementation using Apple's TextKit2
 - **macOS 26 Liquid Glass Design**: Adaptive colors and layouts for the latest macOS design
 - **SwiftSyntax Integration**: Professional Swift code highlighting with Apple's official parser
 - **Multi-Language Support**: Regex-based highlighting for 15+ programming languages
 - **Line Annotations**: Support for displaying contextual information alongside code
 - **Plugin System**: Extensible architecture for adding custom functionality
 - **Swift 6 Concurrency**: Full actor-based concurrency support with strict checking
 - **Multi-platform**: Support for macOS, iOS, and Mac Catalyst
 
 ## Architecture
 
 The package is organized into logical components:
 
 - **Actors**: Background processing and concurrency primitives
 - **Services**: Core text editing, parsing, and highlighting services
 - **Plugins**: Modular functionality (Neon highlighting, Annotations)
 - **Models**: Data structures for text, parsing, and layout
 - **Extensions**: Platform and framework extensions
 - **Protocols**: Interfaces for delegates and data sources
 - **Performance**: Optimized range processing and layout
 - **DSL**: Tree-sitter queries and theme definitions
 
 ## Usage
 
 ```swift
 import CodeEditorPlugin
 
 // Create a modern text editor with macOS 26 compatibility
 let textView = CodeEditorTextView()
 textView.applyModernConfiguration()
 
 // Set up syntax highlighting with adaptive colors
 let highlighter = CodeEditorSyntaxHighlighter()
 let language = highlighter.detectLanguage(from: "swift")
 let tokens = highlighter.highlight(source: sourceCode, language: language)
 highlighter.applyHighlighting(to: attributedString, tokens: tokens)
 
 // Check for macOS 26 features
 if CodeEditorVersionDetection.supportsLiquidGlassDesign {
     // Use enhanced features for Liquid Glass design
     textView.backgroundColor = CodeEditorAdaptiveColors.textBackgroundColor
 }
 ```
 */

// MARK: - Version Info

public struct CodeEditorPlugin {
    public static let version = "1.0.0"
    public static let swiftVersion = "6.0"
    
    private init() {}
}

// MARK: - Convenience Typealiases

// Main text view types
public typealias CodeEditorTextView = STTextView
public typealias CodeEditorDelegate = STTextViewDelegate

// Plugin types  
public typealias CodeEditorPluginProtocol = STPlugin
public typealias CodeEditorPluginContext = STPluginContext

// Annotation types
public typealias CodeEditorAnnotation = STLineAnnotation  
public typealias CodeEditorAnnotationDataSource = STAnnotationsDataSource

// Highlighting types
public typealias CodeEditorTheme = Theme
public typealias CodeEditorToken = Token
public typealias CodeEditorTokenType = TokenType
public typealias CodeEditorSyntaxHighlighter = SyntaxHighlightingCoordinator

// macOS 26 Compatibility types
public typealias CodeEditorAdaptiveColors = AdaptiveColorSystem
public typealias CodeEditorVersionDetection = macOSVersionDetection
public typealias CodeEditorModernTextKit = ModernTextKitHelper

// MARK: - Module Initialization

public struct CodeEditorPluginModule {
    /// Initialize the CodeEditorPlugin module with default configuration
    public static func initialize() {
        // Perform any necessary module initialization
        // This could include registering default themes, languages, etc.
    }
}