import CodeEditorLanguages
import LanguageKit
import XCTest

/// Tests for `LanguageDescriptor.registry` — the CEP-specific `LanguageRegistry`
/// derived from `LanguageRegistry.standard` that expresses CodeEditorPlugin's two
/// deliberate divergences (tsx→typescript, swift-grammar suppression) and its
/// richer shebang interpreter aliases as registry data rather than ad-hoc local
/// mirrors.
///
/// These pin the *construction* of the registry; observable end-to-end behavior
/// (extension/filename/shebang detection) is pinned separately by
/// `LanguageCatalogCharacterizationTests` and `LanguageDetectionTests`.
final class CEPLanguageRegistryTests: XCTestCase {
    private var registry: LanguageRegistry { LanguageDescriptor.registry }

    // MARK: - Coverage

    /// The CEP registry models exactly CodeEditorPlugin's 31 languages and does
    /// not model `tsx` as a distinct language (unlike the 32-language standard
    /// catalog).
    func testRegistryCoversEveryCEPLanguageAndOmitsTSX() {
        XCTAssertEqual(registry.languages.count, Language.allCases.count)
        for language in Language.allCases {
            XCTAssertNotNil(
                registry.metadata(for: LanguageID(rawValue: language.rawValue)),
                "CEP registry should contain metadata for \(language.rawValue)"
            )
        }
        XCTAssertNil(registry.metadata(for: .tsx), "CEP registry must not model tsx as its own language")
    }

    // MARK: - Divergence #1: tsx folds into typescript

    func testTSXExtensionResolvesToTypeScript() {
        XCTAssertEqual(registry.language(forExtension: "tsx")?.id, .typescript)
        XCTAssertEqual(registry.language(forExtension: "ts")?.id, .typescript)
    }

    func testTypeScriptExtensionsAreOrderedTSThenTSX() {
        XCTAssertEqual(registry.metadata(for: .typescript)?.fileExtensions, ["ts", "tsx"])
    }

    // MARK: - Divergence #2: swift grammar suppression

    func testSwiftGrammarIdentifierIsSuppressed() {
        let swift = registry.metadata(for: .swift)
        XCTAssertNotNil(swift)
        XCTAssertNil(swift?.treeSitterGrammarIdentifier, "Swift is highlighted via SwiftSyntax; grammar id must be nil")
    }

    /// Non-suppressed oddities carried through from the standard catalog.
    func testGrammarOdditiesPreserved() {
        XCTAssertEqual(registry.metadata(for: .shell)?.treeSitterGrammarIdentifier, "bash")
        XCTAssertEqual(registry.metadata(for: .csharp)?.treeSitterGrammarIdentifier, "c_sharp")
    }

    // MARK: - Richer interpreter aliases

    func testInterpreterAliasesResolve() {
        let cases: [(interpreter: String, id: LanguageID)] = [
            ("node", .javascript),
            ("javascript", .javascript),
            ("js", .javascript),
            ("deno", .typescript),
            ("ts-node", .typescript),
            ("python", .python),
            ("python2", .python),
            ("python3", .python),
            ("ruby", .ruby),
            ("rb", .ruby),
            ("php", .php),
            ("bash", .shell),
            ("sh", .shell),
            ("zsh", .shell),
            ("fish", .shell),
            ("lua", .lua),
            ("swift", .swift)
        ]
        for (interpreter, id) in cases {
            XCTAssertEqual(
                registry.language(forInterpreter: interpreter)?.id,
                id,
                "interpreter \"\(interpreter)\" should resolve to \(id)"
            )
        }
    }

    func testShebangLineResolutionThroughRegistry() {
        XCTAssertEqual(registry.language(forShebangLine: "#!/usr/bin/env node")?.id, .javascript)
        XCTAssertEqual(registry.language(forShebangLine: "#!/usr/bin/env -S python3 -u")?.id, .python)
        XCTAssertEqual(registry.language(forShebangLine: "#!/bin/bash")?.id, .shell)
    }

    // MARK: - Special filenames delegated to the registry

    func testFilenameRulesResolve() {
        let cases: [(filename: String, id: LanguageID)] = [
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
        for (filename, id) in cases {
            XCTAssertEqual(
                registry.language(forFilename: filename)?.id,
                id,
                "filename \"\(filename)\" should resolve to \(id)"
            )
        }
    }
}
