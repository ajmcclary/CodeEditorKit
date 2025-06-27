#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
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
public typealias CodeEditorTextView = CodeEditorView
public typealias CodeEditorDelegate = CodeEditorViewDelegate

// Plugin types have been removed - functionality integrated directly into CodeEditorView

// Annotation types
public typealias CodeEditorAnnotation = LineAnnotation
public typealias CodeEditorAnnotationDataSource = AnnotationsDataSource

// Highlighting types
// Note: CodeEditorTheme is defined in SwiftUI/CodeEditor.swift
public typealias CodeEditorToken = Token
public typealias CodeEditorTokenType = TokenType
public typealias CodeEditorSyntaxHighlighter = SyntaxHighlightingCoordinator

// macOS 26 Compatibility types
#if canImport(AppKit)
public typealias CodeEditorAdaptiveColors = AdaptiveColorSystem
public typealias CodeEditorVersionDetection = MacOSVersionDetection
public typealias CodeEditorModernTextKit = ModernTextKitHelper
#endif

// MARK: - New Architecture Types

// Configuration
public typealias EditorConfig = EditorConfiguration

// Events
// Note: EditorEventType protocol is defined in Events/EditorEvent.swift
// Note: EditorEventHandler and EditorEventPublisher are defined in Events/EditorEvent.swift

// Layout
public typealias LayoutCoord = LayoutCoordinator
public typealias LayoutCtx = LayoutContext

// Language System
// public typealias LanguageProvider = LanguageProvider // Removed self-referential type alias
public typealias LanguageReg = LanguageRegistry

// Performance
public typealias PerfMonitor = PerformanceMonitor
// Note: PerformanceMetric type alias removed due to ambiguity - use specific types directly
public typealias PerfReport = PerformanceReport

// MARK: - CodeEditorPluginModule

public enum CodeEditorPluginModule {
    /// Initialize the CodeEditorPlugin module with default configuration
    public static func initialize() {
        // Perform any necessary module initialization
        // This could include registering default themes, languages, etc.
    }
}
