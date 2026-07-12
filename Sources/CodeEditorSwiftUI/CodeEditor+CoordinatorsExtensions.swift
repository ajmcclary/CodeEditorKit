import CodeEditorCommon
import CodeEditorCompletion
import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorLanguages
import CodeEditorPlatform
import CodeEditorTheming
import CodeEditorView
import Foundation
import SwiftUI
#if canImport(AppKit)
@preconcurrency import AppKit
#elseif canImport(UIKit)
@preconcurrency import UIKit
#endif

// MARK: - Base Coordinator

/// Base coordinator with shared logic for SwiftUI CodeEditor wrappers
@MainActor
open class CodeEditorBaseCoordinator: NSObject, ObservableObject, CodeEditorCoordinating {
    // MARK: - Shared Properties

    /// The current text content
    @Published var currentText: String = ""

    /// The current language
    @Published var currentLanguage: Language = .plainText

    /// The current configuration
    @Published var currentConfiguration: EditorConfiguration = .default

    /// Selection callback shared across platforms.
    var onSelectionChange: ((NSRange) -> Void)?

    /// Owns editor-to-host text propagation and debounce state.
    let bindingSynchronizer = EditorBindingSynchronizer()

    /// Owns dirty, selection, and cursor-state synchronization.
    let interactionSynchronizer = EditorInteractionSynchronizer()

    var interactionStateBinding: Binding<EditorInteractionState>? {
        get { interactionSynchronizer.interactionState }
        set { interactionSynchronizer.interactionState = newValue }
    }

    /// Optional host-supplied controller. Held weakly to avoid extending
    /// the lifetime of an external object beyond what the host intends.
    /// Set by the SwiftUI representable on `make…`/`update…` and cleared
    /// on `dismantle…`.
    weak var editorController: EditorController?

    /// Host-provided `EditorState` plucked from the SwiftUI environment.
    ///
    /// `EditorState`'s doc contract is that the editor target writes
    /// `selection`, `language`, and `lineCount`; the host writes the rest.
    /// Held weakly so the env's process-wide sentinel doesn't extend its
    /// lifetime through this view (and so a host's `@State`-owned
    /// `EditorState` deallocates cleanly when the host drops it). Writes
    /// to the shared sentinel are inert — no chrome view reads it unless
    /// a host explicitly wires one via `.environment(\.editorState, _:)`.
    var hostEditorState: EditorState? {
        get { interactionSynchronizer.hostState }
        set { interactionSynchronizer.hostState = newValue }
    }

    /// Additional callback for extended selection functionality.
    var onSelectionChangeCallback: ((NSRange) -> Void)?

    /// Track if focus has been requested to avoid duplicate requests
    private var hasFocusBeenRequested = false

    private let platformAdapter = CodeEditorPlatformAdapterFactory.make()

    /// Adapter that wraps the host's `.codeCompletion { … }` modifier
    /// closure as a `CompletionProvider`. Lazy: allocated on the first
    /// non-nil closure, kept alive for the coordinator's lifetime so
    /// re-renders only swap the closure slot. Manager-side identity is
    /// stable.
    var modifierProviderAdapter: SwiftUIClosureCompletionProvider?

    /// Request focus for the text view
    func requestFocusIfNeeded(for view: PlatformView, shouldBecomeFirstResponder: Bool) {
        guard shouldBecomeFirstResponder, !hasFocusBeenRequested else { return }

        hasFocusBeenRequested = true
        platformAdapter.requestFocus(for: view)
    }

    /// Reset focus tracking when environment changes
    func resetFocusTracking() {
        hasFocusBeenRequested = false
    }

    // MARK: - Update Management

    /// Tracks the last update to prevent unnecessary updates
    private struct UpdateState {
        let text: String
        let language: Language
        let configuration: EditorConfiguration
        let runtime: EditorRuntimeSnapshot
    }

    private var lastUpdateState: UpdateState?

    /// Check if an update should proceed based on changed state
    func shouldUpdate(
        text: String,
        language: Language,
        configuration: EditorConfiguration,
        runtimeDependencies: EditorRuntimeDependencies
    ) -> Bool {
        let newState = UpdateState(
            text: text,
            language: language,
            configuration: configuration,
            runtime: EditorRuntimeSnapshot(runtimeDependencies)
        )

        defer { lastUpdateState = newState }

        guard let lastState = lastUpdateState else { return true }

        return lastState.text != newState.text ||
               lastState.language != newState.language ||
               lastState.configuration != newState.configuration ||
               lastState.runtime != newState.runtime
    }

    /// Update the coordinator's state
    func updateState(text: String, language: Language, configuration: EditorConfiguration) {
        if currentText != text {
            currentText = text
        }

        if currentLanguage != language {
            currentLanguage = language
        }

        if currentConfiguration != configuration {
            currentConfiguration = configuration
        }
        bindingSynchronizer.installHostText(text)

        interactionSynchronizer.receiveText(text, language: language)
    }

    /// Reset the dirty baseline to the view's current content. Called by
    /// `EditorController.markClean()` via `CodeEditorView.applyMarkClean()`.
    package func markClean(view: CodeEditorView) {
        let currentText = platformAdapter.text(from: view)
        interactionSynchronizer.markClean(currentText: currentText)
    }

    // MARK: - Text Change Handling

    /// Handle text changes from the editor
    func handleTextChange(_ newText: String) {
        // Prevent feedback loops
        guard newText != currentText else { return }

        currentText = newText
        bindingSynchronizer.receiveEditorText(newText)
    }

    /// Handle selection changes from the editor
    func handleSelectionChange(_ range: NSRange) {
        onSelectionChange?(range)
        onSelectionChangeCallback?(range)

        interactionSynchronizer.receiveSelection(range, text: currentText)
    }

    func updateInteractionStateBinding(_ binding: Binding<EditorInteractionState>) {
        interactionSynchronizer.interactionState = binding
    }

    func applyInteractionState(to textView: CodeEditorView) {
        interactionSynchronizer.applyInteractionState(to: textView)
    }

    // MARK: - Notification Management

    private var notificationObservers: [NSObjectProtocol] = []

    /// Set up text change notifications for the given text view
    func setupTextChangeObservers(for textView: CodeEditorView) {
        removeNotificationObservers()

        notificationObservers = platformAdapter.textChangeObservers(for: textView, coordinator: self)
    }

    /// Remove all notification observers
    func removeNotificationObservers() {
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }

    /// Cleanup method to be called when the coordinator is no longer needed
    /// This should be called before the coordinator is deallocated
    func cleanup() {
        // Notification observers are removed automatically in deinit
    }

    deinit {
        // Cannot access MainActor isolated properties in deinit with Swift 6
        // cleanup() should be called explicitly when view disappears
        // NotificationCenter automatically removes observers when object is deallocated
    }

    // MARK: - Common Update Logic

    /// Apply common updates to a text view
    func updateTextView(
        _ textView: CodeEditorView,
        text: String,
        language: Language,
        configuration: EditorConfiguration
    ) {
        // Update text if changed
        platformAdapter.setText(text, in: textView, preserveSelection: false)

        // Update language if changed
        if textView.language != language {
            textView.language = language
        }

        // Apply configuration
        do {
            try textView.apply(configuration: configuration)
        } catch {
            CrossPlatformLogger.logger().error("Rejected SwiftUI editor configuration: \(error)")
        }
    }

    // MARK: - Container Setup and Update

    /// Set up a container view with initial values
    func setupContainer(
        _ container: CodeEditorContainerView,
        text: String,
        language: Language,
        theme: Theme,
        configuration: EditorConfiguration,
        runtimeDependencies: EditorRuntimeDependencies,
        onTextChange: ((String) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil,
        swiftUICompletionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])? = nil
    ) {
        CodeEditorRenderingDiagnostics.logContainer(
            "coordinator.setup.begin",
            container: container,
            theme: theme,
            note: "language=\(language.rawValue) incomingTextLength=\(text.count)"
        )
        // Store callbacks
        bindingSynchronizer.onEditorText = onTextChange
        self.onSelectionChange = onSelectionChange

        // Get the text view
        let textView = container.textView

        textView.apply(runtimeDependencies: runtimeDependencies)

        // Set initial text
        platformAdapter.setText(text, in: textView, preserveSelection: false)
        CodeEditorRenderingDiagnostics.log(
            "coordinator.setup.afterSetText",
            textView: textView,
            theme: theme,
            note: "incomingTextLength=\(text.count)"
        )

        // Seed the dirty tracker against the initial content. Coordinator
        // owns the tracker; the view holds a weak back-pointer so
        // `EditorController.markClean()` can route through.
        interactionSynchronizer.installBaseline(text)
        textView.coordinator = self

        // Set language
        textView.language = language

        // Editor background + foreground default to system-adaptive colors
        // until `apply(theme:)` lands, which owns the colour state from
        // then on. Re-asserting system colours after a theme is applied
        // would clobber `editor.foreground` and (under TK2) leave glyphs
        // transparent on any later update.
        if textView.appliedTheme == nil {
            platformAdapter.applySystemEditorColors(to: textView)
            CodeEditorRenderingDiagnostics.log(
                "coordinator.setup.afterSystemColors",
                textView: textView,
                theme: theme,
                note: "appliedTheme=nil"
            )
        }

        // Apply initial configuration
        container.configuration = configuration
        CodeEditorRenderingDiagnostics.logContainer(
            "coordinator.setup.afterConfiguration",
            container: container,
            theme: theme,
            note: "wrapLines=\(configuration.layout.wrapLines) editable=\(configuration.behavior.isEditable)"
        )

        // Set up observers
        setupTextChangeObservers(for: textView)

        // Update internal state
        updateState(text: text, language: language, configuration: configuration)

        // Mirror the effective hardware-acceleration state once at mount.
        // Sticky — live config changes do not toggle this field. UIKit
        // views are always layer-backed by definition; AppKit reflects
        // the knob.
        #if canImport(AppKit)
        let hardwareAccelerationActive = configuration.performance.useHardwareAcceleration
        #else
        let hardwareAccelerationActive = true
        #endif
        interactionSynchronizer.setHardwareAccelerationActive(
            hardwareAccelerationActive
        )

        // Reconcile the .codeCompletion modifier closure against the
        // text view's completion manager. First-call path; subsequent
        // updates flow through `updateContainer`.
        syncModifierProvider(on: textView.completionManager, closure: swiftUICompletionProvider)

        // Force initial layout
        platformAdapter.invalidateLayoutAndDisplay(for: textView)
        CodeEditorRenderingDiagnostics.logContainer(
            "coordinator.setup.afterInvalidate",
            container: container,
            theme: theme
        )
    }

    /// Update a container view with new values
    func updateContainer(
        _ container: CodeEditorContainerView,
        text: String,
        language: Language,
        theme: Theme,
        configuration: EditorConfiguration,
        runtimeDependencies: EditorRuntimeDependencies,
        swiftUICompletionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])? = nil
    ) {
        let needsUpdate = shouldUpdate(
            text: text,
            language: language,
            configuration: configuration,
            runtimeDependencies: runtimeDependencies
        )
        CodeEditorRenderingDiagnostics.logContainer(
            "coordinator.update.begin",
            container: container,
            theme: theme,
            note: "needsUpdate=\(needsUpdate) language=\(language.rawValue) incomingTextLength=\(text.count)"
        )

        // Reconcile the modifier closure *before* the shouldUpdate guard:
        // a host may swap the closure without changing text/language/config,
        // and we still need the new closure to land in the adapter slot.
        syncModifierProvider(on: container.textView.completionManager, closure: swiftUICompletionProvider)

        // Check if we need to update
        guard needsUpdate else {
            CodeEditorRenderingDiagnostics.logContainer(
                "coordinator.update.skipped",
                container: container,
                theme: theme
            )
            return
        }

        let textView = container.textView
        textView.apply(runtimeDependencies: runtimeDependencies)

        // Detect host-driven binding swap: when the binding's text differs
        // from the view's current storage, the host has installed new
        // content (e.g., tab switch, file load). User edits write to
        // storage via the delegate before they propagate back here, so
        // storage already matches `text` on the edit re-render path.
        let storageText = platformAdapter.text(from: textView)
        let isHostBindingSwap = (storageText != text)

        // Update text if changed
        platformAdapter.setText(text, in: textView, preserveSelection: true)
        CodeEditorRenderingDiagnostics.log(
            "coordinator.update.afterSetText",
            textView: textView,
            theme: theme,
            note: "hostBindingSwap=\(isHostBindingSwap) previousTextLength=\(storageText.count) incomingTextLength=\(text.count)"
        )

        if isHostBindingSwap {
            interactionSynchronizer.installBaseline(text)
            // `setText` replaces the text storage and drops per-range
            // attributes; the syntax pass re-applies token colours
            // asynchronously, but untokenized characters need the theme
            // foreground stamped synchronously or TK2 renders them with
            // no glyph colour at all.
            textView.stampThemeForeground()
            CodeEditorRenderingDiagnostics.log(
                "coordinator.update.afterHostSwapStamp",
                textView: textView,
                theme: theme
            )
        }

        // Update language if changed
        if textView.language != language {
            textView.language = language
        }

        // System colours only matter until `apply(theme:)` lands; once a
        // theme is applied it owns `textColor`/`backgroundColor`. Skipping
        // the re-assert here is what allows the theme's foreground to
        // survive between updateContainer cycles.
        if textView.appliedTheme == nil {
            platformAdapter.applySystemEditorColors(to: textView)
            CodeEditorRenderingDiagnostics.log(
                "coordinator.update.afterSystemColors",
                textView: textView,
                theme: theme,
                note: "appliedTheme=nil"
            )
        }

        // Update configuration if changed
        if container.configuration != configuration {
            container.configuration = configuration
            CodeEditorRenderingDiagnostics.logContainer(
                "coordinator.update.afterConfiguration",
                container: container,
                theme: theme,
                note: "wrapLines=\(configuration.layout.wrapLines) editable=\(configuration.behavior.isEditable)"
            )
        }

        // Update internal state
        updateState(text: text, language: language, configuration: configuration)
        CodeEditorRenderingDiagnostics.logContainer(
            "coordinator.update.end",
            container: container,
            theme: theme
        )
    }
}

// MARK: - Platform-Specific Extensions

#if canImport(AppKit)

extension CodeEditorBaseCoordinator {
    /// Handle minimap setup for macOS
    func setupMinimap(in _: NSView, with _: CodeEditorView) {
        // Implementation for macOS minimap setup
        // This can be implemented when minimap support is added to the base coordinator
    }
}

#elseif canImport(UIKit)

extension CodeEditorBaseCoordinator {
    /// Handle tap gesture for iOS
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        if let textView = gesture.view as? CodeEditorView,
           currentConfiguration.behavior.isEditable {
            _ = textView.becomeFirstResponder()
        }
    }

    /// Handle done button tap in iOS toolbar
    @objc func doneButtonTapped() {
        // Find the text view and resign first responder
        // This would need to be implemented based on the specific view hierarchy
    }
}

#endif

// MARK: - Platform-Specific Coordinators

#if canImport(AppKit)

/// macOS-specific coordinator for CodeEditor
@MainActor
final class CodeEditorCoordinator: CodeEditorBaseCoordinator {
    init(
        text: Binding<String>,
        onTextChange: ((String) -> Void)?,
        onSelectionChange: ((NSRange) -> Void)?,
        interactionState: Binding<EditorInteractionState>? = nil
    ) {
        super.init()
        bindingSynchronizer.bind(text)
        bindingSynchronizer.onEditorText = onTextChange
        self.interactionStateBinding = interactionState
        self.onSelectionChange = onSelectionChange
        self.onSelectionChangeCallback = onSelectionChange
    }
}

#elseif canImport(UIKit)

/// iOS-specific coordinator for CodeEditor.
///
/// Conforms to `TextViewDelegateParticipant` and registers at
/// `.behavior` via `setupTextViewDelegate(_:)`. Receives
/// `textViewDidChangeText` and `textViewDidChangeSelection` from the
/// multiplexer; mirrors them into the SwiftUI text binding and
/// selection callback.
///
/// The scroll-forwarding methods (`scrollViewDidScroll` etc.) that
/// previously walked superviews via `findContainer(for:)` are gone —
/// the container is itself a multiplexer participant after the iOS
/// container migration, so it receives scroll callbacks directly from
/// the multiplexer and the coordinator no longer needs to forward.
@MainActor
final class CodeEditorCoordinator: CodeEditorBaseCoordinator {
    init(
        text: Binding<String>,
        onTextChange: ((String) -> Void)?,
        onSelectionChange: ((NSRange) -> Void)?,
        interactionState: Binding<EditorInteractionState>? = nil
    ) {
        super.init()
        bindingSynchronizer.bind(text)
        bindingSynchronizer.onEditorText = onTextChange
        self.interactionStateBinding = interactionState
        self.onSelectionChange = onSelectionChange
        self.onSelectionChangeCallback = onSelectionChange
    }

    func setupTextViewDelegate(_ textView: CodeEditorView) {
        textView.addDelegateParticipant(self, phase: .behavior)
    }
}

extension CodeEditorCoordinator: TextViewDelegateParticipant {
    func textViewDidChangeText(_ textView: CodeEditorView) {
        handleTextChange(textView.text ?? "")
    }

    func textViewDidChangeSelection(_ textView: CodeEditorView) {
        handleSelectionChange(textView.selectedRange)
    }
}

#endif

// MARK: - Modifier Provider Reconciliation

extension CodeEditorBaseCoordinator {
    /// Reconciles the host's `.codeCompletion { … }` closure with the
    /// manager's provider registry. Idempotent across renders:
    /// - `(closure, nil)`     → allocate adapter, set slot, register.
    /// - `(closure, adapter)` → swap slot (manager untouched).
    /// - `(nil, adapter)`     → unregister, drop adapter.
    /// - `(nil, nil)`         → no-op.
    func syncModifierProvider(
        on manager: CompletionManager,
        closure: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?
    ) {
        switch (closure, modifierProviderAdapter) {
        case let (.some(new), .some(adapter)):
            adapter.closure = new

        case let (.some(new), .none):
            let adapter = SwiftUIClosureCompletionProvider()
            adapter.closure = new
            modifierProviderAdapter = adapter
            manager.registerProvider(adapter)

        case (.none, .some):
            manager.unregisterProvider(withId: "swiftui-modifier")
            modifierProviderAdapter = nil

        case (.none, .none):
            break
        }
    }
}
