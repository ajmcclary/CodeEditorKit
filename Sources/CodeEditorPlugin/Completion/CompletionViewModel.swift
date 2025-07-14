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
    // MARK: - Types
    
    public struct CompletionPopupState {
        public var isVisible: Bool
        public var position: CGPoint
        public var size: CGSize
        public var selectedIndex: Int
        public var isLoading: Bool
        public var animationDuration: TimeInterval
        
        public init(
            isVisible: Bool = false,
            position: CGPoint = .zero,
            size: CGSize = CGSize(width: 300, height: 200),
            selectedIndex: Int = 0,
            isLoading: Bool = false,
            animationDuration: TimeInterval = 0.2
        ) {
            self.isVisible = isVisible
            self.position = position
            self.size = size
            self.selectedIndex = selectedIndex
            self.isLoading = isLoading
            self.animationDuration = animationDuration
        }
    }
    
    public struct CompletionContext {
        public let triggerLocation: Int
        public let triggerCharacter: String?
        public let prefix: String
        public let currentLine: String
        public let language: Language
        public let contextRange: NSRange
        
        public init(
            triggerLocation: Int,
            triggerCharacter: String?,
            prefix: String,
            currentLine: String,
            language: Language,
            contextRange: NSRange
        ) {
            self.triggerLocation = triggerLocation
            self.triggerCharacter = triggerCharacter
            self.prefix = prefix
            self.currentLine = currentLine
            self.language = language
            self.contextRange = contextRange
        }
    }
    
    public struct CompletionItem: Identifiable, Hashable {
        public let id = UUID()
        public let text: String
        public let kind: CompletionItemKind
        public let detail: String?
        public let documentation: String?
        public let insertText: String?
        public let priority: Int
        public let matchScore: Double
        
        public init(
            text: String,
            kind: CompletionItemKind,
            detail: String? = nil,
            documentation: String? = nil,
            insertText: String? = nil,
            priority: Int = 0,
            matchScore: Double = 1.0
        ) {
            self.text = text
            self.kind = kind
            self.detail = detail
            self.documentation = documentation
            self.insertText = insertText
            self.priority = priority
            self.matchScore = matchScore
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    public enum CompletionItemKind {
        case keyword
        case function
        case variable
        case type
        case constant
        case method
        case property
        case snippet
        case module
        case file
        case unknown
        
        public var icon: String {
            switch self {
            case .keyword: return "k.square"
            case .function: return "function"
            case .variable: return "v.square"
            case .type: return "t.square"
            case .constant: return "c.square"
            case .method: return "m.square"
            case .property: return "p.square"
            case .snippet: return "note.text"
            case .module: return "shippingbox"
            case .file: return "doc"
            case .unknown: return "questionmark.square"
            }
        }
        
        public var priority: Int {
            switch self {
            case .snippet: return 100
            case .keyword: return 90
            case .function, .method: return 80
            case .variable, .property: return 70
            case .type: return 60
            case .constant: return 50
            case .module: return 40
            case .file: return 30
            case .unknown: return 10
            }
        }
    }
    
    // MARK: - Published Properties
    
    public var popupState: CompletionPopupState
    public var completionItems: [CompletionItem] = []
    public var filteredItems: [CompletionItem] = []
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
    
    // Completion providers
    private var completionProviders: [CompletionProvider] = []
    
    // Debouncing and throttling
    @available(iOS 17.0, macOS 14.0, *)
    @ObservationIgnored private var completionTask: Task<Void, Never>?
    @available(iOS 17.0, macOS 14.0, *)
    @ObservationIgnored private var filterTask: Task<Void, Never>?
    private let completionDebounceInterval: TimeInterval = 0.3
    private let filterDebounceInterval: TimeInterval = 0.1
    
    // Cache
    private var cachedCompletions: [String: [CompletionItem]] = [:]
    private let maxCacheSize = 50
    
    // Constants
    private let maxCompletionItems = 100
    private let defaultPopupSize = CGSize(width: 350, height: 250)
    
    // MARK: - Initialization
    
    public init(
        configuration: EditorConfiguration,
        businessLogicServices: BusinessLogicServiceRegistry = BusinessLogicServiceRegistry.shared
    ) {
        self.configuration = configuration
        self.businessLogicServices = businessLogicServices
        self.popupState = CompletionPopupState()
        
        setupCompletionProviders()
        logger.debug("CompletionViewModel initialized")
    }
    
    // MARK: - Public Interface
    
    /// Configures the view model with a text view
    public func configure(with textView: CodeEditorView) {
        self.textView = textView
        logger.debug("CompletionViewModel configured with text view")
    }
    
    /// Updates the configuration
    public func updateConfiguration(_ newConfiguration: EditorConfiguration) {
        configuration = newConfiguration
        setupCompletionProviders()
    }
    
    /// Called when text content changes
    public func textDidChange(_ newText: String) {
        // Check if completion should be triggered
        guard let textView else { return }
        
        let currentLocation = textView.selectedRange.location
        if shouldTriggerCompletion(at: currentLocation, in: newText) {
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
        let insertText = selectedItem.insertText ?? selectedItem.text
        
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
        logger.debug("Accepted completion: \(selectedItem.text)")
        return true
    }
    
    /// Gets the currently selected completion item
    public func getSelectedItem() -> CompletionItem? {
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
        cachedCompletions.removeAll()
        completionItems.removeAll()
        filteredItems.removeAll()
        logger.debug("Completion cache cleared")
    }
    
    deinit {
        logger.debug("CompletionViewModel deinitialized")
    }
}

// MARK: - Supporting Types

public enum SelectionDirection {
    case up
    case down
    case pageUp
    case pageDown
    case first
    case last
}

// MARK: - Private Implementation

@available(iOS 17.0, macOS 14.0, *)
extension CompletionViewModel {
    func setupCompletionProviders() {
        // Get the current language from text view or default to Swift
        let currentLanguage = textView?.language ?? .swift
        
        // Integrate with CompletionProviderRegistry
        completionProviders = CompletionProviderRegistry.shared.providers(for: currentLanguage)
        
        // If no providers found for the language, try to create one from the factory
        if completionProviders.isEmpty {
            if let provider = LanguageProviderFactory.createProvider(for: currentLanguage) {
                CompletionProviderRegistry.shared.register(provider)
                completionProviders = [provider]
            }
        }
        
        logger.debug("Completion providers configured for \(currentLanguage): \(completionProviders.count) providers")
    }
    
    func shouldTriggerCompletion(at location: Int, in text: String) -> Bool {
        guard location > 0 && location <= text.count else { return false }
        
        let index = text.index(text.startIndex, offsetBy: location - 1)
        let character = String(text[index])
        
        // Check trigger characters
        let triggerCharacters = [".", " ", "(", "[", "{"]
        return triggerCharacters.contains(character)
    }
    
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
        guard textView != nil else { return }
        
        // Extract completion context
        let context = extractCompletionContext(at: location, in: text)
        currentContext = context
        
        // Check cache first
        let cacheKey = generateCacheKey(for: context)
        if let cached = cachedCompletions[cacheKey] {
            completionItems = cached
            updateFilteredItems()
            popupState.isLoading = false
            return
        }
        
        // Generate completions
        Task {
            do {
                let items = try await generateCompletions(for: context)
                
                await MainActor.run {
                    self.completionItems = items
                    self.cacheCompletions(cacheKey: cacheKey, items: items)
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
    
    func extractCompletionContext(at location: Int, in text: String) -> CompletionContext {
        guard location <= text.count else {
            return CompletionContext(
                triggerLocation: location,
                triggerCharacter: nil,
                prefix: "",
                currentLine: "",
                language: .swift,
                contextRange: NSRange(location: 0, length: 0)
            )
        }
        
        // Extract current line
        let lines = text.components(separatedBy: .newlines)
        var currentLineIndex = 0
        var currentLineStart = 0
        
        for (index, line) in lines.enumerated() {
            let lineEnd = currentLineStart + line.count
            if location <= lineEnd {
                currentLineIndex = index
                break
            }
            currentLineStart = lineEnd + 1 // +1 for newline
        }
        
        let currentLine = currentLineIndex < lines.count ? lines[currentLineIndex] : ""
        
        // Extract prefix (word being typed)
        let prefix = extractPrefix(at: location, in: text)
        
        // Determine trigger character
        var triggerCharacter: String?
        if location > 0 {
            let index = text.index(text.startIndex, offsetBy: location - 1)
            triggerCharacter = String(text[index])
        }
        
        return CompletionContext(
            triggerLocation: location,
            triggerCharacter: triggerCharacter,
            prefix: prefix,
            currentLine: currentLine,
            language: textView?.language ?? .swift,
            contextRange: NSRange(location: max(0, location - 100), length: min(200, text.count - max(0, location - 100)))
        )
    }
    
    func extractPrefix(at location: Int, in text: String) -> String {
        guard location > 0 else { return "" }
        
        var prefixStart = location
        let characterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        
        for charIndex in stride(from: location - 1, through: 0, by: -1) {
            let index = text.index(text.startIndex, offsetBy: charIndex)
            let character = text[index]
            
            if character.unicodeScalars.allSatisfy({ characterSet.contains($0) }) {
                prefixStart = charIndex
            } else {
                break
            }
        }
        
        if prefixStart < location {
            let startIndex = text.index(text.startIndex, offsetBy: prefixStart)
            let endIndex = text.index(text.startIndex, offsetBy: location)
            return String(text[startIndex..<endIndex])
        }
        
        return ""
    }
    
    func generateCompletions(for context: CompletionContext) async throws -> [CompletionItem] {
        // This would integrate with completion providers
        // For now, generate some basic completions
        
        var items: [CompletionItem] = []
        
        // Add basic Swift keywords if relevant
        if context.language == .swift {
            let keywords = ["func", "var", "let", "class", "struct", "enum", "protocol", "extension", "import", "if", "else", "for", "while", "switch", "case", "default", "return", "break", "continue"]
            
            for keyword in keywords where keyword.lowercased().hasPrefix(context.prefix.lowercased()) {
                let score = calculateMatchScore(keyword, prefix: context.prefix)
                items.append(CompletionItem(
                    text: keyword,
                    kind: .keyword,
                    priority: CompletionItemKind.keyword.priority,
                    matchScore: score
                ))
            }
        }
        
        // Sort by match score and priority
        items.sort { item1, item2 in
            if item1.priority == item2.priority {
                return item1.matchScore > item2.matchScore
            }
            return item1.priority > item2.priority
        }
        
        return Array(items.prefix(maxCompletionItems))
    }
    
    func calculateMatchScore(_ text: String, prefix: String) -> Double {
        guard !prefix.isEmpty else { return 1.0 }
        
        let lowerText = text.lowercased()
        let lowerPrefix = prefix.lowercased()
        
        if lowerText.hasPrefix(lowerPrefix) {
            return 1.0 - (Double(prefix.count) / Double(text.count))
        }
        
        if lowerText.contains(lowerPrefix) {
            return 0.5
        }
        
        return 0.0
    }
    
    func updateFilterText(at location: Int, in text: String) {
        guard currentContext != nil else { return }
        
        let newPrefix = extractPrefix(at: location, in: text)
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
        if filterText.isEmpty {
            filteredItems = completionItems
        } else {
            let filtered = completionItems.filter { item in
                item.text.lowercased().contains(filterText.lowercased())
            }
            
            filteredItems = filtered.sorted { item1, item2 in
                let score1 = calculateMatchScore(item1.text, prefix: filterText)
                let score2 = calculateMatchScore(item2.text, prefix: filterText)
                return score1 > score2
            }
        }
        
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
    
    // MARK: - Cache Helpers
    
    func generateCacheKey(for context: CompletionContext) -> String {
        "\(context.language.rawValue)_\(context.prefix)_\(context.triggerCharacter ?? "")_\(context.currentLine.hash)"
    }
    
    func cacheCompletions(cacheKey: String, items: [CompletionItem]) {
        if cachedCompletions.count >= maxCacheSize,
           let oldestKey = cachedCompletions.keys.first {
            // Remove oldest entry
            cachedCompletions.removeValue(forKey: oldestKey)
        }
        cachedCompletions[cacheKey] = items
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
