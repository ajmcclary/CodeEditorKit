import CodeEditorLanguages
import XCTest

/// Characterization tests pinning the CURRENT `LanguageDescriptor` catalog
/// (`Sources/CodeEditorLanguages/LanguageDescriptor.swift`) ahead of the
/// planned LanguageKit extraction (workspace-reorg Task 7).
///
/// These tests assert what the catalog IS today, oddities included. They are
/// not a statement of what the catalog *should* be -- do not "fix" a
/// mismatch surfaced here without a deliberate, separate production change
/// (and an update to this file to match).
///
/// The expected table is an inline literal so a future diff (when this data
/// moves to `LanguageKit`) is reviewable line-by-line.
final class LanguageCatalogCharacterizationTests: XCTestCase {
    deinit {}

    /// One row per registered `Language` case, in `LanguageDescriptor.allDescriptors` order.
    ///
    /// - `id`: `Language.rawValue` (the plugin identifier).
    /// - `displayName`: `LanguageDescriptor.displayName`.
    /// - `fileExtensions`: `LanguageDescriptor.fileExtensions`, order-sensitive (it's the same
    ///   array `Language.fileExtensions` returns and that `Language.init(fileExtension:)`
    ///   scans in order).
    /// - `lspIdentifier`: `LanguageDescriptor.lspIdentifier`.
    /// - `parserName`: the tree-sitter/grammar identifier, if any (`nil` for languages with no
    ///   tree-sitter grammar wired -- Swift uses SwiftSyntax instead, and the five diagram DSLs
    ///   plus Plain Text have no grammar at all).
    private struct ExpectedRow: Equatable {
        let id: String
        let displayName: String
        let fileExtensions: [String]
        let lspIdentifier: String
        let parserName: String?
    }

    // swiftlint:disable line_length
    private static let expected: [ExpectedRow] = [
        .init(id: "swift", displayName: "Swift", fileExtensions: ["swift"], lspIdentifier: "swift", parserName: nil),
        .init(id: "javascript", displayName: "JavaScript", fileExtensions: ["js", "jsx", "mjs"], lspIdentifier: "javascript", parserName: "javascript"),
        .init(id: "typescript", displayName: "TypeScript", fileExtensions: ["ts", "tsx"], lspIdentifier: "typescript", parserName: "typescript"),
        .init(id: "python", displayName: "Python", fileExtensions: ["py", "pyw"], lspIdentifier: "python", parserName: "python"),
        .init(id: "go", displayName: "Go", fileExtensions: ["go"], lspIdentifier: "go", parserName: "go"),
        .init(id: "rust", displayName: "Rust", fileExtensions: ["rs"], lspIdentifier: "rust", parserName: "rust"),
        .init(id: "c", displayName: "C", fileExtensions: ["c", "h"], lspIdentifier: "c", parserName: "c"),
        .init(id: "cpp", displayName: "C++", fileExtensions: ["cpp", "cc", "cxx", "hpp", "hh", "hxx"], lspIdentifier: "cpp", parserName: "cpp"),
        .init(id: "java", displayName: "Java", fileExtensions: ["java"], lspIdentifier: "java", parserName: "java"),
        .init(id: "html", displayName: "HTML", fileExtensions: ["html", "htm", "xhtml"], lspIdentifier: "html", parserName: "html"),
        .init(id: "css", displayName: "CSS", fileExtensions: ["css", "scss", "sass", "less"], lspIdentifier: "css", parserName: "css"),
        .init(id: "json", displayName: "JSON", fileExtensions: ["json", "jsonc"], lspIdentifier: "json", parserName: "json"),
        .init(id: "markdown", displayName: "Markdown", fileExtensions: ["md", "markdown", "mdown", "mkd"], lspIdentifier: "markdown", parserName: "markdown"),
        .init(id: "yaml", displayName: "YAML", fileExtensions: ["yaml", "yml"], lspIdentifier: "yaml", parserName: "yaml"),
        .init(id: "xml", displayName: "XML", fileExtensions: ["xml", "xsl", "xslt", "svg"], lspIdentifier: "xml", parserName: "xml"),
        .init(id: "sql", displayName: "SQL", fileExtensions: ["sql"], lspIdentifier: "sql", parserName: "sql"),
        .init(id: "ruby", displayName: "Ruby", fileExtensions: ["rb", "rbw"], lspIdentifier: "ruby", parserName: "ruby"),
        .init(id: "php", displayName: "PHP", fileExtensions: ["php", "phtml", "php3", "php4", "php5"], lspIdentifier: "php", parserName: "php"),
        // Oddity: parserName is "bash" (the tree-sitter grammar id), not "shell" -- the
        // Language id and the grammar id diverge for this one entry.
        .init(id: "shell", displayName: "Shell", fileExtensions: ["sh", "bash", "zsh", "fish"], lspIdentifier: "shellscript", parserName: "bash"),
        // Oddity: "dockerfile" is registered as a *file extension* (a file named
        // `foo.dockerfile` matches here), which is unusual -- the far more common real-world
        // case (a file literally named `Dockerfile`, no extension) is handled separately by
        // `LanguageDetectionService.detectLanguage(fromFilename:)`, see below.
        .init(id: "dockerfile", displayName: "Dockerfile", fileExtensions: ["dockerfile"], lspIdentifier: "dockerfile", parserName: "dockerfile"),
        .init(id: "toml", displayName: "TOML", fileExtensions: ["toml"], lspIdentifier: "toml", parserName: "toml"),
        .init(id: "lua", displayName: "Lua", fileExtensions: ["lua"], lspIdentifier: "lua", parserName: "lua"),
        // Oddity: parserName uses an underscore ("c_sharp", the tree-sitter grammar's actual
        // name) while the Language id and lspIdentifier use "csharp".
        .init(id: "csharp", displayName: "C#", fileExtensions: ["cs"], lspIdentifier: "csharp", parserName: "c_sharp"),
        .init(id: "kotlin", displayName: "Kotlin", fileExtensions: ["kt", "kts"], lspIdentifier: "kotlin", parserName: "kotlin"),
        .init(id: "dart", displayName: "Dart", fileExtensions: ["dart"], lspIdentifier: "dart", parserName: "dart"),
        .init(id: "mermaid", displayName: "Mermaid", fileExtensions: ["mmd", "mermaid"], lspIdentifier: "mermaid", parserName: nil),
        .init(id: "d2", displayName: "D2", fileExtensions: ["d2"], lspIdentifier: "d2", parserName: nil),
        .init(id: "dot", displayName: "Graphviz DOT", fileExtensions: ["dot", "gv"], lspIdentifier: "dot", parserName: nil),
        .init(id: "structurizr", displayName: "Structurizr DSL", fileExtensions: ["dsl"], lspIdentifier: "structurizr", parserName: nil),
        .init(id: "plantuml", displayName: "PlantUML", fileExtensions: ["puml", "plantuml", "pu"], lspIdentifier: "plantuml", parserName: nil),
        .init(id: "plaintext", displayName: "Plain Text", fileExtensions: ["txt", "text", "log"], lspIdentifier: "plaintext", parserName: nil)
    ]
    // swiftlint:enable line_length

    /// The full catalog, in declaration order, matches the literal table above exactly.
    ///
    /// This is the primary characterization: 31 registered languages (30 concrete + Plain
    /// Text) -- if a language is added, removed, renamed, or has its extensions/grammar id
    /// changed, this test fails with a reviewable diff.
    func testCompleteCatalogMatchesLiteralExpectedTable() {
        let actual = LanguageDescriptor.allDescriptors.map {
            ExpectedRow(
                id: $0.language.rawValue,
                displayName: $0.displayName,
                fileExtensions: $0.fileExtensions,
                lspIdentifier: $0.lspIdentifier,
                parserName: $0.parserName
            )
        }
        XCTAssertEqual(actual, Self.expected)
    }

    /// `LanguageDescriptor.all` (the `[Language: Self]` lookup dictionary) has exactly one
    /// entry per `Language` case, and every entry's descriptor is identical (by displayName,
    /// a cheap proxy for full-struct identity given `LanguageDescriptor` isn't `Equatable`) to
    /// the one found by iterating `Language.allCases` and `allDescriptors`.
    func testAllDescriptorsDictionaryCoversEveryLanguageCase() {
        XCTAssertEqual(LanguageDescriptor.all.count, Language.allCases.count)
        XCTAssertEqual(LanguageDescriptor.all.count, LanguageDescriptor.allDescriptors.count)

        for language in Language.allCases {
            guard let descriptor = LanguageDescriptor.all[language] else {
                XCTFail("No descriptor registered for Language.\(language)")
                continue
            }
            XCTAssertEqual(descriptor.language, language)
        }
    }

    /// `Language.name` / `.fileExtensions` / `.lspIdentifier` delegate to the descriptor
    /// catalog (see `Language.swift`), so this is redundant with the table above by
    /// construction today -- it's here so a future refactor that breaks that delegation
    /// (rather than the underlying data) still fails a test.
    func testLanguageComputedPropertiesDelegateToDescriptorCatalog() {
        for row in Self.expected {
            guard let language = Language(rawValue: row.id) else {
                XCTFail("Language.rawValue \(row.id) from the expected table doesn't exist on Language")
                continue
            }
            XCTAssertEqual(language.name, row.displayName)
            XCTAssertEqual(language.fileExtensions, row.fileExtensions)
            XCTAssertEqual(language.lspIdentifier, row.lspIdentifier)
        }
    }

    // MARK: - Special filenames (`LanguageDetectionService.detectLanguage(fromFilename:)`)

    /// The extension-registry above only covers extension-based detection. A second,
    /// independent mechanism -- `LanguageDetectionService.detectLanguage(fromFilename:)`,
    /// a `switch` over the full lowercased filename -- maps specific well-known filenames
    /// (with no, or a non-language-indicating, extension) to a `Language`. Pin its complete
    /// literal table too.
    ///
    /// Oddities preserved as-is (not fixed):
    /// - `makefile` / `gnumakefile` map to `.shell`, even though Makefile syntax isn't shell.
    /// - `rakefile` / `gemfile` / `podfile` all map to `.ruby` (all three are literally Ruby
    ///   DSLs, so this one is arguably correct, just worth noting as a many-to-one grouping).
    /// - `readme` / `license` / `changelog` (no extension) all map to `.markdown`, even though
    ///   plenty of real-world README/LICENSE/CHANGELOG files are plain text, not Markdown.
    /// - `.gitignore` / `.dockerignore` explicitly map to `.plainText` -- redundant with the
    ///   `default: return .plainText` case, but written out explicitly anyway.
    /// - `dockerfile` matching is a prefix match (`name == "dockerfile" || name.hasPrefix("dockerfile.")`),
    ///   not an exact-match `case`, unlike every other entry in the switch.
    @MainActor
    func testSpecialFilenameRegistryMatchesLiteralExpectedTable() {
        let service = LanguageDetectionService()

        let expectedExactFilenames: [(filename: String, language: Language)] = [
            ("dockerfile", .dockerfile),
            ("makefile", .shell),
            ("gnumakefile", .shell),
            ("rakefile", .ruby),
            ("gemfile", .ruby),
            ("podfile", .ruby),
            ("package.json", .json),
            ("tsconfig.json", .json),
            (".gitignore", .plainText),
            (".dockerignore", .plainText),
            ("readme", .markdown),
            ("license", .markdown),
            ("changelog", .markdown)
        ]

        for (filename, expectedLanguage) in expectedExactFilenames {
            XCTAssertEqual(
                service.detectLanguage(fromFilename: filename),
                expectedLanguage,
                "detectLanguage(fromFilename: \"\(filename)\") should return \(expectedLanguage)"
            )
        }

        // "dockerfile.<anything>" is a prefix match, not an exact filename -- pin a
        // representative case distinct from the bare "dockerfile" case above.
        XCTAssertEqual(service.detectLanguage(fromFilename: "dockerfile.dev"), .dockerfile)
        XCTAssertEqual(service.detectLanguage(fromFilename: "dockerfile.production"), .dockerfile)

        // The switch lowercases the filename first, so matching is case-insensitive.
        XCTAssertEqual(service.detectLanguage(fromFilename: "Dockerfile"), .dockerfile)
        XCTAssertEqual(service.detectLanguage(fromFilename: "Makefile"), .shell)
        XCTAssertEqual(service.detectLanguage(fromFilename: "README"), .markdown)

        // Anything not in the switch (and not matched by the "dockerfile." prefix) falls
        // through to the default case, .plainText.
        XCTAssertEqual(service.detectLanguage(fromFilename: "random.xyz"), .plainText)
        XCTAssertEqual(service.detectLanguage(fromFilename: "CMakeLists.txt"), .plainText)
    }
}
