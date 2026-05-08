import Foundation

/// Optimized symbol navigation system with improved performance
@MainActor
public class OptimizedSymbolNavigator: ObservableObject {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "OptimizedSymbolNavigator")

    // MARK: - Published Properties

    @Published public private(set) var symbols: [DocumentSymbol] = []
    @Published public private(set) var currentBreadcrumbs: [BreadcrumbItem] = []
    @Published public private(set) var isProcessing = false
    @Published public private(set) var selectedSymbol: DocumentSymbol?

    // MARK: - Properties

    private weak var textView: CodeEditorView?
    private var providers: [Language: DocumentSymbolProvider] = [:]
    private var updateTask: Task<Void, Never>?
    private let asyncOperationManager = AsyncOperationManager()

    // MARK: - Caching

    private var flattenedSymbolsCache: [DocumentSymbol] = []
    private var symbolByIdCache: [UUID: DocumentSymbol] = [:]
    private var symbolRangeIndex: IntervalTree<DocumentSymbol> = IntervalTree()
    private var cacheGeneration: Int = 0

    // MARK: - Configuration

    public var configuration = SymbolNavigationConfiguration()

    // MARK: - Helper Types

    /// Interval tree for efficient range queries
    private class IntervalTree<T> {
        class Node {
            let range: NSRange
            let value: T
            var left: Node?
            var right: Node?

            init(range: NSRange, value: T) {
                self.range = range
                self.value = value
            }
        }

        private var root: Node?

        func insert(range: NSRange, value: T) {
            root = insertNode(root, range: range, value: value)
        }

        private func insertNode(_ node: Node?, range: NSRange, value: T) -> Node {
            guard let node else {
                return Node(range: range, value: value)
            }

            if range.location < node.range.location {
                node.left = insertNode(node.left, range: range, value: value)
                return node
            } else {
                node.right = insertNode(node.right, range: range, value: value)
                return node
            }
        }

        func findContaining(location: Int) -> [T] {
            var results: [T] = []
            findContainingInNode(root, location: location, results: &results)
            return results
        }

        private func findContainingInNode(_ node: Node?, location: Int, results: inout [T]) {
            guard let node else { return }

            let nodeEnd = node.range.location + node.range.length

            // Check if this node contains the location
            if node.range.location <= location && location < nodeEnd {
                results.append(node.value)
            }

            // Search left subtree if location might be there
            if let left = node.left, location < nodeEnd {
                findContainingInNode(left, location: location, results: &results)
            }

            // Search right subtree if location might be there
            if let right = node.right, location >= node.range.location {
                findContainingInNode(right, location: location, results: &results)
            }
        }

        func clear() {
            root = nil
        }
    }

    // MARK: - Initialization

    public init() {
        setupDefaultProviders()
    }

    /// Attach to a text view
    public func attach(to textView: CodeEditorView) {
        self.textView = textView
        updateSymbols()
    }

    // MARK: - Provider Management

    /// Register a symbol provider for a language
    public func registerProvider(_ provider: DocumentSymbolProvider, for language: Language) {
        providers[language] = provider
        logger.info("Registered symbol provider for \(language.name)")
    }

    private func setupDefaultProviders() {
        // Register default providers (same as original)
        registerProvider(SwiftSymbolProvider(), for: .swift)
        registerProvider(JavaScriptSymbolProvider(), for: .javascript)
        registerProvider(JavaScriptSymbolProvider(), for: .typescript)

        let cStyleProvider = CStyleSymbolProvider()
        registerProvider(cStyleProvider, for: .c)
        registerProvider(cStyleProvider, for: .cpp)
        registerProvider(cStyleProvider, for: .java)
        registerProvider(cStyleProvider, for: .go)
        registerProvider(cStyleProvider, for: .rust)

        registerProvider(PythonSymbolProvider(), for: .python)
        registerProvider(MarkdownSymbolProvider(), for: .markdown)
        registerProvider(HTMLSymbolProvider(), for: .html)
        registerProvider(CSSSymbolProvider(), for: .css)
        registerProvider(JSONSymbolProvider(), for: .json)
        registerProvider(YAMLSymbolProvider(), for: .yaml)
        registerProvider(XMLSymbolProvider(), for: .xml)
        registerProvider(SQLSymbolProvider(), for: .sql)
        registerProvider(RubySymbolProvider(), for: .ruby)
        registerProvider(PHPSymbolProvider(), for: .php)
        registerProvider(ShellSymbolProvider(), for: .shell)
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
        guard let textView, let provider = providers[textView.language] else {
            symbols = []
            invalidateCache()
            return
        }

        #if canImport(AppKit)
        guard let text = textView.textStorage?.string else {
            symbols = []
            invalidateCache()
            return
        }
        #else
        let text = textView.textStorage.string
        #endif

        isProcessing = true
        defer { isProcessing = false }

        // Detect symbols using provider
        let detectedSymbols = await provider.detectSymbols(in: text)

        // Build symbol tree optimized
        let symbolTree = buildSymbolTreeOptimized(from: detectedSymbols)

        // Update symbols and rebuild caches
        symbols = symbolTree
        rebuildCaches()

        // Update breadcrumbs based on current cursor position
        updateBreadcrumbs()

        logger.debug("Detected \(symbolTree.count) top-level symbols")
    }

    private func buildSymbolTreeOptimized(from symbols: [DocumentSymbol]) -> [DocumentSymbol] {
        // Use a more efficient algorithm with a single pass
        var rootSymbols: [DocumentSymbol] = []
        var symbolById: [UUID: DocumentSymbol] = [:]
        var parentMap: [UUID: UUID] = [:]

        // First pass: build ID map and determine parents
        for symbol in symbols {
            symbolById[symbol.id] = symbol

            // Find parent by checking containment
            for otherSymbol in symbols where otherSymbol.id != symbol.id {
                if RangeUtilities.contains(otherSymbol.range, symbol.range) {
                    // Check if this is the most immediate parent
                    if let existingParentId = parentMap[symbol.id],
                       let existingParent = symbolById[existingParentId] {
                        if RangeUtilities.contains(existingParent.range, otherSymbol.range) {
                            parentMap[symbol.id] = otherSymbol.id
                        }
                    } else {
                        parentMap[symbol.id] = otherSymbol.id
                    }
                }
            }
        }

        // Second pass: build tree structure
        var updatedSymbols: [UUID: DocumentSymbol] = [:]

        for symbol in symbols {
            var mutableSymbol = symbol
            mutableSymbol.children = []
            updatedSymbols[symbol.id] = mutableSymbol
        }

        // Add children to parents
        for (childId, parentId) in parentMap {
            if let child = updatedSymbols[childId],
               var parent = updatedSymbols[parentId] {
                parent.children.append(child)
                updatedSymbols[parentId] = parent
            }
        }

        // Collect root symbols
        for symbol in updatedSymbols.values where parentMap[symbol.id] == nil {
            rootSymbols.append(symbol)
        }

        // Sort by location
        rootSymbols.sort { $0.range.location < $1.range.location }

        return rootSymbols
    }

    // MARK: - Cache Management

    private func invalidateCache() {
        flattenedSymbolsCache.removeAll()
        symbolByIdCache.removeAll()
        symbolRangeIndex.clear()
        cacheGeneration += 1
    }

    private func rebuildCaches() {
        invalidateCache()

        // Build flattened cache
        var flattened: [DocumentSymbol] = []
        flattenSymbolsInto(symbols, into: &flattened)
        flattenedSymbolsCache = flattened

        // Build ID cache and range index
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
        if !flattenedSymbolsCache.isEmpty {
            return flattenedSymbolsCache
        }

        var flattened: [DocumentSymbol] = []
        flattenSymbolsInto(symbols, into: &flattened)
        flattenedSymbolsCache = flattened
        return flattened
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

        // Use cached flattened symbols for better performance
        let allSymbols = flattenedSymbols

        let nextSymbol = allSymbols
            .filter { $0.range.location > currentLocation }
            .min { $0.range.location < $1.range.location }

        if let nextSymbol {
            navigate(to: nextSymbol)
        }
    }

    /// Navigate to previous symbol
    public func navigateToPrevious() {
        guard let currentLocation = textView?.selectedRange.location else { return }

        // Use cached flattened symbols for better performance
        let allSymbols = flattenedSymbols

        let previousSymbol = allSymbols
            .filter { $0.range.location < currentLocation }
            .max { $0.range.location < $1.range.location }

        if let previousSymbol {
            navigate(to: previousSymbol)
        }
    }

    // MARK: - Breadcrumbs

    /// Update breadcrumbs based on current cursor position
    public func updateBreadcrumbs() {
        guard let textView else {
            currentBreadcrumbs = []
            return
        }

        let cursorLocation = textView.selectedRange.location
        var breadcrumbs: [BreadcrumbItem] = []

        // Use interval tree for efficient lookup
        let containingSymbols = symbolRangeIndex.findContaining(location: cursorLocation)

        // Sort by range size (smallest first = most specific)
        let sorted = containingSymbols.sorted { $0.range.length < $1.range.length }

        for (index, symbol) in sorted.enumerated() {
            breadcrumbs.append(BreadcrumbItem(
                symbol: symbol,
                level: index
            ))
        }

        currentBreadcrumbs = breadcrumbs
    }

    // MARK: - Symbol Search

    /// Search symbols by name
    public func searchSymbols(query: String) async -> [DocumentSymbol] {
        guard !query.isEmpty else { return flattenedSymbols }

        // Use the optimized fuzzy matcher
        let fuzzyMatcher = OptimizedFuzzyMatcher()
        let allSymbols = flattenedSymbols
        let symbolNames = allSymbols.map { $0.name }

        let matches = await fuzzyMatcher.match(pattern: query, candidates: symbolNames)

        // Build result using cached symbols
        return matches.compactMap { match in
            allSymbols.first { $0.name == match.item }
        }
    }

    /// Get symbol at location
    public func symbolAt(location: Int) -> DocumentSymbol? {
        // Use interval tree for O(log n) lookup
        symbolRangeIndex.findContaining(location: location).first
    }

    /// Get symbols in range
    public func symbolsIn(range: NSRange) -> [DocumentSymbol] {
        // Efficiently find symbols that overlap with the given range
        flattenedSymbols.filter { symbol in
            NSIntersectionRange(symbol.range, range).length > 0
        }
    }
}
