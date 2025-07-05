import Foundation
import ObjectiveC
import os.log

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

    /// Enable/disable syntax highlighting (convenience property)
    public var isSyntaxHighlightingEnabled: Bool {
        get { configuration.display.enableSyntaxHighlighting }
        set {
            var display = configuration.display
            display.enableSyntaxHighlighting = newValue
            configuration = configuration.with(display: display)
        }
    }

    /// Controls whether line numbers are shown (convenience property)
    public var showsLineNumbers: Bool {
        get { configuration.display.showLineNumbers }
        set {
            var display = configuration.display
            display.showLineNumbers = newValue
            configuration = configuration.with(display: display)
        }
    }

    /// Controls whether the current line is highlighted (convenience property)
    public var highlightSelectedLine: Bool {
        get { configuration.display.highlightSelectedLine }
        set {
            var display = configuration.display
            display.highlightSelectedLine = newValue
            configuration = configuration.with(display: display)
        }
    }

    /// Controls whether invisible characters are shown (convenience property)
    public var showsInvisibleCharacters: Bool {
        get { configuration.display.showInvisibleCharacters }
        set {
            var display = configuration.display
            display.showInvisibleCharacters = newValue
            configuration = configuration.with(display: display)
        }
    }
    
    /// Controls whether code folding is enabled (convenience property)
    public var enablesCodeFolding: Bool {
        get { configuration.display.enableCodeFolding }
        set {
            var display = configuration.display
            display.enableCodeFolding = newValue
            configuration = configuration.with(display: display)
        }
    }
    
    /// Controls whether folding controls are shown in the gutter (convenience property)
    public var showsFoldingControls: Bool {
        get { configuration.display.showFoldingControls }
        set {
            var display = configuration.display
            display.showFoldingControls = newValue
            configuration = configuration.with(display: display)
        }
    }

    // MARK: - Completion System
    
    /// Whether completion should be enabled
    public var isCompletionEnabled: Bool {
        get { configuration.behavior.enableCodeCompletion }
        set {
            var behavior = configuration.behavior
            behavior.enableCodeCompletion = newValue
            configuration = configuration.with(behavior: behavior)
        }
    }
    
    // MARK: - Improved Boolean Property Aliases (Consistent Naming)
    
    /// Improved alias for isSyntaxHighlightingEnabled (consistent with shows* pattern)
    public var showsSyntaxHighlighting: Bool {
        get { isSyntaxHighlightingEnabled }
        set { isSyntaxHighlightingEnabled = newValue }
    }
    
    /// Improved alias for highlightSelectedLine (consistent with shows* pattern)  
    public var showsSelectedLineHighlight: Bool {
        get { highlightSelectedLine }
        set { highlightSelectedLine = newValue }
    }
    
    /// Improved alias for isCompletionEnabled (consistent with enables* pattern)
    public var enablesCodeCompletion: Bool {
        get { isCompletionEnabled }
        set { isCompletionEnabled = newValue }
    }

    // MARK: - Coordinate System

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// NSTextView requires flipped coordinates for proper text rendering
    nonisolated override public var isFlipped: Bool {
        true
    }
    #endif
}
