import CodeEditorCommon
import CodeEditorCompletion
import CodeEditorLanguages
import CodeEditorPlatform
import CodeEditorSymbols
import CodeEditorTextModel
import Foundation

/// Symbol navigation system for code outline and breadcrumbs
@MainActor
public class SymbolNavigator: ObservableObject {
    private let logger = CodeEditorLog.logger(category: "SymbolNavigator")

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

        // Build symbol tree (bounded: the outline of a generated or
        // minified document is not navigable anyway).
        let bounded = detectedSymbols.count > Self.maximumIndexedSymbols
            ? Array(detectedSymbols.sorted { $0.range.location < $1.range.location }.prefix(Self.maximumIndexedSymbols))
            : detectedSymbols
        let symbolTree = Self.buildSymbolTree(from: bounded)

        // Update symbols
        symbols = symbolTree
        rebuildSymbolCaches()

        // Update breadcrumbs based on current cursor position
        updateBreadcrumbs()

        logger.debug("Detected \(symbolTree.count) top-level symbols")
    }

    /// The most symbols one document's outline indexes.
    nonisolated package static let maximumIndexedSymbols = 10_000
    /// The deepest nesting the outline keeps; deeper symbols attach to the
    /// deepest kept container. (Nested values are also released recursively,
    /// so nesting must not follow the input either.)
    nonisolated package static let maximumNestingDepth = 64

    /// Nests symbols by range containment in one pass with a stack of
    /// enclosing containers, then assembles the tree from the innermost
    /// symbols outward. Nothing here recurses with the input.
    package nonisolated static func buildSymbolTree(from symbols: [DocumentSymbol]) -> [DocumentSymbol] {
        let sorted = symbols.sorted { $0.range.location < $1.range.location }
        var parent = Array(repeating: -1, count: sorted.count)
        var enclosing: [Int] = []

        for (index, symbol) in sorted.enumerated() {
            while let last = enclosing.last,
                  !TextRangeUtilities.contains(sorted[last].range, symbol.range) {
                enclosing.removeLast()
            }
            parent[index] = enclosing.last ?? -1
            if symbol.kind.canContainSymbols, enclosing.count < maximumNestingDepth {
                enclosing.append(index)
            }
        }

        var childIndices = Array(repeating: [Int](), count: sorted.count)
        var rootIndices: [Int] = []
        for index in sorted.indices {
            if parent[index] >= 0 {
                childIndices[parent[index]].append(index)
            } else {
                rootIndices.append(index)
            }
        }

        // A child always sorts after its parent, so building from the end
        // finishes every child before its parent needs it.
        var built = sorted
        for index in sorted.indices.reversed() where !childIndices[index].isEmpty {
            built[index].children = childIndices[index].map { built[$0] }
        }
        return rootIndices.map { built[$0] }
    }

    /// Pre-order flattening with an explicit stack.
    package nonisolated static func flatten(_ symbols: [DocumentSymbol]) -> [DocumentSymbol] {
        var result: [DocumentSymbol] = []
        var pending = Array(symbols.reversed())
        while let symbol = pending.popLast() {
            result.append(symbol)
            pending.append(contentsOf: symbol.children.reversed())
        }
        return result
    }

    // MARK: - Cache Management

    private func invalidateSymbolCaches() {
        flattenedSymbolsCache.removeAll()
        symbolByIdCache.removeAll()
        symbolRangeIndex.removeAll()
    }

    private func rebuildSymbolCaches() {
        invalidateSymbolCaches()

        let flattened = Self.flatten(symbols)
        flattenedSymbolsCache = flattened

        for symbol in flattened {
            symbolByIdCache[symbol.id] = symbol
        }
        symbolRangeIndex.replaceAll(with: flattened.map { ($0.range, $0) })
    }

    private var flattenedSymbols: [DocumentSymbol] {
        if flattenedSymbolsCache.isEmpty, symbols.isEmpty == false {
            flattenedSymbolsCache = Self.flatten(symbols)
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
        Self.flatten(symbols)
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
