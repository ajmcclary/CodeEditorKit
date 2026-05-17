import CodeEditorLanguages
import Foundation

/// Catalog of document-symbol providers keyed by language.
public struct SymbolProviderCatalog: Sendable {
    private var providers: [Language: any DocumentSymbolProvider]

    public init(providers: [Language: any DocumentSymbolProvider] = [:]) {
        self.providers = providers
    }

    public static var `default`: Self {
        var catalog = Self()
        catalog.registerDefaultProviders()
        return catalog
    }

    public func provider(for language: Language) -> (any DocumentSymbolProvider)? {
        providers[language]
    }

    public func hasProvider(for language: Language) -> Bool {
        providers[language] != nil
    }

    public mutating func registerProvider(_ provider: any DocumentSymbolProvider, for language: Language) {
        providers[language] = provider
    }

    private mutating func registerDefaultProviders() {
        registerProvider(SwiftSymbolProvider(), for: .swift)
        registerProvider(JavaScriptSymbolProvider(), for: .javascript)
        registerProvider(JavaScriptSymbolProvider(), for: .typescript)

        let cStyleProvider = CStyleSymbolProvider()
        for language in [Language.c, .cpp, .java, .go, .rust, .csharp, .kotlin, .dart] {
            registerProvider(cStyleProvider, for: language)
        }

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

        registerProvider(HeuristicSymbolProviderFacade(language: .dockerfile), for: .dockerfile)
        registerProvider(HeuristicSymbolProviderFacade(language: .toml), for: .toml)
        registerProvider(HeuristicSymbolProviderFacade(language: .lua), for: .lua)
        registerProvider(EmptySymbolProvider(), for: .plainText)
    }
}

private struct EmptySymbolProvider: DocumentSymbolProvider {
    func detectSymbols(in _: String) async -> [DocumentSymbol] {
        []
    }
}

final class SymbolRangeIndex<Value> {
    private final class Node {
        let range: NSRange
        let value: Value
        var maxUpperBound: Int
        var left: Node?
        var right: Node?

        init(range: NSRange, value: Value) {
            self.range = range
            self.value = value
            self.maxUpperBound = NSMaxRange(range)
        }
    }

    private var root: Node?

    func insert(range: NSRange, value: Value) {
        root = insert(range: range, value: value, into: root)
    }

    func findContaining(location: Int) -> [Value] {
        var results: [Value] = []
        findContaining(location: location, in: root, results: &results)
        return results
    }

    func removeAll() {
        root = nil
    }

    private func insert(range: NSRange, value: Value, into node: Node?) -> Node {
        guard let node else {
            return Node(range: range, value: value)
        }

        if range.location < node.range.location {
            node.left = insert(range: range, value: value, into: node.left)
        } else {
            node.right = insert(range: range, value: value, into: node.right)
        }

        node.maxUpperBound = max(node.maxUpperBound, NSMaxRange(range))
        return node
    }

    private func findContaining(location: Int, in node: Node?, results: inout [Value]) {
        guard let node else { return }

        if let left = node.left, left.maxUpperBound >= location {
            findContaining(location: location, in: left, results: &results)
        }

        if node.range.location <= location, location <= NSMaxRange(node.range) {
            results.append(node.value)
        }

        if location >= node.range.location {
            findContaining(location: location, in: node.right, results: &results)
        }
    }
}
