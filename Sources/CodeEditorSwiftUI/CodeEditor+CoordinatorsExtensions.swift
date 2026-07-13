import CodeEditorCommon
import CodeEditorCompletion
import CodeEditorConfiguration
import CodeEditorLanguages
import CodeEditorPlatform
import DesignKitThemes
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

    /// Owns `.codeCompletion` provider identity across SwiftUI renders.
    let completionModifierRegistry = CompletionModifierRegistry()

    /// Owns ordered mount/update reconciliation for the represented editor.
    lazy var renderReconciler = EditorRenderReconciler(
        interactionSynchronizer: interactionSynchronizer,
        completionRegistry: completionModifierRegistry
    )

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

    /// Update the coordinator's state
    func updateState(text: String, language: Language, configuration: EditorConfiguration) {
        updatePublishedState(
            text: text,
            language: language,
            configuration: configuration
        )
        interactionSynchronizer.receiveText(text, language: language)
    }

    private func updatePublishedState(
        text: String,
        language: Language,
        configuration: EditorConfiguration
    ) {
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
        bindingSynchronizer.onEditorText = onTextChange
        self.onSelectionChange = onSelectionChange
        let textView = container.textView
        textView.coordinator = self
        let state = EditorRenderState(
            text: text,
            language: language,
            configuration: configuration,
            theme: theme,
            runtimeDependencies: runtimeDependencies
        )
        renderReconciler.mount(
            state,
            in: container,
            completion: swiftUICompletionProvider
        ) { [weak self] text, language, configuration in
            self?.updatePublishedState(
                text: text,
                language: language,
                configuration: configuration
            )
        }
        setupTextChangeObservers(for: textView)
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
        let state = EditorRenderState(
            text: text,
            language: language,
            configuration: configuration,
            theme: theme,
            runtimeDependencies: runtimeDependencies
        )
        renderReconciler.update(
            state,
            in: container,
            completion: swiftUICompletionProvider
        ) { [weak self] text, language, configuration in
            self?.updatePublishedState(
                text: text,
                language: language,
                configuration: configuration
            )
        }
    }
}

// MARK: - Platform-Specific Extensions

#if canImport(UIKit)
extension CodeEditorBaseCoordinator {
    /// Handle tap gesture for iOS
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        if let textView = gesture.view as? CodeEditorView,
           currentConfiguration.behavior.isEditable {
            _ = textView.becomeFirstResponder()
        }
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
