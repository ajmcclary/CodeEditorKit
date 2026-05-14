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

    /// Workspace root for LSP and file operations.
    public var workspaceRoot: URL?

    /// Optional memory monitor for performance tracking
    public var memoryMonitor: MemoryMonitor?

    /// Optional unified event system for advanced event handling
    public var eventSystem: UnifiedEventSystem?

    /// Optional complete runtime setup. When present, this is the canonical
    /// source for runtime dependencies.
    public var runtimeDependencies: EditorRuntimeDependencies?

    /// Optional performance observation. When set, the editor's effective
    /// configuration receives `observation.system` as its
    /// `performance.unifiedPerformanceSystem`, so framework producers
    /// (e.g. AsyncSyntaxHighlighter) record metrics into the system the
    /// host observes. Paired with the `.performanceObserver(_:)` modifier.
    public var performanceObservation: PerformanceObservation?

    /// Creates a new CodeEditor environment configuration
    public init(
        language: Language = .plainText,
        theme: Theme = .default,
        configuration: EditorConfiguration = EditorConfiguration(),
        becomeFirstResponder: Bool = false,
        workspaceRoot: URL? = nil,
        memoryMonitor: MemoryMonitor? = nil,
        eventSystem: UnifiedEventSystem? = nil,
        runtimeDependencies: EditorRuntimeDependencies? = nil,
        performanceObservation: PerformanceObservation? = nil
    ) {
        self.language = language
        self.theme = theme
        self.configuration = configuration
        self.becomeFirstResponder = becomeFirstResponder
        self.workspaceRoot = workspaceRoot
        self.memoryMonitor = memoryMonitor
        self.eventSystem = eventSystem
        self.runtimeDependencies = runtimeDependencies
        self.performanceObservation = performanceObservation
    }

    /// Default environment configuration
    public static let `default` = Self()

    /// Creates a copy with updated values
    public func with(
        language: Language? = nil,
        theme: Theme? = nil,
        configuration: EditorConfiguration? = nil,
        becomeFirstResponder: BecomeFirstResponderOption = .unchanged,
        workspaceRoot: URL? = nil,
        memoryMonitor: MemoryMonitor? = nil,
        eventSystem: UnifiedEventSystem? = nil,
        runtimeDependencies: EditorRuntimeDependencies? = nil,
        performanceObservation: PerformanceObservation? = nil
    ) -> Self {
        Self(
            language: language ?? self.language,
            theme: theme ?? self.theme,
            configuration: configuration ?? self.configuration,
            becomeFirstResponder: becomeFirstResponder == .unchanged ? self.becomeFirstResponder : (becomeFirstResponder == .yes),
            workspaceRoot: workspaceRoot ?? self.workspaceRoot,
            memoryMonitor: memoryMonitor ?? self.memoryMonitor,
            eventSystem: eventSystem ?? self.eventSystem,
            runtimeDependencies: runtimeDependencies ?? self.runtimeDependencies,
            performanceObservation: performanceObservation ?? self.performanceObservation
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

    /// Legacy: Access the memory monitor directly.
    ///
    /// Writing `nil` clears the underlying field on the
    /// `CodeEditorEnvironment`. (The setter writes the field directly
    /// instead of routing through `with(_:)`, which treats `nil` as
    /// "no change".)
    public var codeEditorMemoryMonitor: MemoryMonitor? {
        get { codeEditorEnvironment.memoryMonitor }
        set {
            var env = codeEditorEnvironment
            env.memoryMonitor = newValue
            codeEditorEnvironment = env
        }
    }

    /// Legacy: Access the event system directly.
    ///
    /// Writing `nil` clears the underlying field on the
    /// `CodeEditorEnvironment`.
    public var codeEditorEventSystem: UnifiedEventSystem? {
        get { codeEditorEnvironment.eventSystem }
        set {
            var env = codeEditorEnvironment
            env.eventSystem = newValue
            codeEditorEnvironment = env
        }
    }

    /// Legacy: Access the performance observation directly.
    ///
    /// Writing `nil` clears the underlying field on the
    /// `CodeEditorEnvironment`.
    public var codeEditorPerformanceObservation: PerformanceObservation? {
        get { codeEditorEnvironment.performanceObservation }
        set {
            var env = codeEditorEnvironment
            env.performanceObservation = newValue
            codeEditorEnvironment = env
        }
    }

    /// Legacy: Access the workspace root directly.
    ///
    /// Writing `nil` clears the underlying field on the
    /// `CodeEditorEnvironment`.
    public var codeEditorWorkspaceRoot: URL? {
        get { codeEditorEnvironment.workspaceRoot }
        set {
            var env = codeEditorEnvironment
            env.workspaceRoot = newValue
            codeEditorEnvironment = env
        }
    }

    /// Access complete runtime dependencies directly.
    ///
    /// Writing `nil` clears the underlying field on the
    /// `CodeEditorEnvironment`.
    public var codeEditorRuntimeDependencies: EditorRuntimeDependencies? {
        get { codeEditorEnvironment.runtimeDependencies }
        set {
            var env = codeEditorEnvironment
            env.runtimeDependencies = newValue
            codeEditorEnvironment = env
        }
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
        workspaceRoot: URL? = nil,
        memoryMonitor: MemoryMonitor? = nil,
        eventSystem: UnifiedEventSystem? = nil,
        runtimeDependencies: EditorRuntimeDependencies? = nil,
        performanceObservation: PerformanceObservation? = nil
    ) -> some View {
        transformEnvironment(\.codeEditorEnvironment) { env in
            env = env.with(
                language: language,
                theme: theme,
                configuration: configuration,
                becomeFirstResponder: becomeFirstResponder,
                workspaceRoot: workspaceRoot,
                memoryMonitor: memoryMonitor,
                eventSystem: eventSystem,
                runtimeDependencies: runtimeDependencies,
                performanceObservation: performanceObservation
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
