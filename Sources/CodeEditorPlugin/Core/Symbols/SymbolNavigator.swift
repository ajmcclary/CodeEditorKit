import CodeEditorCommon
import CodeEditorLanguages
import CodeEditorPlatform
import CodeEditorSymbols
import CodeEditorTextModel
import Foundation

/// Symbol navigation system for code outline and breadcrumbs
@MainActor
public class SymbolNavigator: ObservableObject {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "SymbolNavigator")

    // MARK: - Published Properties

    @Published public private(set) var symbols: [DocumentSymbol] = []
    @Published public private(set) var currentBreadcrumbs: [BreadcrumbItem] = []
    @Published public private(set) var isProcessing = false
    @Published public private(set) var selectedSymbol: DocumentSymbol?

    // MARK: - Properties

    private weak var textView: CodeEditorView?
    private var providerCatalog: SymbolProviderCatalog
    private var updateTask: Task<Void, Never>?
    private let asyncOperationManager = AsyncOperationManager()

    private var flattenedSymbolsCache: [DocumentSymbol] = []
    private var symbolByIdCache: [UUID: DocumentSymbol] = [:]
    private var symbolRangeIndex = SymbolRangeIndex<DocumentSymbol>()

    // MARK: - Configuration

    public var configuration = SymbolNavigationConfiguration()

    // MARK: - Initialization

    public init(providerCatalog: SymbolProviderCatalog = .default) {
        self.providerCatalog = providerCatalog
    }

    /// Attach to a text view
    public func attach(to textView: CodeEditorView) {
        self.textView = textView
        updateSymbols()
    }

    // MARK: - Provider Management

    /// Register a symbol provider for a language
    public func registerProvider(_ provider: DocumentSymbolProvider, for language: Language) {
        providerCatalog.registerProvider(provider, for: language)
        logger.info("Registered symbol provider for \(language.name)")
    }

    internal func hasProvider(for language: Language) -> Bool {
        providerCatalog.hasProvider(for: language)
    }

    // MARK: - Symbol Detection

    /// Update symbols based on current text
    public func updateSymbols() {
        updateTask?.cancel()

        updateTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await self.asyncOperationManager.debounce(
                    key: "symbolUpdate",
                    delay: 0.3
                ) {
                    await self.detectSymbols()
                }
            } catch {
                // Debounce cancelled
            }
        }
    }

    private func detectSymbols() async {
        guard let textView, let provider = providerCatalog.provider(for: textView.language) else {
            symbols = []
            invalidateSymbolCaches()
            return
        }
        let text = textView.textKitBridge.documentString
        guard !text.isEmpty else {
            symbols = []
            invalidateSymbolCaches()
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        // Detect symbols using provider
        let detectedSymbols = await provider.detectSymbols(in: text)

        // Build symbol tree
        let symbolTree = buildSymbolTree(from: detectedSymbols)

        // Update symbols
        symbols = symbolTree
        rebuildSymbolCaches()

        // Update breadcrumbs based on current cursor position
        updateBreadcrumbs()

        logger.debug("Detected \(symbolTree.count) top-level symbols")
    }

    private func buildSymbolTree(from symbols: [DocumentSymbol]) -> [DocumentSymbol] {
        // Sort symbols by range location
        let sorted = symbols.sorted { $0.range.location < $1.range.location }

        var rootSymbols: [DocumentSymbol] = []
        var symbolStack: [DocumentSymbol] = []

        for symbol in sorted {
            // Pop symbols from stack that don't contain current symbol
            while let parent = symbolStack.last,
                  !TextRangeUtilities.contains(parent.range, symbol.range) {
                symbolStack.removeLast()
            }

            if let parent = symbolStack.last {
                // Add as child to parent
                var updatedParent = parent
                updatedParent.children.append(symbol)

                // Update parent in stack
                symbolStack[symbolStack.count - 1] = updatedParent

                // Also update in root symbols if needed
                updateSymbolInTree(&rootSymbols, updated: updatedParent)
            } else {
                // Add as root symbol
                rootSymbols.append(symbol)
            }

            // Add to stack if it can contain other symbols
            if symbol.kind.canContainSymbols {
                symbolStack.append(symbol)
            }
        }

        return rootSymbols
    }

    private func updateSymbolInTree(_ tree: inout [DocumentSymbol], updated: DocumentSymbol) {
        for index in 0..<tree.count {
            if tree[index].id == updated.id {
                tree[index] = updated
                return
            }
            updateSymbolInTree(&tree[index].children, updated: updated)
        }
    }

    // MARK: - Cache Management

    private func invalidateSymbolCaches() {
        flattenedSymbolsCache.removeAll()
        symbolByIdCache.removeAll()
        symbolRangeIndex.removeAll()
    }

    private func rebuildSymbolCaches() {
        invalidateSymbolCaches()

        var flattened: [DocumentSymbol] = []
        flattenSymbolsInto(symbols, into: &flattened)
        flattenedSymbolsCache = flattened

        for symbol in flattened {
            symbolByIdCache[symbol.id] = symbol
            symbolRangeIndex.insert(range: symbol.range, value: symbol)
        }
    }

    private func flattenSymbolsInto(_ symbols: [DocumentSymbol], into result: inout [DocumentSymbol]) {
        for symbol in symbols {
            result.append(symbol)
            flattenSymbolsInto(symbol.children, into: &result)
        }
    }

    private var flattenedSymbols: [DocumentSymbol] {
        if flattenedSymbolsCache.isEmpty, symbols.isEmpty == false {
            var flattened: [DocumentSymbol] = []
            flattenSymbolsInto(symbols, into: &flattened)
            flattenedSymbolsCache = flattened
        }
        return flattenedSymbolsCache
    }

    // MARK: - Navigation

    /// Navigate to a symbol
    public func navigate(to symbol: DocumentSymbol) {
        guard let textView else { return }

        // Select the symbol range
        textView.selectedRange = symbol.selectionRange

        // Scroll to make visible only if autoScrollToCursor is enabled
        if textView.configuration.behavior.autoScrollToCursor {
            textView.scrollRangeToVisible(symbol.selectionRange)
        }

        // Update selected symbol
        selectedSymbol = symbol
        updateBreadcrumbs()

        logger.info("Navigated to symbol: \(symbol.name)")
    }

    /// Navigate to next symbol
    public func navigateToNext() {
        guard let currentLocation = textView?.selectedRange.location else { return }

        if let nextSymbol = findNextSymbol(after: currentLocation) {
            navigate(to: nextSymbol)
        }
    }

    /// Navigate to previous symbol
    public func navigateToPrevious() {
        guard let currentLocation = textView?.selectedRange.location else { return }

        if let previousSymbol = findPreviousSymbol(before: currentLocation) {
            navigate(to: previousSymbol)
        }
    }

    private func findNextSymbol(after location: Int) -> DocumentSymbol? {
        let allSymbols = flattenedSymbols

        return allSymbols
            .filter { $0.range.location > location }
            .min { $0.range.location < $1.range.location }
    }

    private func findPreviousSymbol(before location: Int) -> DocumentSymbol? {
        let allSymbols = flattenedSymbols

        return allSymbols
            .filter { $0.range.location < location }
            .max { $0.range.location < $1.range.location }
    }

    private func flattenSymbols(_ symbols: [DocumentSymbol]) -> [DocumentSymbol] {
        var flattened: [DocumentSymbol] = []
        flattenSymbolsInto(symbols, into: &flattened)
        return flattened
    }

    // MARK: - Breadcrumbs

    /// Update breadcrumbs based on current cursor position
    public func updateBreadcrumbs() {
        guard let textView else {
            currentBreadcrumbs = []
            return
        }

        let cursorLocation = textView.selectedRange.location
        currentBreadcrumbs = symbolRangeIndex
            .findContaining(location: cursorLocation)
            .sorted { lhs, rhs in
                if lhs.range.length == rhs.range.length {
                    return lhs.range.location < rhs.range.location
                }
                return lhs.range.length > rhs.range.length
            }
            .enumerated()
            .map { index, symbol in
                BreadcrumbItem(symbol: symbol, level: index)
            }
    }

    // MARK: - Symbol Search

    /// Search symbols by name
    public func searchSymbols(query: String) -> [DocumentSymbol] {
        guard !query.isEmpty else { return flattenedSymbols }

        let fuzzyMatcher = OptimizedFuzzyMatcher()
        let allSymbols = flattenedSymbols
        let symbolNames = allSymbols.map { $0.name }

        let matches = fuzzyMatcher.matchSequential(pattern: query, candidates: symbolNames)

        return matches.compactMap { match in
            allSymbols.first { $0.name == match.item }
        }
    }

    /// Get symbol at location
    public func symbol(at location: Int) -> DocumentSymbol? {
        symbolRangeIndex
            .findContaining(location: location)
            .min { lhs, rhs in
                if lhs.range.length == rhs.range.length {
                    return lhs.range.location > rhs.range.location
                }
                return lhs.range.length < rhs.range.length
            }
    }

    /// Get a cached symbol by ID.
    public func symbol(withId id: UUID) -> DocumentSymbol? {
        symbolByIdCache[id]
    }

    deinit {
        updateTask?.cancel()
    }
}
