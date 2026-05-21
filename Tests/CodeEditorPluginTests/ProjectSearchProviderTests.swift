import CodeEditorSearch
@testable import CodeEditorSwiftUI
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
}
