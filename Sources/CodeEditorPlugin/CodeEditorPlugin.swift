import AppKit
import Foundation
import SwiftUI

// MARK: - Main Module Exports

public struct CodeEditorPlugin {
    public static let version = "1.0.0"
    public static let swiftVersion = "6.0"

    private init() {}
}

// MARK: - Convenience Typealiases

// Main text view types
public typealias CodeEditorTextView = STTextView
public typealias CodeEditorDelegate = STTextViewDelegate

// Plugin types have been removed - functionality integrated directly into STTextView

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
public typealias CodeEditorVersionDetection = MacOSVersionDetection
public typealias CodeEditorModernTextKit = ModernTextKitHelper

// MARK: - CodeEditorPluginModule

public enum CodeEditorPluginModule {
    /// Initialize the CodeEditorPlugin module with default configuration
    public static func initialize() {
        // Perform any necessary module initialization
        // This could include registering default themes, languages, etc.
    }
}
