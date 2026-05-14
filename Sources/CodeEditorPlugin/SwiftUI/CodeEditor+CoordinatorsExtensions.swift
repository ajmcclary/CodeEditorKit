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
open class CodeEditorBaseCoordinator: NSObject, ObservableObject {
    // MARK: - Shared Properties

    /// The current text content
    @Published var currentText: String = ""

    /// The current language
    @Published var currentLanguage: Language = .plainText

    /// The current configuration
    @Published var currentConfiguration: EditorConfiguration = .default

    /// Callbacks (common across platforms)
    var onTextChange: ((String) -> Void)?
    var onSelectionChange: ((NSRange) -> Void)?

    /// Text binding for SwiftUI integration
    var textBinding: Binding<String>?

    /// Optional interaction-state binding for cursor persistence/restoration.
    var interactionStateBinding: Binding<EditorInteractionState>?

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
    weak var hostEditorState: EditorState?

    /// Additional callbacks for extended functionality
    var onTextChangeCallback: ((String) -> Void)?
    var onSelectionChangeCallback: ((NSRange) -> Void)?

    /// Debounce task for text changes
    var textUpdateTask: Task<Void, Never>?

    /// Debounce interval for text changes
    @available(macOS 13.0, iOS 16.0, *)
    var textDebounceInterval: Duration = .milliseconds(100)

    /// Legacy debounce interval for older OS versions
    var legacyTextDebounceInterval: TimeInterval = 0.1

    /// Track if focus has been requested to avoid duplicate requests
    private var hasFocusBeenRequested = false

    private let platformAdapter = CodeEditorPlatformAdapterFactory.make()

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
    }

    private var lastUpdateState: UpdateState?

    /// Check if an update should proceed based on changed state
    func shouldUpdate(text: String, language: Language, configuration: EditorConfiguration) -> Bool {
        let newState = UpdateState(text: text, language: language, configuration: configuration)

        defer { lastUpdateState = newState }

        guard let lastState = lastUpdateState else { return true }

        return lastState.text != newState.text ||
               lastState.language != newState.language ||
               lastState.configuration != newState.configuration
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

        // Mirror into the host's shared `EditorState`, if any. Status bar
        // and other chrome read these fields out of the SwiftUI environment.
        if let hostEditorState {
            if hostEditorState.language != language {
                hostEditorState.language = language
            }
            let lineCount = EditorStateBridge.lineCount(of: text)
            if hostEditorState.lineCount != lineCount {
                hostEditorState.lineCount = lineCount
            }
        }
    }

    // MARK: - Text Change Handling

    /// Handle text changes from the editor
    func handleTextChange(_ newText: String) {
        // Prevent feedback loops
        guard newText != currentText else { return }

        currentText = newText

        // Cancel any existing debounce task and wait for it
        let taskToCancel = textUpdateTask
        textUpdateTask = nil

        // Immediate update for internal state
        onTextChange?(newText)

        // Create new debounced update task
        textUpdateTask = Task { [weak self] in
            // First, await the cancellation of the previous task if it exists
            if let taskToCancel {
                taskToCancel.cancel()
                _ = await taskToCancel.value
            }

            do {
                guard let self else { return }
                if #available(macOS 13.0, iOS 16.0, *) {
                    try await Task.sleep(for: self.textDebounceInterval)
                } else {
                    try await Task.sleep(for: .seconds(self.legacyTextDebounceInterval))
                }

                await MainActor.run { [weak self] in
                    guard let self else { return }

                    // Update SwiftUI binding if available
                    if let textBinding = self.textBinding, textBinding.wrappedValue != newText {
                        textBinding.wrappedValue = newText
                    }

                    // Call the debounced callback
                    self.onTextChangeCallback?(newText)
                }
            } catch is CancellationError {
                // Task was cancelled, which is expected behavior
            } catch {
                // Unexpected error - still continue
            }
        }
    }

    /// Handle selection changes from the editor
    func handleSelectionChange(_ range: NSRange) {
        onSelectionChange?(range)
        onSelectionChangeCallback?(range)

        // Derive only when someone consumes it — deriveSelection walks the
        // UTF-16 view from the start, so we skip the work for hosts with
        // neither chrome nor interaction-state restore.
        guard hostEditorState != nil || interactionStateBinding != nil else { return }

        let selection = EditorStateBridge.deriveSelection(from: range, in: currentText)

        if let hostEditorState, hostEditorState.selection != selection {
            hostEditorState.selection = selection
        }

        updateInteractionStateCursor(from: selection)
    }

    func updateInteractionStateBinding(_ binding: Binding<EditorInteractionState>) {
        interactionStateBinding = binding
    }

    func applyInteractionState(to textView: CodeEditorView) {
        guard let cursor = interactionStateBinding?.wrappedValue.cursorPositions?.first else {
            return
        }

        let editorText = text(from: textView)
        let offset = Self.utf16Offset(for: cursor, in: editorText)
        let targetRange = NSRange(location: offset, length: 0)
        guard textView.selectedRange != targetRange else { return }
        textView.setSelectedRangeWithoutScrolling(targetRange)
    }

    private func updateInteractionStateCursor(from selection: SelectionState) {
        guard var state = interactionStateBinding?.wrappedValue else { return }
        let cursor = EditorCursorPosition(line: selection.line, column: selection.column)
        guard state.cursorPositions != [cursor] else { return }
        state.cursorPositions = [cursor]
        interactionStateBinding?.wrappedValue = state
    }

    private func text(from textView: CodeEditorView) -> String {
        platformAdapter.text(from: textView)
    }

    private static func utf16Offset(for cursor: EditorCursorPosition, in text: String) -> Int {
        let targetLine = max(1, cursor.line)
        let targetColumn = max(1, cursor.column)
        var line = 1
        var column = 1
        var offset = 0

        for character in text {
            if line == targetLine && column == targetColumn {
                return offset
            }

            if character == "\n" {
                if line == targetLine {
                    return offset
                }
                line += 1
                column = 1
            } else {
                column += 1
            }

            offset += String(character).utf16.count
        }

        return TextRangeUtilities.utf16Length(of: text)
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
            try configuration.apply(to: textView)
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
        theme _: Theme,
        configuration: EditorConfiguration,
        runtimeDependencies: EditorRuntimeDependencies,
        onTextChange: ((String) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil
    ) {
        // Store callbacks
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange

        // Get the text view
        let textView = container.textView

        textView.apply(runtimeDependencies: runtimeDependencies)

        // Set initial text
        platformAdapter.setText(text, in: textView, preserveSelection: false)

        // Set language
        textView.language = language

        // Editor background + foreground intentionally use system-adaptive
        // colors so they follow the SwiftUI .preferredColorScheme tied to
        // the active theme's appearance. This keeps the canvas legible
        // when switching between dark and light theme variants without
        // baking specific theme tokens (some are near-black even for
        // "light" theme families).
        platformAdapter.applySystemEditorColors(to: textView)

        // Apply initial configuration
        container.configuration = configuration

        // Set up observers
        setupTextChangeObservers(for: textView)

        // Update internal state
        updateState(text: text, language: language, configuration: configuration)

        // Force initial layout
        platformAdapter.invalidateLayoutAndDisplay(for: textView)
    }

    /// Update a container view with new values
    func updateContainer(
        _ container: CodeEditorContainerView,
        text: String,
        language: Language,
        theme _: Theme,
        configuration: EditorConfiguration,
        runtimeDependencies: EditorRuntimeDependencies
    ) {
        // Check if we need to update
        guard shouldUpdate(text: text, language: language, configuration: configuration) else {
            return
        }

        let textView = container.textView
        textView.apply(runtimeDependencies: runtimeDependencies)

        // Update text if changed
        platformAdapter.setText(text, in: textView, preserveSelection: true)

        // Update language if changed
        if textView.language != language {
            textView.language = language
        }

        // Re-assert system-adaptive editor colors so the canvas tracks
        // the theme appearance via .preferredColorScheme on every update.
        platformAdapter.applySystemEditorColors(to: textView)

        // Update configuration if changed
        if container.configuration != configuration {
            container.configuration = configuration
        }

        // Update internal state
        updateState(text: text, language: language, configuration: configuration)
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
        self.textBinding = text
        self.interactionStateBinding = interactionState
        self.onTextChange = onTextChange
        self.onTextChangeCallback = onTextChange
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
        self.textBinding = text
        self.interactionStateBinding = interactionState
        self.onTextChange = onTextChange
        self.onTextChangeCallback = onTextChange
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
