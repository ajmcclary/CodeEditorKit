import Foundation
#if canImport(os.log)
import os.log
#endif

// MARK: - Project Search Protocol

/// Options for project-wide search.
public struct ProjectSearchOptions: Sendable {
    public var caseSensitive: Bool = false
    public var useRegex: Bool = false
    public var maxResults: Int = 200
    public var fileExtensions: [String] = []
    /// Files larger than this are skipped instead of read whole into memory.
    public var maxFileSizeBytes: Int = 8 * 1_024 * 1_024

    public init(
        caseSensitive: Bool = false,
        useRegex: Bool = false,
        maxResults: Int = 200,
        fileExtensions: [String] = [],
        maxFileSizeBytes: Int = 8 * 1_024 * 1_024
    ) {
        self.caseSensitive = caseSensitive
        self.useRegex = useRegex
        self.maxResults = maxResults
        self.fileExtensions = fileExtensions
        self.maxFileSizeBytes = maxFileSizeBytes
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
    ///
    /// - Throws: Implementation-defined indexing errors. The portable adapter
    ///   currently never throws — `throws` is declared on the protocol so
    ///   future system-backed adapters (e.g. SearchKit) can surface index
    ///   build failures without breaking source compatibility.
    func indexFiles(urls: [URL]) async throws

    /// Search the indexed files.
    ///
    /// - Throws: `ProjectSearchError.invalidRegex` if `options.useRegex` is
    ///   true and `query` does not compile as an `NSRegularExpression`.
    ///   System-backed adapters may throw additional implementation-defined
    ///   errors; individual unreadable files are logged and skipped rather
    ///   than aborting the search.
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

    #if canImport(os.log)
    /// File-skip diagnostics for `performSearch`. Search is best-effort
    /// across the workspace — files that fail to read still get skipped,
    /// but they're recorded here rather than swallowed silently.
    private static let logger = Logger(
        subsystem: "com.codeeditor.search",
        category: "ProjectSearchProvider"
    )
    #endif

    public init() {}

    /// - Throws: Never. The portable adapter only filters paths in memory;
    ///   `throws` is inherited from the protocol for future-richer-adapter
    ///   compatibility.
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
    ///
    /// - Throws: Never. See `indexFiles(urls:)` for why the signature is
    ///   `throws`.
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

    /// - Throws: `ProjectSearchError.invalidRegex` if `options.useRegex` is
    ///   true and `query` fails to compile as an `NSRegularExpression`.
    ///   Individual files that fail to decode as UTF-8 are logged and
    ///   skipped, not surfaced as a throw.
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

        // Compile the regex up-front so an invalid pattern fails fast with a
        // typed error rather than yielding silent zero-results from inside
        // the detached search task.
        let regex: NSRegularExpression?
        if options.useRegex {
            do {
                regex = try NSRegularExpression(
                    pattern: query,
                    options: options.caseSensitive ? [] : .caseInsensitive
                )
            } catch {
                throw ProjectSearchError.invalidRegex(pattern: query, underlying: error)
            }
        } else {
            regex = nil
        }

        let task = Task.detached(priority: .userInitiated) { () -> [ProjectSearchResult] in
            // swiftlint:disable:next prefer_self_in_static_references
            PortableProjectSearchAdapter.performSearch(
                query: query,
                options: opts,
                files: files,
                maxResults: opts.maxResults,
                regex: regex
            )
        }

        locked {
            searchTask = task
        }
        // The scan is detached; cancelling the caller must cancel it too.
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    nonisolated private static func performSearch(
        query: String,
        options: ProjectSearchOptions,
        files: [URL],
        maxResults: Int,
        regex: NSRegularExpression?
    ) -> [ProjectSearchResult] {
        var results: [ProjectSearchResult] = []
        let predicate = makePredicate(query: query, options: options, regex: regex)

        for fileURL in files {
            guard !Task.isCancelled, results.count < maxResults else { break }
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               size > options.maxFileSizeBytes {
                #if canImport(os.log)
                Self.logger.info("Skipping \(fileURL.path, privacy: .public): \(size) bytes is over the search size limit")
                #endif
                continue
            }
            let content: String
            do {
                content = try String(contentsOf: fileURL, encoding: .utf8)
            } catch {
                // Permissions, non-UTF-8 binary, or transient I/O failure.
                // Search is best-effort across the workspace — skip the file
                // but leave a breadcrumb so the cause isn't invisible.
                #if canImport(os.log)
                Self.logger.warning("Skipping unreadable file \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                #endif
                continue
            }

            let lines = content.components(separatedBy: "\n")
            for (idx, line) in lines.enumerated() {
                guard !Task.isCancelled, results.count < maxResults else { break }
                guard predicate(line) else { continue }

                let match = matchRange(query: query, options: options, line: line, regex: regex)
                // swiftlint:disable:next legacy_objc_type
                let matchedText = match.map { (line as NSString).substring(with: $0) } ?? query

                results.append(ProjectSearchResult(
                    fileURL: fileURL,
                    lineNumber: idx + 1,
                    column: (match?.location ?? 0) + 1,
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

    /// The first match in `line` as a UTF-16 range: the regex's own match
    /// (its length, not the pattern's), or the query found case-insensitively
    /// on the original line (lowercasing first can change UTF-16 offsets).
    nonisolated private static func matchRange(
        query: String,
        options: ProjectSearchOptions,
        line: String,
        regex: NSRegularExpression?
    ) -> NSRange? {
        if options.useRegex {
            return regex?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count))?.range
        }
        let compareOptions: String.CompareOptions = options.caseSensitive ? [] : [.caseInsensitive]
        return line.range(of: query, options: compareOptions).map { NSRange($0, in: line) }
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
