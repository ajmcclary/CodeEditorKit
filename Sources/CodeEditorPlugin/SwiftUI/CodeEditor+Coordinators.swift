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
    
    /// Callbacks (common across platforms)
    var onTextChange: ((String) -> Void)?
    var onSelectionChange: ((NSRange) -> Void)?
    
    /// Text binding for SwiftUI integration
    var textBinding: Binding<String>?
    
    /// Additional callbacks for extended functionality
    var onTextChangeCallback: ((String) -> Void)?
    var onSelectionChangeCallback: ((NSRange) -> Void)?
    
    /// Debounce task for text changes
    var textUpdateTask: Task<Void, Never>?
    
    /// Debounce interval for text changes
    var textDebounceInterval: TimeInterval = 0.1
    
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
        
        // Cancel any existing debounce task
        textUpdateTask?.cancel()
        
        // Immediate update for internal state
        onTextChange?(newText)
        
        // Debounced update for SwiftUI binding and callbacks
        textUpdateTask = Task { [weak self] in
            do {
                guard let self else { return }
                try await Task.sleep(for: .seconds(self.textDebounceInterval))
                
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    
                    // Update SwiftUI binding if available
                    if let textBinding = self.textBinding, textBinding.wrappedValue != newText {
                        textBinding.wrappedValue = newText
                    }
                    
                    // Call the debounced callback
                    self.onTextChangeCallback?(newText)
                }
            } catch {
                // Task was cancelled, which is expected behavior
            }
        }
    }
    
    /// Handle selection changes from the editor
    func handleSelectionChange(_ range: NSRange) {
        onSelectionChange?(range)
        onSelectionChangeCallback?(range)
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
        // Cannot access MainActor isolated properties in deinit with Swift 6
        // removeNotificationObservers() should be called explicitly when view disappears
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
    
    /// Apply theme colors for Mac Catalyst
    #if targetEnvironment(macCatalyst)
    func applyCatalystThemeColors(theme: CodeEditorSwiftUITheme, to textView: CodeEditorView) {
        let effectiveTextColor = CatalystColorHelper.effectiveTextColor(from: theme.textColor)
        Task { @MainActor in
            await CatalystColorHelper.applyTextColor(effectiveTextColor, to: textView)
        }
    }
    #endif
    
    // MARK: - Container Setup and Update
    
    /// Set up a container view with initial values
    func setupContainer(
        _ container: CodeEditorContainerView,
        text: String,
        language: Language,
        theme: CodeEditorSwiftUITheme,
        configuration: EditorConfiguration,
        onTextChange: ((String) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil
    ) {
        // Store callbacks
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
        
        // Get the text view
        let textView = container.textView
        
        // Set initial text
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.string = text
        #else
        textView.text = text
        #endif
        
        // Set language
        textView.language = language
        
        // Apply theme colors
        textView.backgroundColor = PlatformColor.from(theme.backgroundColor)
        
        // Apply text color
        #if targetEnvironment(macCatalyst)
        applyCatalystThemeColors(theme: theme, to: textView)
        #else
        textView.textColor = PlatformColor.from(theme.textColor)
        #endif
        
        // Apply initial configuration
        container.configuration = configuration
        
        // Set up observers
        setupTextChangeObservers(for: textView)
        
        // Update internal state
        updateState(text: text, language: language, configuration: configuration)
        
        // Force initial layout
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.needsLayout = true
        textView.needsDisplay = true
        #else
        textView.setNeedsLayout()
        textView.setNeedsDisplay()
        #endif
    }
    
    /// Update a container view with new values
    func updateContainer(
        _ container: CodeEditorContainerView,
        text: String,
        language: Language,
        theme: CodeEditorSwiftUITheme,
        configuration: EditorConfiguration
    ) {
        // Check if we need to update
        guard shouldUpdate(text: text, language: language, configuration: configuration) else {
            return
        }
        
        let textView = container.textView
        
        // Update text if changed
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if textView.string != text {
            textView.string = text
        }
        #else
        // On iOS, preserve selection when updating text
        let savedSelectedRange = textView.selectedRange
        if textView.text != text {
            textView.text = text
            
            // Restore selection if possible
            if savedSelectedRange.location <= (textView.text ?? "").count {
                textView.setSelectedRangeWithoutScrolling(savedSelectedRange)
            }
        }
        #endif
        
        // Update language if changed
        if textView.language != language {
            textView.language = language
        }
        
        // Apply theme colors
        textView.backgroundColor = PlatformColor.from(theme.backgroundColor)
        
        // Apply text color
        #if targetEnvironment(macCatalyst)
        applyCatalystThemeColors(theme: theme, to: textView)
        #else
        textView.textColor = PlatformColor.from(theme.textColor)
        #endif
        
        // Update configuration if changed
        if container.configuration != configuration {
            container.configuration = configuration
        }
        
        // Update internal state
        updateState(text: text, language: language, configuration: configuration)
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

// MARK: - Platform-Specific Coordinators

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

/// macOS-specific coordinator for CodeEditor
@MainActor
final class CodeEditorCoordinator: CodeEditorBaseCoordinator {
    init(text: Binding<String>, onTextChange: ((String) -> Void)?, onSelectionChange: ((NSRange) -> Void)?) {
        super.init()
        self.textBinding = text
        self.onTextChangeCallback = onTextChange
        self.onSelectionChangeCallback = onSelectionChange
    }
}

#elseif canImport(UIKit)

/// iOS-specific coordinator for CodeEditor
@MainActor
final class CodeEditorCoordinator: CodeEditorBaseCoordinator, UITextViewDelegate {
    init(text: Binding<String>, onTextChange: ((String) -> Void)?, onSelectionChange: ((NSRange) -> Void)?) {
        super.init()
        self.textBinding = text
        self.onTextChangeCallback = onTextChange
        self.onSelectionChangeCallback = onSelectionChange
    }
    
    func setupTextViewDelegate(_ textView: CodeEditorView) {
        textView.delegate = self
    }
    
    // MARK: - UITextViewDelegate
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        handleSelectionChange(textView.selectedRange)
    }
    
    // Forward scroll events to the container
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let container = findContainer(for: scrollView) {
            container.scrollViewDidScroll(scrollView)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if let container = findContainer(for: scrollView) {
            container.scrollViewWillBeginDragging(scrollView)
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if let container = findContainer(for: scrollView) {
            container.scrollViewDidEndDragging(scrollView, willDecelerate: decelerate)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let container = findContainer(for: scrollView) {
            container.scrollViewDidEndDecelerating(scrollView)
        }
    }
    
    private func findContainer(for scrollView: UIScrollView) -> CodeEditorContainerView? {
        var view = scrollView.superview
        while view != nil {
            if let container = view as? CodeEditorContainerView {
                return container
            }
            view = view?.superview
        }
        return nil
    }
}

#endif
