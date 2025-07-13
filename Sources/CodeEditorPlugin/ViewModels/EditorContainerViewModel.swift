import Foundation
import SwiftUI
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
    
    public struct EditorState {
        public var isEditing: Bool
        public var hasUnsavedChanges: Bool
        public var lineCount: Int
        public var characterCount: Int
        public var selectedRange: NSRange
        public var visibleRange: NSRange
        public var scrollPosition: CGPoint
        
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
    
    public struct ComponentVisibility {
        public var showGutter: Bool
        public var showMinimap: Bool
        public var showScrollbar: Bool
        public var showStatusBar: Bool
        public var showCompletionPopup: Bool
        
        public init(
            showGutter: Bool = true,
            showMinimap: Bool = false,
            showScrollbar: Bool = true,
            showStatusBar: Bool = false,
            showCompletionPopup: Bool = false
        ) {
            self.showGutter = showGutter
            self.showMinimap = showMinimap
            self.showScrollbar = showScrollbar
            self.showStatusBar = showStatusBar
            self.showCompletionPopup = showCompletionPopup
        }
    }
    
    // MARK: - Published Properties
    
    public var editorState: EditorState
    public var componentVisibility: ComponentVisibility
    public var configuration: EditorConfiguration
    public var layoutFrames: EditorLayoutService.ComponentFrames?
    
    // Error and status states
    public var errorMessage: String?
    public var isLoading: Bool = false
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
    @ObservationIgnored private var updateWorkItem: DispatchWorkItem?
    private let updateDebounceInterval: TimeInterval = 0.1
    
    // MARK: - Initialization
    
    public init(
        configuration: EditorConfiguration = EditorConfiguration(),
        businessLogicServices: BusinessLogicServiceRegistry = BusinessLogicServiceRegistry.shared
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
    
    public func getGutterViewModel() -> GutterViewModel? {
        gutterViewModel
    }
    
    public func getCompletionViewModel() -> CompletionViewModel? {
        completionViewModel
    }
    
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
        logger.debug("EditorContainerViewModel deinitialized")
    }
}

// MARK: - Private Implementation

@available(iOS 17.0, macOS 14.0, *)
extension EditorContainerViewModel {
    func updateComponentVisibility() {
        componentVisibility.showGutter = configuration.display.isLineNumbersEnabled
        componentVisibility.showMinimap = configuration.display.showMinimap
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
        editorState.lineCount = text.components(separatedBy: .newlines).count
        
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
        updateWorkItem?.cancel()
        
        updateWorkItem = DispatchWorkItem { [weak self] in
            guard let self,
                  let layoutFrames = self.layoutFrames else { return }
            
            self.updateLayout(containerBounds: layoutFrames.containerFrame, animated: true)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + updateDebounceInterval, execute: updateWorkItem!)
    }
    
    func debouncedUpdate(_ action: @escaping () -> Void) {
        updateWorkItem?.cancel()
        
        updateWorkItem = DispatchWorkItem {
            action()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + updateDebounceInterval, execute: updateWorkItem!)
    }
    
    func getLineNumber(for characterIndex: Int) -> Int {
        guard let textView else { return 1 }
        return businessLogicServices.lineNumberCalculationService.lineNumber(for: characterIndex, in: textView)
    }
    
    func getColumnNumber(for characterIndex: Int) -> Int {
        guard let textView else { return 1 }
        let text = textView.text ?? ""
        guard characterIndex >= 0 && characterIndex <= text.count else { return 1 }
        
        let textUpToIndex = String(text.prefix(characterIndex))
        if let lastNewlineIndex = textUpToIndex.lastIndex(of: "\n") {
            let lineStart = textUpToIndex.index(after: lastNewlineIndex)
            return textUpToIndex.distance(from: lineStart, to: textUpToIndex.endIndex) + 1
        } else {
            return characterIndex + 1
        }
    }
}

// MARK: - SwiftUI Integration

@available(iOS 17.0, macOS 14.0, *)
extension EditorContainerViewModel {
    /// Creates bindings for SwiftUI integration
    public var configurationBinding: Binding<EditorConfiguration> {
        Binding(
            get: { self.configuration },
            set: { self.updateConfiguration($0) }
        )
    }
    
    public var errorBinding: Binding<String?> {
        Binding(
            get: { self.errorMessage },
            set: { _ in self.clearError() }
        )
    }
    
    public var loadingBinding: Binding<Bool> {
        Binding(
            get: { self.isLoading },
            set: { self.setLoading($0) }
        )
    }
}
