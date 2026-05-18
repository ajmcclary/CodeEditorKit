import Foundation

// MARK: - Project Search Protocol

/// Options for project-wide search.
public struct ProjectSearchOptions: Sendable {
    public var caseSensitive: Bool = false
    public var useRegex: Bool = false
    public var maxResults: Int = 200
    public var fileExtensions: [String] = []

    public init(
        caseSensitive: Bool = false,
        useRegex: Bool = false,
        maxResults: Int = 200,
        fileExtensions: [String] = []
    ) {
        self.caseSensitive = caseSensitive
        self.useRegex = useRegex
        self.maxResults = maxResults
        self.fileExtensions = fileExtensions
    }

    public static let `default` = Self()
}

/// A single search result from project search.
public struct ProjectSearchResult: Sendable {
    public let fileURL: URL
    public let lineNumber: Int    // 1-based
    public let column: Int        // 1-based
    public let matchedText: String
    public let contextLine: String

    public init(
        fileURL: URL,
        lineNumber: Int,
        column: Int,
        matchedText: String,
        contextLine: String
    ) {
        self.fileURL = fileURL
        self.lineNumber = lineNumber
        self.column = column
        self.matchedText = matchedText
        self.contextLine = contextLine
    }
}

// MARK: - ProjectSearchProvider

/// Protocol for project-wide full-text search.
///
/// Implementations range from simple file-walking (portable baseline)
/// to system search index integration (macOS SearchKit, if viable).
///
/// `Sendable`-conforming so callers can dispatch index/search work
/// from any isolation domain; concrete adapters take responsibility
/// for their own thread safety (`PortableProjectSearchAdapter` uses
/// an `NSLock`).
public protocol ProjectSearchProvider: AnyObject, Sendable {
    /// Index a set of file URLs. Called once before search, or
    /// incrementally as files change.
    func indexFiles(urls: [URL]) async throws

    /// Search the indexed files.
    func search(query: String, options: ProjectSearchOptions) async throws -> [ProjectSearchResult]

    /// Cancel any in-progress search.
    func cancelSearch()

    /// Clear the index.
    func clearIndex()
}

// MARK: - Portable Project Search Adapter

/// Cross-platform baseline search implementation. Walks files and
/// performs in-memory text matching. Suitable for small-to-medium
/// projects; no system dependencies.
public final class PortableProjectSearchAdapter: ProjectSearchProvider, @unchecked Sendable {
    private var indexedFiles: [URL] = []
    private var searchTask: Task<[ProjectSearchResult], Never>?
    private let lock = NSLock()
    private let fileManager = FileManager.default

    public init() {}

    public func indexFiles(urls: [URL]) async throws {
        let files = urls.filter { url in
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return false }
            return !isDir.boolValue
        }
        locked {
            indexedFiles = files
        }
    }

    /// Re-index with file extension filtering applied.
    public func indexFiles(urls: [URL], extensions: [String]) async throws {
        let extSet = Set(extensions.map { $0.lowercased() })
        let files = urls.filter { url in
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir),
                  !isDir.boolValue else { return false }
            if extSet.isEmpty { return true }
            return extSet.contains(url.pathExtension.lowercased())
        }
        locked {
            indexedFiles = files
        }
    }

    public func search(query: String, options: ProjectSearchOptions) async throws -> [ProjectSearchResult] {
        cancelSearch()
        let files: [URL] = locked {
            if options.fileExtensions.isEmpty {
                return indexedFiles
            } else {
                let extSet = Set(options.fileExtensions.map { $0.lowercased() })
                return indexedFiles.filter { extSet.contains($0.pathExtension.lowercased()) }
            }
        }
        let opts = options

        let task = Task.detached(priority: .userInitiated) { () -> [ProjectSearchResult] in
            // swiftlint:disable:next prefer_self_in_static_references
            PortableProjectSearchAdapter.performSearch(
                query: query,
                options: opts,
                files: files,
                maxResults: opts.maxResults
            )
        }

        locked {
            searchTask = task
        }
        return await task.value
    }

    nonisolated private static func performSearch(
        query: String,
        options: ProjectSearchOptions,
        files: [URL],
        maxResults: Int
    ) -> [ProjectSearchResult] {
        var results: [ProjectSearchResult] = []
        // Compile the regex once when in regex mode; otherwise nil.
        let regex: NSRegularExpression? = options.useRegex
            ? try? NSRegularExpression(
                pattern: query,
                options: options.caseSensitive ? [] : .caseInsensitive
            )
            : nil
        let predicate = makePredicate(query: query, options: options, regex: regex)

        for fileURL in files {
            guard !Task.isCancelled, results.count < maxResults else { break }
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            let lines = content.components(separatedBy: "\n")
            for (idx, line) in lines.enumerated() {
                guard !Task.isCancelled, results.count < maxResults else { break }
                guard predicate(line) else { continue }

                let column = computeColumn(query: query, options: options, line: line, regex: regex)
                let matchedText = extractMatchedText(query: query, line: line, column: column)

                results.append(ProjectSearchResult(
                    fileURL: fileURL,
                    lineNumber: idx + 1,
                    column: column,
                    matchedText: matchedText,
                    contextLine: line.trimmingCharacters(in: .whitespacesAndNewlines)
                ))
            }
        }
        return results
    }

    nonisolated private static func makePredicate(
        query: String,
        options: ProjectSearchOptions,
        regex: NSRegularExpression?
    ) -> (String) -> Bool {
        if options.useRegex {
            return { line in
                regex?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil
            }
        } else if options.caseSensitive {
            return { $0.contains(query) }
        } else {
            return { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    nonisolated private static func computeColumn(
        query: String,
        options: ProjectSearchOptions,
        line: String,
        regex: NSRegularExpression?
    ) -> Int {
        if options.useRegex {
            let range = regex?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count))?.range
            return (range?.location ?? 0) + 1
        }
        let searchLine = options.caseSensitive ? line : line.lowercased()
        let searchQuery = options.caseSensitive ? query : query.lowercased()
        if let foundRange = searchLine.range(of: searchQuery) {
            return searchLine.distance(from: searchLine.startIndex, to: foundRange.lowerBound) + 1
        }
        return 1
    }

    nonisolated private static func extractMatchedText(query: String, line: String, column: Int) -> String {
        let start = max(0, column - 1)
        let end = min(line.utf16.count, start + query.utf16.count)
        if end > start,
           let startIdx = line.utf16.index(line.utf16.startIndex, offsetBy: start, limitedBy: line.utf16.endIndex),
           let endIdx = line.utf16.index(startIdx, offsetBy: end - start, limitedBy: line.utf16.endIndex),
           let stringStart = String.Index(startIdx, within: line),
           let stringEnd = String.Index(endIdx, within: line) {
            return String(line[stringStart..<stringEnd])
        }
        return query
    }

    public func cancelSearch() {
        let task = locked {
            let task = searchTask
            searchTask = nil
            return task
        }
        task?.cancel()
    }

    public func clearIndex() {
        let task = locked {
            indexedFiles.removeAll()
            let task = searchTask
            searchTask = nil
            return task
        }
        task?.cancel()
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
