import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@preconcurrency import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Protocol for custom completion item views.
///
/// Implement this protocol to provide custom UI for code completion items.
/// The default completion system uses `CompletionItemModel`, but you can
/// create custom implementations for specialized completion experiences.
///
/// ## Requirements
///
/// - Must be `Identifiable` with a unique identifier
/// - Must be `Sendable` for thread safety
/// - Must provide a platform-specific view
///
/// ## Example Implementation
///
/// ```swift
/// @MainActor
/// struct CustomCompletionItem: CompletionItem {
///     let id = UUID()
///     let title: String
///     let icon: Image
///     let insertText: String
///     
///     var view: PlatformView {
///         #if canImport(AppKit)
///         let view = NSView()
///         // Configure macOS view...
///         return view
///         #else
///         let view = UIView()
///         // Configure iOS view...
///         return view
///         #endif
///     }
/// }
/// ```
///
/// ## Integration
///
/// Custom completion items can be provided through completion providers:
///
/// ```swift
/// func completions(for context: CompletionContextModel) async -> [CompletionItem] {
///     return myItems.map { CustomCompletionItem(from: $0) }
/// }
/// ```
///
/// - SeeAlso: ``CompletionItemModel``, ``CompletionProvider``, ``CompletionManager``
@MainActor
public protocol CompletionItemView: Identifiable, Sendable {
    /// The platform-specific view representing this completion item.
    ///
    /// This view is displayed in the completion popup. It should be
    /// appropriately sized and styled for the current platform.
    ///
    /// - Note: Use `PlatformView` type alias for cross-platform compatibility.
    var view: PlatformView { get }
}
