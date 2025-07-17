import Foundation
import SwiftUI
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Completion View Model

/// View model responsible for code completion popup coordination and state management
/// Manages completion suggestions, filtering, and popup positioning
@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Observable
public final class CompletionViewModel {
    // MARK: - Published Properties
    
    public var popupState: CompletionPopupState
    public var completionItems: [CompletionItemModel] = []
    public var filteredItems: [CompletionItemModel] = []
    public var currentContext: CompletionContext?
    public var configuration: EditorConfiguration
    
    // Filter and search state
    public var filterText: String = ""
    public var showDetailedView: Bool = false
    
    // MARK: - Private Properties
    
    private let businessLogicServices: BusinessLogicServiceRegistry
    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "CompletionViewModel")
    
    // Text view reference (weak to avoid retain cycles)
    private weak var textView: CodeEditorView?
    
    // Services
    private let contextExtractor = CompletionContextExtractor()
    private let cacheManager = CompletionCacheManager()
    private let filteringService = CompletionFilteringService()
    private let generationService = CompletionGenerationService()
    
    // Debouncing and throttling
    @available(iOS 17.0, macOS 14.0, *)
    @ObservationIgnored private var completionTask: Task<Void, Never>?
    @available(iOS 17.0, macOS 14.0, *)
    @ObservationIgnored private var filterTask: Task<Void, Never>?
    private let completionDebounceInterval: TimeInterval = 0.3
    private let filterDebounceInterval: TimeInterval = 0.1
    
    // Constants
    private let maxCompletionItems = 100
    private let defaultPopupSize = CGSize(width: 350, height: 250)
    
    // MARK: - Initialization
    
    public init(
        configuration: EditorConfiguration,
        businessLogicServices: BusinessLogicServiceRegistry
    ) {
        self.configuration = configuration
        self.businessLogicServices = businessLogicServices
        self.popupState = CompletionPopupState()
        
        logger.debug("CompletionViewModel initialized")
    }
    
    // MARK: - Public Interface
    
    /// Configures the view model with a text view
    public func configure(with textView: CodeEditorView) {
        self.textView = textView
        generationService.configureProviders(for: textView.language)
        logger.debug("CompletionViewModel configured with text view")
    }
    
    /// Updates the configuration
    public func updateConfiguration(_ newConfiguration: EditorConfiguration) {
        configuration = newConfiguration
        if let language = textView?.language {
            generationService.configureProviders(for: language)
        }
    }
    
    /// Called when text content changes
    public func textDidChange(_ newText: String) {
        // Check if completion should be triggered
        guard let textView else { return }
        
        let currentLocation = textView.selectedRange.location
        if contextExtractor.shouldTriggerCompletion(at: currentLocation, in: newText) {
            triggerCompletion(at: currentLocation, in: newText)
        } else if popupState.isVisible {
            // Update filter if popup is visible
            updateFilterText(at: currentLocation, in: newText)
        }
    }
    
    /// Called when selection changes
    public func selectionDidChange(_ newRange: NSRange) {
        if popupState.isVisible && newRange.length > 0 {
            // Hide popup if user makes a selection
            hidePopup()
        }
    }
    
    /// Shows the completion popup at the specified location
    public func showPopup(at location: CGPoint) {
        popupState.position = location
        popupState.size = calculateOptimalPopupSize()
        popupState.isVisible = true
        popupState.selectedIndex = 0
        
        // Reset filter
        filterText = ""
        updateFilteredItems()
        
        logger.debug("Completion popup shown at \(location)")
    }
    
    /// Hides the completion popup
    public func hidePopup() {
        popupState.isVisible = false
        popupState.selectedIndex = 0
        currentContext = nil
        
        // Cancel any pending operations
        completionTask?.cancel()
        filterTask?.cancel()
        
        logger.debug("Completion popup hidden")
    }
    
    /// Moves selection in the popup
    public func moveSelection(direction: SelectionDirection) {
        guard popupState.isVisible && !filteredItems.isEmpty else { return }
        
        switch direction {
        case .up:
            popupState.selectedIndex = max(0, popupState.selectedIndex - 1)

        case .down:
            popupState.selectedIndex = min(filteredItems.count - 1, popupState.selectedIndex + 1)

        case .pageUp:
            popupState.selectedIndex = max(0, popupState.selectedIndex - 10)

        case .pageDown:
            popupState.selectedIndex = min(filteredItems.count - 1, popupState.selectedIndex + 10)

        case .first:
            popupState.selectedIndex = 0

        case .last:
            popupState.selectedIndex = filteredItems.count - 1
        }
    }
    
    /// Accepts the currently selected completion
    public func acceptSelectedCompletion() -> Bool {
        guard popupState.isVisible,
              popupState.selectedIndex < filteredItems.count,
              let textView,
              let context = currentContext else { return false }
        
        let selectedItem = filteredItems[popupState.selectedIndex]
        let insertText = selectedItem.insertText
        
        // Calculate insertion range
        let insertionRange = NSRange(
            location: context.triggerLocation - context.prefix.count,
            length: context.prefix.count
        )
        
        // Perform text replacement
        if let text = textView.text {
            let mutableText = NSMutableString(string: text)
            mutableText.replaceCharacters(in: insertionRange, with: insertText)
            textView.text = mutableText as String
            
            // Update selection
            let newLocation = insertionRange.location + insertText.count
            textView.selectedRange = NSRange(location: newLocation, length: 0)
        }
        
        hidePopup()
        logger.debug("Accepted completion: \(selectedItem.label)")
        return true
    }
    
    /// Gets the currently selected completion item
    public func getSelectedItem() -> CompletionItemModel? {
        guard popupState.isVisible,
              popupState.selectedIndex < filteredItems.count else { return nil }
        return filteredItems[popupState.selectedIndex]
    }
    
    /// Toggles detailed view mode
    public func toggleDetailedView() {
        showDetailedView.toggle()
        popupState.size = calculateOptimalPopupSize()
    }
    
    // MARK: - Cache Management
    
    /// Clears the completion cache
    public func clearCache() {
        cacheManager.clearCache()
        completionItems.removeAll()
        filteredItems.removeAll()
        logger.debug("Completion cache cleared")
    }
    
    deinit {
        logger.debug("CompletionViewModel deinitialized")
    }
}

// MARK: - Private Implementation

@available(iOS 17.0, macOS 14.0, *)
extension CompletionViewModel {
    func triggerCompletion(at location: Int, in text: String) {
        completionTask?.cancel()
        
        popupState.isLoading = true
        
        completionTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(self?.completionDebounceInterval ?? 0.3))
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self?.performCompletion(at: location, in: text)
                }
            } catch {
                // Task was cancelled
            }
        }
    }
    
    func performCompletion(at location: Int, in text: String) {
        guard let textView else { return }
        
        // Extract completion context
        let context = contextExtractor.extractContext(
            at: location,
            in: text,
            language: textView.language
        )
        currentContext = context
        
        // Check cache first
        let cacheKey = cacheManager.generateCacheKey(for: context)
        let cached = cacheManager.getCachedCompletions(for: cacheKey)
        if !cached.isEmpty {
            cacheManager.recordCacheHit()
            completionItems = cached
            updateFilteredItems()
            popupState.isLoading = false
            return
        }
        
        cacheManager.recordCacheMiss()
        
        // Generate completions
        Task {
            do {
                let items = try await generationService.generateCompletions(for: context)
                
                await MainActor.run {
                    self.completionItems = items
                    self.cacheManager.cacheCompletions(items, for: cacheKey)
                    self.updateFilteredItems()
                    self.popupState.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.logger.error("Completion generation failed: \(error)")
                    self.popupState.isLoading = false
                    self.hidePopup()
                }
            }
        }
    }
    
    func updateFilterText(at location: Int, in text: String) {
        guard currentContext != nil else { return }
        
        let newPrefix = contextExtractor.extractPrefix(at: location, in: text)
        if newPrefix != filterText {
            filterText = newPrefix
            scheduleFilterUpdate()
        }
    }
    
    func scheduleFilterUpdate() {
        filterTask?.cancel()
        
        filterTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(self?.filterDebounceInterval ?? 0.1))
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self?.updateFilteredItems()
                }
            } catch {
                // Task was cancelled
            }
        }
    }
    
    func updateFilteredItems() {
        filteredItems = filteringService.filterItems(
            completionItems,
            filterText: filterText,
            options: CompletionFilteringService.FilterOptions(
                caseSensitive: false,
                fuzzyMatching: true,
                maxResults: maxCompletionItems
            )
        )
        
        // Reset selection if needed
        if popupState.selectedIndex >= filteredItems.count {
            popupState.selectedIndex = 0
        }
    }
    
    func calculateOptimalPopupSize() -> CGSize {
        var width = defaultPopupSize.width
        var height = defaultPopupSize.height
        
        if showDetailedView {
            width *= 1.5
            height *= 1.2
        }
        
        // Adjust based on content
        let itemCount = min(filteredItems.count, 10)
        let itemHeight: CGFloat = 22
        height = max(100, CGFloat(itemCount) * itemHeight + 20)
        
        return CGSize(width: width, height: height)
    }
}

// MARK: - SwiftUI Integration

@available(iOS 17.0, macOS 14.0, *)
extension CompletionViewModel {
    /// Creates a binding for popup visibility
    public var popupVisibilityBinding: Binding<Bool> {
        Binding(
            get: { self.popupState.isVisible },
            set: { newValue in
                if newValue {
                    // Trigger completion at current location
                    if let textView = self.textView {
                        let location = textView.selectedRange.location
                        self.triggerCompletion(at: location, in: textView.text ?? "")
                    }
                } else {
                    self.hidePopup()
                }
            }
        )
    }
    
    /// Creates a binding for the selected index
    public var selectedIndexBinding: Binding<Int> {
        Binding(
            get: { self.popupState.selectedIndex },
            set: { self.popupState.selectedIndex = $0 }
        )
    }
}
