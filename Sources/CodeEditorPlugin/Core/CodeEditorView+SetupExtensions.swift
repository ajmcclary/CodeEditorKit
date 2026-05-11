import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Initialization & Setup

extension CodeEditorView {
    // MARK: - Setup Methods

    internal func setupTextView() {
        // Use TextKitSetupHelper for centralized setup
        let setupResult = TextKitSetupHelper.setupTextKit(for: self)

        #if DEBUG
        Self.logger.debug("Setting up CodeEditorView with TextKit2")
        setupResult.notes.forEach { note in
            Self.logger.debug("TextKit Setup: \(note)")
        }
        #endif

        // Setup theme
        setupDefaultTheme()

        // Initial syntax highlighting
        applySyntaxHighlighting()

        // Set up completion providers
        setupCompletionProviders()

        // Set up code folding engine
        setupCodeFoldingEngine()

        // Set up line geometry store edit handler
        setupLineGeometryStore()

        // LSP integration can be set up here when needed
        // setupLSPIntegration(filePath:languageId:)

        // Set up TextKit2 rendering optimization
        setupTextKit2Optimization()

        // Register with memory monitor
        registerWithMemoryMonitor()

        // Apply default configuration
        applyConfiguration()

        // Set up accessibility support
        setupAccessibility()
    }

    internal func setupDefaultTheme() {
        // Set default theme colors
        #if canImport(AppKit)
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

    internal func setupLineGeometryStore() {
        rebuildLineGeometryStoreFromCurrentTextStorage()

        // Create and register the edit handler that keeps the geometry
        // store in sync with text storage changes.
        lineGeometryEditHandler = LineGeometryEditHandler(
            geometryStore: lineGeometryStore,
            textView: self
        )
    }

    internal func rebuildLineGeometryStoreFromCurrentTextStorage() {
        #if canImport(AppKit)
        guard let textStorage else {
            lineGeometryStore.reset()
            return
        }
        lineGeometryStore.build(from: textStorage)
        #else
        lineGeometryStore.build(from: textStorage)
        #endif
    }

    internal func updateCompletionTriggerCharacters() {
        let syntaxService = businessLogicServices.syntaxHighlightingService
        completionTriggerCharacters = syntaxService.getCompletionTriggerCharacters(for: language)
    }

    // MARK: - LSP Integration

    /// Creates an `LSPContentCoordinator` that bridges this editor's
    /// edit-event stream to LSP `textDocument/didChange` notifications.
    ///
    /// Call this after opening a document in an LSP server (via
    /// `lspManager.openDocument`). The coordinator begins batching edits
    /// immediately. Call `lspContentCoordinator?.detach()` to stop.
    ///
    /// - Parameters:
    ///   - filePath: Absolute path to the file being edited.
    ///   - languageId: LSP language identifier (e.g. `"swift"`).
    #if canImport(AppKit)
    internal func setupLSPIntegration(filePath: String, languageId: String) {
        // Detach any previous coordinator first.
        lspContentCoordinator?.detach()

        lspContentCoordinator = LSPContentCoordinator(
            textView: self,
            lspManager: lspManager,
            filePath: filePath,
            languageId: languageId
        )
    }
    #endif
}
