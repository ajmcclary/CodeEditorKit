import CodeEditorSearch
@testable import CodeEditorView
import Foundation
import Testing

@Suite("Portable project search")
struct ProjectSearchProviderTests {
    @Test("search throws ProjectSearchError.invalidRegex for malformed patterns")
    func searchSurfacesInvalidRegexError() async throws {
        let adapter = PortableProjectSearchAdapter()
        // No indexed files needed — the regex compiles before any file walk.
        do {
            _ = try await adapter.search(
                query: "[abc",
                options: ProjectSearchOptions(useRegex: true)
            )
            Issue.record("Expected ProjectSearchError.invalidRegex to be thrown")
        } catch let error as ProjectSearchError {
            guard case let .invalidRegex(pattern, _) = error else {
                Issue.record("Expected .invalidRegex, got \(error)")
                return
            }
            #expect(pattern == "[abc")
            #expect(
                error.errorDescription?.contains("[abc") == true,
                "errorDescription should include the offending pattern"
            )
        }
    }

    @Test("search skips unreadable files but continues with readable ones")
    func searchSkipsUnreadableFiles() async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        // A readable text file containing the query.
        let readableURL = rootURL.appendingPathComponent("Readable.txt")
        try "this is a needle in plain text\n".write(to: readableURL, atomically: true, encoding: .utf8)

        // A "binary" file with bytes that aren't valid UTF-8 —
        // `String(contentsOf:encoding: .utf8)` throws
        // NSFileReadInapplicableStringEncodingError on this content, which is
        // the swallowed-skip path the fix exists to log instead of swallow.
        let unreadableURL = rootURL.appendingPathComponent("Binary.bin")
        let invalidUtf8 = Data([0xFF, 0xFE, 0xFD, 0xFC, 0x00, 0x01, 0x02])
        try invalidUtf8.write(to: unreadableURL)

        let adapter = PortableProjectSearchAdapter()
        try await adapter.indexFiles(urls: [readableURL, unreadableURL])

        // Must not throw — the binary file is skipped, the text file matches.
        let results = try await adapter.search(query: "needle", options: .default)

        #expect(
            results.map(\.fileURL.lastPathComponent) == ["Readable.txt"],
            "Unreadable file must be skipped without aborting the search"
        )
    }

    @Test("search applies file extension filters to indexed files")
    func searchAppliesFileExtensionFilters() async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        let swiftURL = rootURL.appendingPathComponent("Match.swift")
        let textURL = rootURL.appendingPathComponent("Match.txt")

        try "let value = needle\n".write(to: swiftURL, atomically: true, encoding: .utf8)
        try "plain needle\n".write(to: textURL, atomically: true, encoding: .utf8)

        let adapter = PortableProjectSearchAdapter()
        try await adapter.indexFiles(urls: [swiftURL, textURL])

        let results = try await adapter.search(
            query: "needle",
            options: ProjectSearchOptions(fileExtensions: ["swift"])
        )

        #expect(results.map(\.fileURL.lastPathComponent) == ["Match.swift"])
    }

    private func withFiles(
        _ files: [String: String],
        _ body: (PortableProjectSearchAdapter, URL) async throws -> Void
    ) async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: rootURL) }
        var urls: [URL] = []
        for (name, content) in files {
            let url = rootURL.appendingPathComponent(name)
            try content.write(to: url, atomically: true, encoding: .utf8)
            urls.append(url)
        }
        let adapter = PortableProjectSearchAdapter()
        try await adapter.indexFiles(urls: urls)
        try await body(adapter, rootURL)
    }

    @Test("a regex result's matched text is what the regex matched, not the pattern's length")
    func regexMatchedText() async throws {
        try await withFiles(["a.txt": "xx fooooo yy\n"]) { adapter, _ in
            let results = try await adapter.search(query: "fo+", options: ProjectSearchOptions(useRegex: true))
            #expect(results.map(\.matchedText) == ["fooooo"])
            #expect(results.map(\.column) == [4])
        }
    }

    @Test("plain-text columns are UTF-16 columns, so the matched text lines up after an emoji")
    func plainTextColumnsAreUTF16() async throws {
        try await withFiles(["a.txt": "😀 Needle\n"]) { adapter, _ in
            let results = try await adapter.search(query: "needle", options: .default)
            #expect(results.map(\.column) == [4])
            #expect(results.map(\.matchedText) == ["Needle"])
        }
    }

    @Test("files larger than the size limit are skipped")
    func oversizedFilesAreSkipped() async throws {
        let big = String(repeating: "needle\n", count: 20)
        try await withFiles(["big.txt": big, "small.txt": "needle\n"]) { adapter, _ in
            var options = ProjectSearchOptions()
            options.maxFileSizeBytes = 32
            let results = try await adapter.search(query: "needle", options: options)
            #expect(results.map(\.fileURL.lastPathComponent) == ["small.txt"])
        }
    }

    @Test("cancelling the calling task cancels the search")
    func callerCancellationStopsTheSearch() async throws {
        let line = String(repeating: "haystack ", count: 50) + "\n"
        let files = Dictionary(uniqueKeysWithValues: (0..<200).map { ("f\($0).txt", String(repeating: line, count: 200)) })
        try await withFiles(files) { adapter, _ in
            var options = ProjectSearchOptions()
            options.maxResults = .max
            let search = Task { try await adapter.search(query: "haystack", options: options) }
            search.cancel()
            let results = try await search.value
            #expect(results.count < 200 * 200, "the search ran to completion after its caller was cancelled")
        }
    }
}
