import Foundation
import SwiftUI
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
    
    /// Callbacks
    var onTextChange: ((String) -> Void)?
    var onSelectionChange: ((NSRange) -> Void)?
    
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
    }
    
    // MARK: - Text Change Handling
    
    /// Handle text changes from the editor
    func handleTextChange(_ newText: String) {
        // Prevent feedback loops
        guard newText != currentText else { return }
        
        currentText = newText
        onTextChange?(newText)
    }
    
    /// Handle selection changes from the editor
    func handleSelectionChange(_ range: NSRange) {
        onSelectionChange?(range)
    }
    
    // MARK: - Notification Management
    
    private var notificationObservers: [NSObjectProtocol] = []
    
    /// Set up text change notifications for the given text view
    func setupTextChangeObservers(for textView: CodeEditorView) {
        removeNotificationObservers()
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let textChangeObserver = NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self, weak textView] _ in
            MainActor.assumeIsolated {
                guard let self, let textView else { return }
                self.handleTextChange(textView.string)
            }
        }
        
        let selectionChangeObserver = NotificationCenter.default.addObserver(
            forName: NSTextView.didChangeSelectionNotification,
            object: textView,
            queue: .main
        ) { [weak self, weak textView] _ in
            MainActor.assumeIsolated {
                guard let self, let textView else { return }
                self.handleSelectionChange(textView.selectedRange())
            }
        }
        #else
        let textChangeObserver = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self, weak textView] _ in
            MainActor.assumeIsolated {
                guard let self, let textView else { return }
                self.handleTextChange(textView.text ?? "")
            }
        }
        
        let selectionChangeObserver = NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification, // iOS doesn't have separate selection change notification
            object: textView,
            queue: .main
        ) { [weak self, weak textView] _ in
            MainActor.assumeIsolated {
                guard let self, let textView else { return }
                self.handleSelectionChange(textView.selectedRange)
            }
        }
        #endif
        
        notificationObservers = [textChangeObserver, selectionChangeObserver]
    }
    
    /// Remove all notification observers
    func removeNotificationObservers() {
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }
    
    deinit {
        // Must be done synchronously in deinit - cannot access MainActor properties
        // The observers are cleaned up when the view disappears
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if textView.string != text {
            textView.string = text
        }
        #else
        if textView.text != text {
            textView.text = text
        }
        #endif
        
        // Update language if changed
        if textView.language != language {
            textView.language = language
        }
        
        // Apply configuration
        configuration.apply(to: textView)
    }
}

// MARK: - Platform-Specific Extensions

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

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
            textView.becomeFirstResponder()
        }
    }
    
    /// Handle done button tap in iOS toolbar
    @objc func doneButtonTapped() {
        // Find the text view and resign first responder
        // This would need to be implemented based on the specific view hierarchy
    }
}

#endif
