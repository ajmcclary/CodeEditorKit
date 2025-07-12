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
    public typealias Color = PlatformColor
    public typealias Font = PlatformFont
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
    
    /// Controls whether syntax highlighting is enabled (convenience property)
    @available(*, deprecated, renamed: "isSyntaxHighlightingEnabled", message: "Use isSyntaxHighlightingEnabled for consistent naming")
    public var showsSyntaxHighlighting: Bool {
        get { isSyntaxHighlightingEnabled }
        set { isSyntaxHighlightingEnabled = newValue }
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
    
    /// Controls whether line numbers are shown (convenience property)
    @available(*, deprecated, renamed: "isLineNumbersEnabled", message: "Use isLineNumbersEnabled for consistent naming")
    public var showsLineNumbers: Bool {
        get { isLineNumbersEnabled }
        set { isLineNumbersEnabled = newValue }
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
    
    /// Controls whether the current line is highlighted (convenience property)
    @available(*, deprecated, renamed: "isSelectedLineHighlightEnabled", message: "Use isSelectedLineHighlightEnabled for consistent naming")
    public var showsSelectedLineHighlight: Bool {
        get { isSelectedLineHighlightEnabled }
        set { isSelectedLineHighlightEnabled = newValue }
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
    
    /// Controls whether invisible characters are shown (convenience property)
    @available(*, deprecated, renamed: "isInvisibleCharactersEnabled", message: "Use isInvisibleCharactersEnabled for consistent naming")
    public var showsInvisibleCharacters: Bool {
        get { isInvisibleCharactersEnabled }
        set { isInvisibleCharactersEnabled = newValue }
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
    
    /// Controls whether code folding is enabled (convenience property)
    @available(*, deprecated, renamed: "isCodeFoldingEnabled", message: "Use isCodeFoldingEnabled for consistent naming")
    public var enablesCodeFolding: Bool {
        get { isCodeFoldingEnabled }
        set { isCodeFoldingEnabled = newValue }
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
    
    /// Controls whether folding controls are shown in the gutter (convenience property)
    @available(*, deprecated, renamed: "isFoldingControlsEnabled", message: "Use isFoldingControlsEnabled for consistent naming")
    public var showsFoldingControls: Bool {
        get { isFoldingControlsEnabled }
        set { isFoldingControlsEnabled = newValue }
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
    
    /// Controls whether code completion is enabled (convenience property)
    @available(*, deprecated, renamed: "isCodeCompletionEnabled", message: "Use isCodeCompletionEnabled for consistent naming")
    public var enablesCodeCompletion: Bool {
        get { isCodeCompletionEnabled }
        set { isCodeCompletionEnabled = newValue }
    }

    // MARK: - Coordinate System

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// NSTextView requires flipped coordinates for proper text rendering
    nonisolated override public var isFlipped: Bool {
        true
    }
    #endif
}
