//
//  CodeEditorEnvironment.swift
//  CodeEditorPlugin
//
//  Consolidated environment configuration for CodeEditor SwiftUI view
//

import SwiftUI

// MARK: - Supporting Types

/// Options for updating the become first responder state
@available(macOS 12.0, iOS 16.0, *)
public enum BecomeFirstResponderOption: Sendable {
    case yes
    case no
    case unchanged
}

// MARK: - Consolidated Environment Configuration

/// A single environment configuration that consolidates all CodeEditor settings
@available(macOS 12.0, iOS 16.0, *)
public struct CodeEditorEnvironment: Sendable {
    /// The language for syntax highlighting
    public var language: Language

    /// The theme for visual styling
    public var theme: Theme

    /// The editor configuration settings
    public var configuration: EditorConfiguration

    /// Whether the editor should become first responder
    public var becomeFirstResponder: Bool

    /// Optional memory monitor for performance tracking
    public var memoryMonitor: MemoryMonitor?

    /// Optional unified event system for advanced event handling
    public var eventSystem: UnifiedEventSystem?

    /// Creates a new CodeEditor environment configuration
    public init(
        language: Language = .plainText,
        theme: Theme = .default,
        configuration: EditorConfiguration = EditorConfiguration(),
        becomeFirstResponder: Bool = false,
        memoryMonitor: MemoryMonitor? = nil,
        eventSystem: UnifiedEventSystem? = nil
    ) {
        self.language = language
        self.theme = theme
        self.configuration = configuration
        self.becomeFirstResponder = becomeFirstResponder
        self.memoryMonitor = memoryMonitor
        self.eventSystem = eventSystem
    }

    /// Default environment configuration
    public static let `default` = Self()

    /// Creates a copy with updated values
    public func with(
        language: Language? = nil,
        theme: Theme? = nil,
        configuration: EditorConfiguration? = nil,
        becomeFirstResponder: BecomeFirstResponderOption = .unchanged,
        memoryMonitor: MemoryMonitor? = nil,
        eventSystem: UnifiedEventSystem? = nil
    ) -> Self {
        Self(
            language: language ?? self.language,
            theme: theme ?? self.theme,
            configuration: configuration ?? self.configuration,
            becomeFirstResponder: becomeFirstResponder == .unchanged ? self.becomeFirstResponder : (becomeFirstResponder == .yes),
            memoryMonitor: memoryMonitor ?? self.memoryMonitor,
            eventSystem: eventSystem ?? self.eventSystem
        )
    }
}

// MARK: - Environment Key

@available(macOS 12.0, iOS 16.0, *)
public struct CodeEditorEnvironmentKey: EnvironmentKey {
    public static let defaultValue = CodeEditorEnvironment.default

    public typealias Value = CodeEditorEnvironment
}

// MARK: - Environment Values Extension

@available(macOS 12.0, iOS 16.0, *)
extension EnvironmentValues {
    /// The consolidated CodeEditor environment configuration
    public var codeEditorEnvironment: CodeEditorEnvironment {
        get { self[CodeEditorEnvironmentKey.self] }
        set { self[CodeEditorEnvironmentKey.self] = newValue }
    }

    // MARK: - Legacy Support (Computed Properties)

    /// Legacy: Access the theme directly
    public var codeEditorTheme: Theme {
        get { codeEditorEnvironment.theme }
        set { codeEditorEnvironment = codeEditorEnvironment.with(theme: newValue) }
    }

    /// Legacy: Access the language directly
    public var codeEditorLanguage: Language {
        get { codeEditorEnvironment.language }
        set { codeEditorEnvironment = codeEditorEnvironment.with(language: newValue) }
    }

    /// Legacy: Access the configuration directly
    public var codeEditorConfiguration: EditorConfiguration {
        get { codeEditorEnvironment.configuration }
        set { codeEditorEnvironment = codeEditorEnvironment.with(configuration: newValue) }
    }

    /// Legacy: Access the become first responder flag directly
    public var codeEditorBecomeFirstResponder: Bool {
        get { codeEditorEnvironment.becomeFirstResponder }
        set { codeEditorEnvironment = codeEditorEnvironment.with(becomeFirstResponder: newValue ? .yes : .no) }
    }

    /// Legacy: Access the memory monitor directly
    public var codeEditorMemoryMonitor: MemoryMonitor? {
        get { codeEditorEnvironment.memoryMonitor }
        set { codeEditorEnvironment = codeEditorEnvironment.with(memoryMonitor: newValue) }
    }

    /// Legacy: Access the event system directly
    public var codeEditorEventSystem: UnifiedEventSystem? {
        get { codeEditorEnvironment.eventSystem }
        set { codeEditorEnvironment = codeEditorEnvironment.with(eventSystem: newValue) }
    }
}

// MARK: - View Modifiers

@available(macOS 12.0, iOS 16.0, *)
extension View {
    /// Set the complete CodeEditor environment configuration
    public func codeEditorEnvironment(_ environment: CodeEditorEnvironment) -> some View {
        self.environment(\.codeEditorEnvironment, environment)
    }

    /// Set the CodeEditor environment using a builder closure
    public func codeEditorEnvironment(@CodeEditorEnvironmentBuilder builder: () -> CodeEditorEnvironment) -> some View {
        self.environment(\.codeEditorEnvironment, builder())
    }

    // MARK: - Convenience Modifiers

    /// Update specific properties of the CodeEditor environment
    public func codeEditorEnvironment(
        language: Language? = nil,
        theme: Theme? = nil,
        configuration: EditorConfiguration? = nil,
        becomeFirstResponder: BecomeFirstResponderOption = .unchanged,
        memoryMonitor: MemoryMonitor? = nil,
        eventSystem: UnifiedEventSystem? = nil
    ) -> some View {
        transformEnvironment(\.codeEditorEnvironment) { env in
            env = env.with(
                language: language,
                theme: theme,
                configuration: configuration,
                becomeFirstResponder: becomeFirstResponder,
                memoryMonitor: memoryMonitor,
                eventSystem: eventSystem
            )
        }
    }
}

// MARK: - Result Builder

/// A result builder for constructing code editor environments in a declarative manner.
///
/// This result builder allows you to create `CodeEditorEnvironment` instances using a block-based syntax,
/// making it easier to configure multiple environment properties in a clean, readable way.
///
/// ## Usage
/// ```swift
/// .codeEditorEnvironment {
///     CodeEditorEnvironment(
///         language: .swift,
///         theme: .dark,
///         configuration: myConfig
///     )
/// }
/// ```
@available(macOS 12.0, iOS 16.0, *)
@resultBuilder
public enum CodeEditorEnvironmentBuilder {
    /// Builds a block of environment values.
    /// - Parameter environment: The environment to build
    /// - Returns: The built environment
    public static func buildBlock(_ environment: CodeEditorEnvironment) -> CodeEditorEnvironment {
        environment
    }

    /// Builds an expression of environment values.
    /// - Parameter environment: The environment expression
    /// - Returns: The built environment
    public static func buildExpression(_ environment: CodeEditorEnvironment) -> CodeEditorEnvironment {
        environment
    }
}
