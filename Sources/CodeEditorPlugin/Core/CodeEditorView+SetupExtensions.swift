import CodeEditorDiagnostics
import CodeEditorPlatform
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
        // First-time wakeup: language hasn't gone through didSet for its
        // initial value (`.plainText`). Register the built-in keyword
        // provider explicitly so a fresh editor gets keyword completions
        // for free. Subsequent language changes route through
        // `language { didSet }` below.
        completionManager.ensureBuiltInProvider(for: language)
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
        // Read text through the TK2-safe accessor; reading `self.textStorage`
        // directly triggers Apple's TK1 compatibility shim and clears
        // `textLayoutManager`. See `CodeEditorViewTextKit2InitTests` for the
        // load-bearing invariant.
        guard let textStorage = textContentStorage?.textStorage else {
            lineGeometryStore.reset()
            return
        }
        lineGeometryStore.build(from: textStorage)
    }

    internal func updateCompletionTriggerCharacters() {
        let syntaxService = featureDependencies.syntaxHighlightingService
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
        if let lspSemanticTokenProvider {
            rangeBasedHighlightingController?.unregisterSupplementalProvider(lspSemanticTokenProvider)
            lspSemanticTokenProvider.onTokensUpdated = nil
        }

        let coordinator = LSPContentCoordinator(
            textView: self,
            lspManager: lspManager,
            filePath: filePath,
            languageId: languageId
        )
        lspContentCoordinator = coordinator

        // Create semantic token provider and wire post-batch refresh.
        let stp = LSPSemanticTokenProvider(
            lspManager: lspManager,
            filePath: filePath
        )
        lspSemanticTokenProvider = stp
        stp.onTokensUpdated = { [weak self, weak stp] indices in
            guard let self, let stp else { return }
            self.rangeBasedHighlightingController?.invalidateSupplementalProvider(stp, indices: indices)
        }
        coordinator.onBatchFlushed = { [weak self] in
            guard let self, let stp = self.lspSemanticTokenProvider else { return }
            stp.refreshAfterBatch(textView: self)
        }

        registerSemanticTokenProviderIfAvailable()
    }
    #endif

    /// Bridge between `EditorController.markClean()` and the coordinator
    /// that owns the dirty tracker. No-op when the view is not mounted
    /// (no coordinator attached).
    internal func applyMarkClean() {
        coordinator?.markClean(view: self)
    }
}
