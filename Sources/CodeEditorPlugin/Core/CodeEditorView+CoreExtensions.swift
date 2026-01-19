import Foundation
import ObjectiveC

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - Core Properties

extension CodeEditorView {
    // CodeEditorViewProtocol conformance
    /// Platform-independent color type for cross-platform compatibility.
    ///
    /// This type alias provides a unified interface for colors across different Apple platforms,
    /// automatically resolving to `NSColor` on macOS and `UIColor` on iOS/iPadOS.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let textColor: CodeEditorView.Color = .label
    /// let backgroundColor: CodeEditorView.Color = .systemBackground
    /// ```
    public typealias Color = PlatformColor

    /// Platform-independent font type for cross-platform compatibility.
    ///
    /// This type alias provides a unified interface for fonts across different Apple platforms,
    /// automatically resolving to `NSFont` on macOS and `UIFont` on iOS/iPadOS.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let codeFont: CodeEditorView.Font = .monospacedSystemFont(ofSize: 14, weight: .regular)
    /// ```
    public typealias Font = PlatformFont

    /// The delegate type for receiving editor events and customizing behavior.
    ///
    /// This type alias provides a consistent interface for the delegate protocol across platforms,
    /// allowing for editor customization and event handling.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// class MyEditorDelegate: CodeEditorView.Delegate {
    ///     // Implement delegate methods
    /// }
    /// ```
    public typealias Delegate = CodeEditorViewDelegate

    // MARK: - Properties

    /// The delegate that receives notifications about text editing events.
    ///
    /// The delegate provides hooks for customizing editor behavior, responding to text changes,
    /// handling completion events, and managing editor lifecycle.
    ///
    /// ## Example
    ///
    /// ```swift
    /// class MyDelegate: CodeEditorViewDelegate {
    ///     func textViewDidChangeText(_ notification: Notification) {
    ///         // Handle text changes
    ///     }
    ///     
    ///     func textView(_ textView: CodeEditorView, shouldChangeTextIn range: NSRange, 
    ///                   replacementString: String) -> Bool {
    ///         // Validate text changes
    ///         return true
    ///     }
    /// }
    /// 
    /// editor.textDelegate = MyDelegate()
    /// ```
    ///
    /// - SeeAlso: `CodeEditorViewDelegate`
    public weak var textDelegate: (any CodeEditorViewDelegate)? {
        get {
            delegateProxy.source
        }
        set {
            delegateProxy.source = newValue
        }
    }

    /// Controls whether syntax highlighting is enabled (convenience property)
    public var isSyntaxHighlightingEnabled: Bool {
        get { configuration.display.enableSyntaxHighlighting }
        set {
            var display = configuration.display
            display.enableSyntaxHighlighting = newValue
            configuration = configuration.with(display: display)
        }
    }

    /// Controls whether line numbers are shown (convenience property)
    public var isLineNumbersEnabled: Bool {
        get { configuration.display.isLineNumbersEnabled }
        set {
            var display = configuration.display
            display.isLineNumbersEnabled = newValue
            configuration = configuration.with(display: display)
        }
    }

    /// Controls whether the current line is highlighted (convenience property)
    public var isSelectedLineHighlightEnabled: Bool {
        get { configuration.display.highlightSelectedLine }
        set {
            var display = configuration.display
            display.highlightSelectedLine = newValue
            configuration = configuration.with(display: display)
        }
    }

    /// Controls whether invisible characters are shown (convenience property)
    public var isInvisibleCharactersEnabled: Bool {
        get { configuration.display.showInvisibleCharacters }
        set {
            var display = configuration.display
            display.showInvisibleCharacters = newValue
            configuration = configuration.with(display: display)
        }
    }

    /// Controls whether code folding is enabled (convenience property)
    public var isCodeFoldingEnabled: Bool {
        get { configuration.display.enableCodeFolding }
        set {
            var display = configuration.display
            display.enableCodeFolding = newValue
            configuration = configuration.with(display: display)
        }
    }

    /// Controls whether folding controls are shown in the gutter (convenience property)
    public var isFoldingControlsEnabled: Bool {
        get { configuration.display.showFoldingControls }
        set {
            var display = configuration.display
            display.showFoldingControls = newValue
            configuration = configuration.with(display: display)
        }
    }

    // MARK: - Completion System

    /// Controls whether code completion is enabled (convenience property)
    public var isCodeCompletionEnabled: Bool {
        get { configuration.behavior.enableCodeCompletion }
        set {
            var behavior = configuration.behavior
            behavior.enableCodeCompletion = newValue
            configuration = configuration.with(behavior: behavior)
        }
    }

    // MARK: - Coordinate System

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// NSTextView requires flipped coordinates for proper text rendering
    override nonisolated public var isFlipped: Bool {
        true
    }
    #endif
}
