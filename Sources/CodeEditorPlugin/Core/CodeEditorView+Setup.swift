import Foundation
import os.log

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - Initialization & Setup

extension CodeEditorView {
    // MARK: - Setup Methods
    
    internal func setupTextView() {
        #if DEBUG
        Self.logger.debug("CodeEditorView setupTextView: Starting setup")
        Self.logger.debug("CodeEditorView setupTextView: textStorage = exists")
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        Self.logger.debug("CodeEditorView setupTextView: layoutManager = \(self.layoutManager != nil ? "exists" : "nil")")
        #else
        Self.logger.debug("CodeEditorView setupTextView: layoutManager = exists")
        #endif
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        Self.logger.debug("CodeEditorView setupTextView: textContainer = \(self.textContainer != nil ? "exists" : "nil")")
        #else
        Self.logger.debug("CodeEditorView setupTextView: textContainer = exists")
        #endif
        Self.logger.debug("CodeEditorView setupTextView: textLayoutManager = \(self.textLayoutManager != nil ? "exists" : "nil")")
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        Self.logger.debug("CodeEditorView setupTextView: textContentStorage = \(self.textContentStorage != nil ? "exists" : "nil")")
        #endif
        #endif
        
        // Check which TextKit version we're using
        #if DEBUG
        if textLayoutManager != nil {
            Self.logger.debug("CodeEditorView setupTextView: Using TextKit2")
        } else {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            if layoutManager != nil {
                Self.logger.debug("CodeEditorView setupTextView: Using TextKit1 (fallback)")
            } else {
                Self.logger.debug("CodeEditorView setupTextView: WARNING - No layout manager detected!")
            }
            #else
            Self.logger.debug("CodeEditorView setupTextView: Using TextKit1 (UITextView default)")
            #endif
        }
        #endif
        
        // Try to ensure we're using TextKit2 if possible
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        #if DEBUG
        if textLayoutManager == nil && ModernTextKitHelper.shouldUseTextKit2 {
            Self.logger.debug("CodeEditorView setupTextView: Attempting to initialize with TextKit2")
            // Force TextKit2 initialization if needed
            // This is a fallback - normally NSTextView should auto-initialize with TextKit2
        }
        #endif
        #else
        // For iOS/Mac Catalyst, textLayoutManager is always nil since UITextView doesn't expose TextKit2
        #if DEBUG
        Self.logger.debug("CodeEditorView setupTextView: TextKit2 detection not available on iOS/Mac Catalyst")
        #endif
        #endif
        
        // Set up the text view
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        
        // Enable undo
        allowsUndo = true
        
        // Set up delegate
        delegate = delegateProxy
        #else
        // UITextView configuration
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
        
        // Disable automatic content inset adjustments to prevent scroll jumping
        contentInsetAdjustmentBehavior = .never
        
        // Set up delegate
        delegate = delegateProxy
        #endif
        
        // Set up text storage observation for syntax highlighting
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextStorageDidProcessEditing(_:)),
            name: NSTextStorage.didProcessEditingNotification,
            object: textStorage
        )
        #else
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextStorageDidProcessEditing(_:)),
            name: NSTextStorage.didProcessEditingNotification,
            object: textStorage
        )
        #endif
        
        // Set up selection change observation
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextViewDidChangeSelection(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: self
        )
        #else
        // UITextView doesn't have a direct selection change notification
        // We'll handle this through the delegate instead
        #endif
        
        // Setup theme
        setupDefaultTheme()
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        ModernTextKitHelper.configureTextView(self)
        ModernTextKitHelper.applyPerformanceOptimizations(to: self)
        
        // Ensure TextKit2 is used if available and beneficial
        let usingTextKit2 = ModernTextKitHelper.ensureTextKit2(for: self)
        Self.logger.debug("CodeEditorView setupTextView: Using TextKit2: \(usingTextKit2)")
        #else
        // ModernTextKitHelper is not available for iOS/Mac Catalyst
        Self.logger.debug("CodeEditorView setupTextView: Using TextKit1 (iOS/Mac Catalyst)")
        #endif
        
        // Ensure proper sizing and layout
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        isVerticallyResizable = true
        // Don't set isHorizontallyResizable here - it will be set by configuration
        if let textContainer = self.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
        }
        #elseif targetEnvironment(macCatalyst)
        // Mac Catalyst - textContainer is non-optional
        let textContainer = self.textContainer
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        #else
        // UITextView doesn't have these properties - it handles scrolling differently
        #endif
        
        // Make sure we have reasonable size constraints
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        minSize = NSSize(width: 0, height: 0)
        maxSize = NSSize(width: 10_000, height: 10_000)
        #endif
        
        Self.logger.debug("CodeEditorView setupTextView: Final frame = \(String(describing: self.frame))")
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        Self.logger.debug("CodeEditorView setupTextView: Final container size = \(String(describing: self.textContainer?.containerSize ?? NSSize(width: 0, height: 0)))")
        #else
        Self.logger.debug("CodeEditorView setupTextView: Final container size = \(String(describing: self.textContainer.size))")
        #endif
        
        // Initial syntax highlighting
        applySyntaxHighlighting()
        
        // Set up completion providers
        setupCompletionProviders()
        
        // Set up code folding engine
        setupCodeFoldingEngine()
        
        // LSP integration can be set up here when needed
        // setupLSPIntegration()
        
        // Set up TextKit2 rendering optimization
        setupTextKit2Optimization()
        
        // Register with memory monitor
        registerWithMemoryMonitor()
        
        // Apply default configuration
        applyConfiguration()
    }
    
    internal func setupDefaultTheme() {
        // Set default theme colors
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        backgroundColor = PlatformColors.textBackgroundColor
        textColor = PlatformColors.label
        insertionPointColor = PlatformColors.controlAccentColor
        selectedTextAttributes = [
            .backgroundColor: PlatformColors.selectedTextBackgroundColor,
            .foregroundColor: PlatformColors.selectedTextColor
        ]
        #else
        backgroundColor = PlatformColors.systemBackground
        textColor = PlatformColors.label
        tintColor = PlatformColors.tintColor
        #endif
        
        // Apply font settings
        let font = PlatformFonts.monospacedSystemFont(ofSize: configuration.display.fontSize, weight: .regular)
        self.font = font
    }
    
    internal func setupCompletionProviders() {
        // Set up language-specific completion providers
        // Providers are registered on-demand when languages are selected
        // The completion manager will handle provider registration internally
    }
    
    internal func setupCodeFoldingEngine() {
        // Connect the code folding engine
        codeFoldingEngine.attach(to: self)
    }
    
    internal func updateCompletionTriggerCharacters() {
        // Update trigger characters based on language
        switch language {
        case .swift, .rust, .go, .c, .cpp, .java:
            completionTriggerCharacters = [".", "(", "[", "<", " ", ":"]

        case .python, .ruby:
            completionTriggerCharacters = [".", "(", "[", " ", ":"]

        case .javascript, .typescript:
            completionTriggerCharacters = [".", "(", "[", "{", " ", ":"]

        case .html:
            completionTriggerCharacters = ["<", " ", "\"", "'", "/"]

        case .css:
            completionTriggerCharacters = [":", " ", "-", "("]

        case .json, .yaml:
            completionTriggerCharacters = ["\"", ":", " ", "[", "{"]

        case .sql:
            completionTriggerCharacters = [" ", ".", "("]

        default:
            completionTriggerCharacters = [".", "(", "[", "<", " "]
        }
    }
}
