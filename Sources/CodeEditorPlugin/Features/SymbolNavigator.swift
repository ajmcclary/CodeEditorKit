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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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

// MARK: - Supporting Types

/// Document symbol representation
public struct DocumentSymbol: Identifiable {
    public let id = UUID()
    public var name: String
    public var kind: DocumentSymbolKind
    public var range: NSRange
    public var selectionRange: NSRange
    public var detail: String?
    public var children: [Self] = []
    
    public init(
        name: String,
        kind: DocumentSymbolKind,
        range: NSRange,
        selectionRange: NSRange? = nil,
        detail: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.range = range
        self.selectionRange = selectionRange ?? range
        self.detail = detail
    }
}

/// Document symbol kinds for navigation
public enum DocumentSymbolKind: String, CaseIterable {
    case file
    case module
    case namespace
    case package
    case `class`
    case method
    case property
    case field
    case constructor
    case `enum`
    case interface
    case function
    case variable
    case constant
    case string
    case number
    case boolean
    case array
    case object
    case key
    case null
    case enumMember
    case `struct`
    case event
    case `operator`
    case typeParameter
    
    var icon: String {
        switch self {
        case .file: return "📄"
        case .module: return "📦"
        case .namespace: return "🗂"
        case .package: return "📦"
        case .class: return "🏛"
        case .method: return "⚡️"
        case .property: return "🔧"
        case .field: return "📝"
        case .constructor: return "🏗"
        case .enum: return "🔢"
        case .interface: return "🔌"
        case .function: return "ƒ"
        case .variable: return "𝑥"
        case .constant: return "𝐶"
        case .string: return "\"\"" 
        case .number: return "#"
        case .boolean: return "◉"
        case .array: return "[]"
        case .object: return "{}"
        case .key: return "🔑"
        case .null: return "∅"
        case .enumMember: return "•"
        case .struct: return "◼︎"
        case .event: return "⚡"
        case .operator: return "±"
        case .typeParameter: return "𝑇"
        }
    }
    
    var canContainSymbols: Bool {
        switch self {
        case .file, .module, .namespace, .package, .class,
             .interface, .struct, .object, .enum:
            return true

        default:
            return false
        }
    }
}

/// Breadcrumb item
public struct BreadcrumbItem: Identifiable {
    public let id = UUID()
    public let symbol: DocumentSymbol
    public let level: Int
}

/// Symbol navigation configuration
public struct SymbolNavigationConfiguration {
    public var enabled = true
    public var showInGutter = true
    public var showBreadcrumbs = true
    public var maxBreadcrumbItems = 5
    public var updateDelay: TimeInterval = 0.3
    public var includeAnonymousSymbols = false
}

/// Protocol for language-specific symbol providers
public protocol DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol]
}

// MARK: - Default Providers

/// Swift symbol provider
struct SwiftSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Simple pattern matching for Swift
            if let symbol = detectSwiftSymbol(in: trimmed, at: currentLocation, line: lineIndex, fullLine: line) {
                symbols.append(symbol)
            }
            
            currentLocation += line.count + 1 // +1 for newline
        }
        
        return symbols
    }
    
    private func detectSwiftSymbol(in line: String, at location: Int, line _: Int, fullLine: String) -> DocumentSymbol? {
        // Class detection
        if line.hasPrefix("class ") || line.hasPrefix("final class ") {
            return extractSymbol(from: line, prefix: "class", kind: .class, at: location, fullLine: fullLine)
        }
        
        // Struct detection
        if line.hasPrefix("struct ") {
            return extractSymbol(from: line, prefix: "struct", kind: .struct, at: location, fullLine: fullLine)
        }
        
        // Enum detection
        if line.hasPrefix("enum ") {
            return extractSymbol(from: line, prefix: "enum", kind: .enum, at: location, fullLine: fullLine)
        }
        
        // Protocol detection
        if line.hasPrefix("protocol ") {
            return extractSymbol(from: line, prefix: "protocol", kind: .interface, at: location, fullLine: fullLine)
        }
        
        // Function detection
        if line.hasPrefix("func ") || line.contains(" func ") {
            let prefix = line.hasPrefix("func ") ? "func" : String(line.prefix { $0 != "f" }) + "func"
            return extractSymbol(from: line, prefix: prefix, kind: .function, at: location, fullLine: fullLine)
        }
        
        // Property detection
        if line.hasPrefix("var ") || line.hasPrefix("let ") {
            let prefix = line.hasPrefix("var ") ? "var" : "let"
            let kind: DocumentSymbolKind = line.hasPrefix("let ") ? .constant : .variable
            return extractSymbol(from: line, prefix: prefix, kind: kind, at: location, fullLine: fullLine)
        }
        
        return nil
    }
    
    private func extractSymbol(from line: String, prefix: String, kind: DocumentSymbolKind, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Extract name after prefix
        let afterPrefix = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        let name = afterPrefix.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
        
        guard !name.isEmpty else { return nil }
        
        // Calculate selection range (just the name)
        let nameStart = fullLine.range(of: String(name))?.lowerBound
        let selectionStart = nameStart.map { fullLine.distance(from: fullLine.startIndex, to: $0) } ?? 0
        
        return DocumentSymbol(
            name: String(name),
            kind: kind,
            range: NSRange(location: location, length: fullLine.count),
            selectionRange: NSRange(location: location + selectionStart, length: name.count),
            detail: line
        )
    }
}

/// JavaScript/TypeScript symbol provider
struct JavaScriptSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if let symbol = detectJavaScriptSymbol(in: trimmed, at: currentLocation, line: lineIndex, fullLine: line) {
                symbols.append(symbol)
            }
            
            currentLocation += line.count + 1
        }
        
        return symbols
    }
    
    private func detectJavaScriptSymbol(in line: String, at location: Int, line _: Int, fullLine: String) -> DocumentSymbol? {
        // Function detection
        if line.hasPrefix("function ") || line.contains("= function") || line.contains("=> {") {
            return extractJSFunction(from: line, at: location, fullLine: fullLine)
        }
        
        // Class detection
        if line.hasPrefix("class ") {
            return extractSymbol(from: line, prefix: "class", kind: .class, at: location, fullLine: fullLine)
        }
        
        // Const/let/var detection
        if line.hasPrefix("const ") || line.hasPrefix("let ") || line.hasPrefix("var ") {
            let prefix = line.hasPrefix("const ") ? "const" : (line.hasPrefix("let ") ? "let" : "var")
            let kind: DocumentSymbolKind = line.hasPrefix("const ") ? .constant : .variable
            return extractSymbol(from: line, prefix: prefix, kind: kind, at: location, fullLine: fullLine)
        }
        
        return nil
    }
    
    private func extractJSFunction(from line: String, at location: Int, fullLine: String) -> DocumentSymbol? {
        // Extract function name
        var name = ""
        
        if line.hasPrefix("function ") {
            let afterFunction = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            name = String(afterFunction.prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "$" })
        } else if line.contains("= function") {
            // Extract name before = function
            if let eqIndex = line.firstIndex(of: "=") {
                let beforeEq = String(line.prefix(upTo: eqIndex)).trimmingCharacters(in: .whitespaces)
                name = beforeEq.components(separatedBy: .whitespaces).last ?? ""
            }
        } else if line.contains("=>") {
            // Arrow function
            if let arrowIndex = line.range(of: "=>") {
                let beforeArrow = String(line.prefix(upTo: arrowIndex.lowerBound)).trimmingCharacters(in: .whitespaces)
                name = beforeArrow.components(separatedBy: .whitespaces).last ?? ""
            }
        }
        
        guard !name.isEmpty else { return nil }
        
        return DocumentSymbol(
            name: name,
            kind: .function,
            range: NSRange(location: location, length: fullLine.count),
            detail: line
        )
    }
    
    private func extractSymbol(from line: String, prefix: String, kind: DocumentSymbolKind, at location: Int, fullLine: String) -> DocumentSymbol? {
        let afterPrefix = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        let name = afterPrefix.prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "$" }
        
        guard !name.isEmpty else { return nil }
        
        return DocumentSymbol(
            name: String(name),
            kind: kind,
            range: NSRange(location: location, length: fullLine.count),
            detail: line
        )
    }
}

/// Python symbol provider
struct PythonSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0
        
        for (lineIndex, line) in lines.enumerated() {
            if let symbol = detectPythonSymbol(in: line, at: currentLocation, line: lineIndex) {
                symbols.append(symbol)
            }
            
            currentLocation += line.count + 1
        }
        
        return symbols
    }
    
    private func detectPythonSymbol(in line: String, at location: Int, line _: Int) -> DocumentSymbol? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Class detection
        if trimmed.hasPrefix("class ") {
            return extractPythonSymbol(from: trimmed, prefix: "class", kind: .class, at: location, fullLine: line)
        }
        
        // Function detection
        if trimmed.hasPrefix("def ") || trimmed.hasPrefix("async def ") {
            let prefix = trimmed.hasPrefix("async def ") ? "async def" : "def"
            return extractPythonSymbol(from: trimmed, prefix: prefix, kind: .function, at: location, fullLine: line)
        }
        
        return nil
    }
    
    private func extractPythonSymbol(from line: String, prefix: String, kind: DocumentSymbolKind, at location: Int, fullLine: String) -> DocumentSymbol? {
        let afterPrefix = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        let name = afterPrefix.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
        
        guard !name.isEmpty else { return nil }
        
        return DocumentSymbol(
            name: String(name),
            kind: kind,
            range: NSRange(location: location, length: fullLine.count),
            detail: line
        )
    }
}

/// C-style language symbol provider
struct CStyleSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0
        
        for (lineIndex, line) in lines.enumerated() {
            if let symbol = detectCStyleSymbol(in: line, at: currentLocation, line: lineIndex) {
                symbols.append(symbol)
            }
            
            currentLocation += line.count + 1
        }
        
        return symbols
    }
    
    private func detectCStyleSymbol(in line: String, at location: Int, line _: Int) -> DocumentSymbol? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Function detection (simplified)
        if trimmed.contains("(") && trimmed.contains(")") && !trimmed.hasPrefix("//") && !trimmed.hasPrefix("/*") {
            // Try to extract function name
            if let parenIndex = trimmed.firstIndex(of: "(") {
                let beforeParen = trimmed[..<parenIndex].trimmingCharacters(in: .whitespaces)
                let parts = beforeParen.split(separator: " ")
                if let lastPart = parts.last, !lastPart.isEmpty {
                    return DocumentSymbol(
                        name: String(lastPart),
                        kind: .function,
                        range: NSRange(location: location, length: line.count),
                        detail: line
                    )
                }
            }
        }
        
        // Class/struct detection
        if trimmed.hasPrefix("class ") || trimmed.hasPrefix("struct ") {
            let prefix = trimmed.hasPrefix("class ") ? "class" : "struct"
            return extractCStyleSymbol(from: trimmed, prefix: prefix, kind: .class, at: location, fullLine: line)
        }
        
        return nil
    }
    
    private func extractCStyleSymbol(from line: String, prefix: String, kind: DocumentSymbolKind, at location: Int, fullLine: String) -> DocumentSymbol? {
        let afterPrefix = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        let name = afterPrefix.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
        
        guard !name.isEmpty else { return nil }
        
        return DocumentSymbol(
            name: String(name),
            kind: kind,
            range: NSRange(location: location, length: fullLine.count),
            detail: line
        )
    }
}

/// Markdown symbol provider
struct MarkdownSymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in text: String) async -> [DocumentSymbol] {
        var symbols: [DocumentSymbol] = []
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0
        
        for (lineIndex, line) in lines.enumerated() {
            if let symbol = detectMarkdownSymbol(in: line, at: currentLocation, line: lineIndex) {
                symbols.append(symbol)
            }
            
            currentLocation += line.count + 1
        }
        
        return symbols
    }
    
    private func detectMarkdownSymbol(in line: String, at location: Int, line _: Int) -> DocumentSymbol? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Header detection
        if trimmed.hasPrefix("#") {
            let level = trimmed.prefix { $0 == "#" }.count
            if level >= 1 && level <= 6 {
                let headerText = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                
                return DocumentSymbol(
                    name: headerText,
                    kind: level == 1 ? .module : .namespace,
                    range: NSRange(location: location, length: line.count),
                    detail: "Level \(level) heading"
                )
            }
        }
        
        return nil
    }
}
