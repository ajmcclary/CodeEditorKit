import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Editor Container View Model

/// View model responsible for coordinating all editor components and their state
/// Provides MVVM architecture for complex editor UI interactions
@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Observable
public final class EditorContainerViewModel {
    // MARK: - Types

    /// Represents the current state of the editor
    public struct EditorState {
        /// Whether the editor is currently in editing mode
        public var isEditing: Bool
        /// Whether there are unsaved changes in the editor
        public var hasUnsavedChanges: Bool
        /// Total number of lines in the document
        public var lineCount: Int
        /// Total number of characters in the document
        public var characterCount: Int
        /// Currently selected text range
        public var selectedRange: NSRange
        /// Currently visible text range in the editor
        public var visibleRange: NSRange
        /// Current scroll position of the editor
        public var scrollPosition: CGPoint

        /// Initializes editor state with default values
        /// - Parameters:
        ///   - isEditing: Whether the editor is currently in editing mode
        ///   - hasUnsavedChanges: Whether there are unsaved changes
        ///   - lineCount: Number of lines in the document
        ///   - characterCount: Number of characters in the document
        ///   - selectedRange: Currently selected text range
        ///   - visibleRange: Currently visible text range
        ///   - scrollPosition: Current scroll position
        public init(
            isEditing: Bool = false,
            hasUnsavedChanges: Bool = false,
            lineCount: Int = 0,
            characterCount: Int = 0,
            selectedRange: NSRange = NSRange(location: 0, length: 0),
            visibleRange: NSRange = NSRange(location: 0, length: 0),
            scrollPosition: CGPoint = .zero
        ) {
            self.isEditing = isEditing
            self.hasUnsavedChanges = hasUnsavedChanges
            self.lineCount = lineCount
            self.characterCount = characterCount
            self.selectedRange = selectedRange
            self.visibleRange = visibleRange
            self.scrollPosition = scrollPosition
        }
    }

    /// Controls visibility of various editor components
    public struct ComponentVisibility {
        /// Whether to show the line number gutter
        public var showGutter: Bool
        /// Whether to show the minimap component
        public var isMinimapVisible: Bool
        /// Whether to show scrollbars
        public var showScrollbar: Bool
        /// Whether to show the status bar
        public var showStatusBar: Bool
        /// Whether to show the code completion popup
        public var showCompletionPopup: Bool

        /// Initializes component visibility settings
        /// - Parameters:
        ///   - showGutter: Whether to show the line number gutter
        ///   - isMinimapVisible: Whether to show the minimap
        ///   - showScrollbar: Whether to show scrollbars
        ///   - showStatusBar: Whether to show the status bar
        ///   - showCompletionPopup: Whether to show the completion popup
        public init(
            showGutter: Bool = true,
            isMinimapVisible: Bool = false,
            showScrollbar: Bool = true,
            showStatusBar: Bool = false,
            showCompletionPopup: Bool = false
        ) {
            self.showGutter = showGutter
            self.isMinimapVisible = isMinimapVisible
            self.showScrollbar = showScrollbar
            self.showStatusBar = showStatusBar
            self.showCompletionPopup = showCompletionPopup
        }
    }

    // MARK: - Published Properties

    /// Current state of the editor
    public var editorState: EditorState
    /// Visibility settings for editor components
    public var componentVisibility: ComponentVisibility
    /// Current editor configuration
    public var configuration: EditorConfiguration
    /// Current layout frames for editor components
    public var layoutFrames: EditorLayoutService.ComponentFrames?

    // Error and status states
    /// Current error message, if any
    public var errorMessage: String?
    /// Whether the editor is currently in a loading state
    public var isLoading: Bool = false
    /// Current status text displayed to the user
    public var statusText: String = "Ready"

    // MARK: - Private Properties

    private let businessLogicServices: BusinessLogicServiceRegistry
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "EditorContainerViewModel")

    // Child view models
    private var gutterViewModel: GutterViewModel?
    private var completionViewModel: CompletionViewModel?
    private var minimapViewModel: MinimapViewModel?

    // Text view reference (weak to avoid retain cycles)
    private weak var textView: CodeEditorView?

    // Update debouncing
    @available(iOS 17.0, macOS 14.0, *)
    @ObservationIgnored private var updateTask: Task<Void, Never>?
    private let updateDebounceInterval: TimeInterval = 0.1

    // MARK: - Initialization

    /// Initializes the editor container view model
    /// - Parameters:
    ///   - businessLogicServices: Registry of business logic services
    ///   - configuration: Initial editor configuration
    public init(
        businessLogicServices: BusinessLogicServiceRegistry,
        configuration: EditorConfiguration = EditorConfiguration()
    ) {
        self.configuration = configuration
        self.businessLogicServices = businessLogicServices
        self.editorState = EditorState()
        self.componentVisibility = ComponentVisibility()

        updateComponentVisibility()
        logger.debug("EditorContainerViewModel initialized")
    }

    // MARK: - Public Interface

    /// Configures the view model with a text view
    public func configure(with textView: CodeEditorView) {
        self.textView = textView

        // Configure business logic services
        businessLogicServices.configureForEditor(
            textView: textView,
            configuration: configuration
        )

        // Initialize child view models
        setupChildViewModels(textView: textView)

        // Initial state update
        updateEditorState()

        logger.debug("EditorContainerViewModel configured with text view")
    }

    /// Updates the editor configuration
    public func updateConfiguration(_ newConfiguration: EditorConfiguration) {
        let oldConfiguration = configuration
        configuration = newConfiguration

        updateComponentVisibility()

        // Invalidate layout if needed
        if businessLogicServices.editorLayoutService.shouldAnimateLayoutChange(
            from: oldConfiguration,
            to: newConfiguration
        ) {
            scheduleLayoutUpdate()
        } else {
            if let layoutFrames {
                updateLayout(containerBounds: layoutFrames.containerFrame, animated: false)
            }
        }

        // Update child view models
        gutterViewModel?.updateConfiguration(newConfiguration)
        completionViewModel?.updateConfiguration(newConfiguration)
        minimapViewModel?.updateConfiguration(newConfiguration)

        logger.debug("Configuration updated")
    }

    /// Updates layout frames for the given container bounds
    public func updateLayout(containerBounds: CGRect, animated: Bool = true) {
        guard let textView else { return }

        let newFrames = businessLogicServices.editorLayoutService.standardLayout(
            containerBounds: containerBounds,
            configuration: configuration,
            textView: textView
        )

        // Check if layout actually changed
        if let currentFrames = layoutFrames,
           !businessLogicServices.editorLayoutService.layoutNeedsUpdate(
               currentFrames: currentFrames,
               newBounds: containerBounds,
               configuration: configuration
           ) {
            return
        }

        layoutFrames = newFrames

        // Update child view models with new frames
        updateChildViewModelFrames(newFrames, animated: animated)

        logger.debug("Layout updated: gutter=\(newFrames.gutterFrame), text=\(newFrames.textViewFrame)")
    }

    /// Called when text content changes
    public func textDidChange(_ newText: String) {
        debouncedUpdate {
            self.updateEditorStateFromText(newText)
            self.gutterViewModel?.textDidChange(newText)
            self.completionViewModel?.textDidChange(newText)
            self.minimapViewModel?.textDidChange(newText)
        }

        editorState.hasUnsavedChanges = true
        statusText = "Modified"
    }

    /// Called when selection changes
    public func selectionDidChange(_ newRange: NSRange) {
        editorState.selectedRange = newRange

        gutterViewModel?.selectionDidChange(newRange)
        completionViewModel?.selectionDidChange(newRange)
        statusText = "Line \(getLineNumber(for: newRange.location)), Column \(getColumnNumber(for: newRange.location))"
    }

    /// Called when scroll position changes
    public func scrollPositionDidChange(_ newPosition: CGPoint) {
        editorState.scrollPosition = newPosition

        gutterViewModel?.scrollPositionDidChange(newPosition)
        minimapViewModel?.scrollPositionDidChange(newPosition)
    }

    /// Handles completion popup visibility
    public func showCompletionPopup(at location: CGPoint) {
        componentVisibility.showCompletionPopup = true
        completionViewModel?.showPopup(at: location)
    }

    /// Hides the completion popup
    public func hideCompletionPopup() {
        componentVisibility.showCompletionPopup = false
        completionViewModel?.hidePopup()
    }

    /// Handles error states
    public func showError(_ message: String) {
        errorMessage = message
        statusText = "Error: \(message)"
        logger.error("Error shown: \(message)")
    }

    /// Clears the current error state
    public func clearError() {
        errorMessage = nil
        statusText = "Ready"
    }

    /// Handles loading states
    public func setLoading(_ loading: Bool, message: String = "") {
        isLoading = loading
        statusText = loading ? (message.isEmpty ? "Loading..." : message) : "Ready"
    }

    // MARK: - Child View Model Access

    /// Gets the gutter view model instance
    /// - Returns: The gutter view model, if available
    public func getGutterViewModel() -> GutterViewModel? {
        gutterViewModel
    }

    /// Gets the completion view model instance
    /// - Returns: The completion view model, if available
    public func getCompletionViewModel() -> CompletionViewModel? {
        completionViewModel
    }

    /// Gets the minimap view model instance
    /// - Returns: The minimap view model, if available
    public func getMinimapViewModel() -> MinimapViewModel? {
        minimapViewModel
    }

    // MARK: - Memory Management

    /// Clears all caches and resets state
    public func clearCaches() {
        businessLogicServices.clearAllCaches()
        gutterViewModel?.clearCache()
        completionViewModel?.clearCache()
        minimapViewModel?.clearCache()
        logger.debug("All caches cleared")
    }

    deinit {
        updateTask?.cancel()
        logger.debug("EditorContainerViewModel deinitialized")
    }
}

// MARK: - Private Implementation

@available(iOS 17.0, macOS 14.0, *)
extension EditorContainerViewModel {
    func updateComponentVisibility() {
        componentVisibility.showGutter = configuration.display.isLineNumbersEnabled
        componentVisibility.isMinimapVisible = configuration.display.isMinimapVisible
        componentVisibility.showScrollbar = true // Always show for now
        componentVisibility.showStatusBar = false // Configurable in future
    }

    func setupChildViewModels(textView: CodeEditorView) {
        // Create gutter view model
        gutterViewModel = GutterViewModel(
            configuration: configuration,
            businessLogicServices: businessLogicServices
        )
        gutterViewModel?.configure(with: textView)

        // Create completion view model
        completionViewModel = CompletionViewModel(
            configuration: configuration,
            businessLogicServices: businessLogicServices
        )
        completionViewModel?.configure(with: textView)

        // Create minimap view model
        minimapViewModel = MinimapViewModel(
            configuration: configuration,
            businessLogicServices: businessLogicServices
        )
        minimapViewModel?.configure(with: textView)
    }

    func updateChildViewModelFrames(_ frames: EditorLayoutService.ComponentFrames, animated: Bool) {
        gutterViewModel?.updateFrame(frames.gutterFrame, animated: animated)
        minimapViewModel?.updateFrame(frames.minimapFrame, animated: animated)

        // Completion popup positioning is handled dynamically
    }

    func updateEditorState() {
        guard let textView else { return }
        updateEditorStateFromText(textView.text ?? "")
    }

    func updateEditorStateFromText(_ text: String) {
        editorState.characterCount = text.count
        editorState.lineCount = textView?.lineGeometryStore.lineCount ?? text.components(separatedBy: .newlines).count

        // Update visible range if we have layout information
        if let textView {
            let visibleLineRange = businessLogicServices.lineNumberCalculationService.calculateVisibleLineRanges(
                for: textView,
                configuration: configuration
            )

            if let firstPosition = visibleLineRange.positions.first,
               let lastPosition = visibleLineRange.positions.last {
                editorState.visibleRange = NSRange(
                    location: firstPosition.characterRange.location,
                    length: lastPosition.characterRange.location + lastPosition.characterRange.length - firstPosition.characterRange.location
                )
            }
        }
    }

    func scheduleLayoutUpdate() {
        updateTask?.cancel()

        updateTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(self?.updateDebounceInterval ?? 0.1))

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard let self,
                          let layoutFrames = self.layoutFrames else { return }

                    self.updateLayout(containerBounds: layoutFrames.containerFrame, animated: true)
                }
            } catch is CancellationError {
                return
            } catch {
                CrossPlatformLogger.logger().error(
                    "EditorContainerViewModel layout debounce sleep failed: \(error.localizedDescription)"
                )
            }
        }
    }

    func debouncedUpdate(_ action: @escaping () -> Void) {
        updateTask?.cancel()

        updateTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(self?.updateDebounceInterval ?? 0.1))

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    action()
                }
            } catch is CancellationError {
                return
            } catch {
                CrossPlatformLogger.logger().error(
                    "EditorContainerViewModel debounce sleep failed: \(error.localizedDescription)"
                )
            }
        }
    }

    func getLineNumber(for characterIndex: Int) -> Int {
        guard let textView else { return 1 }
        return businessLogicServices.lineNumberCalculationService.lineNumber(for: characterIndex, in: textView)
    }

    func getColumnNumber(for characterIndex: Int) -> Int {
        guard let textView else { return 1 }
        let text = textView.text ?? ""
        let textLength = TextRangeUtilities.utf16Length(of: text)
        guard characterIndex >= 0 && characterIndex <= textLength else { return 1 }

        let store = textView.lineGeometryStore
        if store.lineCount > 0 {
            let lineIndex = store.lineIndex(forUtf16Offset: characterIndex)
            let lineStart = store.utf16Offset(forLineIndex: lineIndex)
            return max(1, characterIndex - lineStart + 1)
        }

        let lineRange = TextRangeUtilities.lineRange(containingUTF16Offset: characterIndex, in: text)
        return max(1, characterIndex - lineRange.location + 1)
    }
}

// MARK: - SwiftUI Integration

@available(iOS 17.0, macOS 14.0, *)
extension EditorContainerViewModel {
    /// Creates bindings for SwiftUI integration
    /// Creates a SwiftUI binding for the editor configuration
    /// - Returns: A binding that updates the configuration when changed
    public var configurationBinding: Binding<EditorConfiguration> {
        Binding(
            get: { self.configuration },
            set: { self.updateConfiguration($0) }
        )
    }

    /// Creates a SwiftUI binding for the error message
    /// - Returns: A binding that clears the error when set to nil
    public var errorBinding: Binding<String?> {
        Binding(
            get: { self.errorMessage },
            set: { _ in self.clearError() }
        )
    }

    /// Creates a SwiftUI binding for the loading state
    /// - Returns: A binding that updates the loading state
    public var loadingBinding: Binding<Bool> {
        Binding(
            get: { self.isLoading },
            set: { self.setLoading($0) }
        )
    }
}
