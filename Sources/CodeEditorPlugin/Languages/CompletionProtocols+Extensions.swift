import Foundation

// MARK: - Completion Provider Protocol

/// Protocol for providing code completions.
///
/// Implement this protocol to create custom completion providers that can
/// suggest code completions for specific languages or contexts.
///
/// ## Implementing a Provider
///
/// ```swift
/// @MainActor
/// final class CustomCompletionProvider: CompletionProvider {
///     let id = "custom-provider"
///     let supportedLanguages: [Language] = [.swift]
///     let triggerCharacters = [".", "(", "[", "<"]
///     let supportsSnippets = true
///     
///     func completions(for context: CompletionContextModel) async throws -> CompletionResult {
///         // Analyze context and generate completions
///         let items = generateCompletions(context)
///         return CompletionResult(items: items, context: context)
///     }
/// }
/// ```
///
/// ## Registration
///
/// Providers are registered with the `CompletionManager`:
///
/// ```swift
/// let manager = CompletionManager()
/// let provider = CustomCompletionProvider()
/// manager.registerProvider(provider)
/// ```
///
/// - SeeAlso: ``CompletionItemModel``, ``CompletionContextModel``, ``CompletionManager``
public protocol CompletionProvider: Sendable {
    /// Unique identifier for this provider
    var id: String { get }

    /// Languages supported by this provider
    var supportedLanguages: [Language] { get }

    /// Characters that trigger completion automatically
    var triggerCharacters: [String] { get }

    /// Whether this provider supports snippet insertions
    var supportsSnippets: Bool { get }

    /// Provide completions for the given context
    /// - Parameter context: The completion context
    /// - Returns: Completion result with items
    @MainActor
    func completions(for context: CompletionContextModel) async throws -> CompletionResult
}

// MARK: - Default Implementation

extension CompletionProvider {
    /// Default trigger characters - empty array for providers that don't require triggers
    public var triggerCharacters: [String] { [] }

    /// Default snippet support - false for providers that don't support snippets
    public var supportsSnippets: Bool { false }
}
