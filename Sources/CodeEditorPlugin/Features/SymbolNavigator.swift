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
    private var providers: [Language: DocumentSymbolProvider] = [:]
    private var updateTask: Task<Void, Never>?
    private let asyncOperationManager = AsyncOperationManager()

    // MARK: - Configuration

    public var configuration = SymbolNavigationConfiguration()

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

    internal func hasProvider(for language: Language) -> Bool {
        providers[language] != nil
    }

    private func setupDefaultProviders() {
        // Register default providers
        registerProvider(SwiftSymbolProvider(), for: .swift)
        registerProvider(JavaScriptSymbolProvider(), for: .javascript)
        registerProvider(JavaScriptSymbolProvider(), for: .typescript)

        // C-style languages can use the same provider
        let cStyleProvider = CStyleSymbolProvider()
        registerProvider(cStyleProvider, for: .c)
        registerProvider(cStyleProvider, for: .cpp)
        registerProvider(cStyleProvider, for: .java)
        registerProvider(cStyleProvider, for: .go)
        registerProvider(cStyleProvider, for: .rust)

        // Python indentation-based provider
        registerProvider(PythonSymbolProvider(), for: .python)

        // Markdown section provider
        registerProvider(MarkdownSymbolProvider(), for: .markdown)

        // Web technologies
        registerProvider(HTMLSymbolProvider(), for: .html)
        registerProvider(CSSSymbolProvider(), for: .css)

        // Data formats
        registerProvider(JSONSymbolProvider(), for: .json)
        registerProvider(YAMLSymbolProvider(), for: .yaml)
        registerProvider(XMLSymbolProvider(), for: .xml)

        // Databases and scripting
        registerProvider(SQLSymbolProvider(), for: .sql)
        registerProvider(RubySymbolProvider(), for: .ruby)
        registerProvider(PHPSymbolProvider(), for: .php)
        registerProvider(ShellSymbolProvider(), for: .shell)

        // Newly added languages enter through the Tree-sitter provider facade.
        // The spike delegates to heuristics today and moves to tags.scm later.
        registerProvider(TreeSitterSymbolProvider(language: .csharp), for: .csharp)
        registerProvider(TreeSitterSymbolProvider(language: .kotlin), for: .kotlin)
        registerProvider(TreeSitterSymbolProvider(language: .dart), for: .dart)
        registerProvider(TreeSitterSymbolProvider(language: .dockerfile), for: .dockerfile)
        registerProvider(TreeSitterSymbolProvider(language: .toml), for: .toml)
        registerProvider(TreeSitterSymbolProvider(language: .lua), for: .lua)
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
            return
        }
        #if canImport(AppKit)
        guard let text = textView.textStorage?.string else {
            symbols = []
            return
        }
        #else
        let text = textView.textStorage.string
        #endif

        isProcessing = true
        defer { isProcessing = false }

        // Detect symbols using provider
        let detectedSymbols = await provider.detectSymbols(in: text)

        // Build symbol tree
        let symbolTree = buildSymbolTree(from: detectedSymbols)

        // Update symbols
        symbols = symbolTree

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
                  !RangeUtilities.contains(parent.range, symbol.range) {
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
        let allSymbols = flattenSymbols(symbols)

        return allSymbols
            .filter { $0.range.location > location }
            .min { $0.range.location < $1.range.location }
    }

    private func findPreviousSymbol(before location: Int) -> DocumentSymbol? {
        let allSymbols = flattenSymbols(symbols)

        return allSymbols
            .filter { $0.range.location < location }
            .max { $0.range.location < $1.range.location }
    }

    private func flattenSymbols(_ symbols: [DocumentSymbol]) -> [DocumentSymbol] {
        var flattened: [DocumentSymbol] = []

        for symbol in symbols {
            flattened.append(symbol)
            flattened.append(contentsOf: flattenSymbols(symbol.children))
        }

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
        var breadcrumbs: [BreadcrumbItem] = []

        // Find symbols containing cursor
        var currentSymbols = symbols

        while !currentSymbols.isEmpty {
            if let containingSymbol = currentSymbols.first(where: {
                RangeUtilities.contains($0.range, NSRange(location: cursorLocation, length: 0))
            }) {
                breadcrumbs.append(BreadcrumbItem(
                    symbol: containingSymbol,
                    level: breadcrumbs.count
                ))
                currentSymbols = containingSymbol.children
            } else {
                break
            }
        }

        currentBreadcrumbs = breadcrumbs
    }

    // MARK: - Symbol Search

    /// Search symbols by name
    public func searchSymbols(query: String) -> [DocumentSymbol] {
        guard !query.isEmpty else { return flattenSymbols(symbols) }

        let fuzzyMatcher = FuzzyMatcher()
        let allSymbols = flattenSymbols(symbols)
        let symbolNames = allSymbols.map { $0.name }

        let matches = fuzzyMatcher.match(pattern: query, candidates: symbolNames)

        return matches.compactMap { match in
            allSymbols.first { $0.name == match.item }
        }
    }

    /// Get symbol at location
    public func symbol(at location: Int) -> DocumentSymbol? {
        findDeepestSymbol(containing: location, in: symbols)
    }

    private func findDeepestSymbol(containing location: Int, in symbols: [DocumentSymbol]) -> DocumentSymbol? {
        for symbol in symbols where RangeUtilities.contains(symbol.range, NSRange(location: location, length: 0)) {
            // Check children for deeper match
            if let childMatch = findDeepestSymbol(containing: location, in: symbol.children) {
                return childMatch
            }
            return symbol
        }
        return nil
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}
