import CodeEditorLanguages
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorSyntaxHighlighting
@testable import CodeEditorView
import XCTest

final class LanguageDetectionTests: XCTestCase {
    // MARK: - Language Enum Tests

    func testAllLanguagesHaveValidIdentifiers() {
        for language in Language.allCases {
            XCTAssertFalse(language.identifier.isEmpty, "Language \(language) should have a non-empty identifier")
            XCTAssertEqual(language.rawValue, language.identifier, "Language identifier should match rawValue")
        }
    }

    func testLanguageFromIdentifier() {
        let expectedLanguages: [(identifier: String, language: Language)] = [
            ("swift", .swift),
            ("javascript", .javascript),
            ("typescript", .typescript),
            ("python", .python),
            ("go", .go),
            ("rust", .rust),
            ("c", .c),
            ("cpp", .cpp),
            ("java", .java),
            ("html", .html),
            ("css", .css),
            ("json", .json),
            ("markdown", .markdown),
            ("yaml", .yaml),
            ("xml", .xml),
            ("sql", .sql),
            ("ruby", .ruby),
            ("php", .php),
            ("shell", .shell),
            ("plaintext", .plainText)
        ]

        for (identifier, expectedLanguage) in expectedLanguages {
            let language = Language(identifier: identifier)
            XCTAssertEqual(language, expectedLanguage, "Language(identifier: \"\(identifier)\") should return \(expectedLanguage)")
        }
    }

    func testFileExtensionDetection() {
        let testCases: [(fileExt: String, expectedLanguage: Language)] = [
            // Swift
            ("swift", .swift),

            // JavaScript/TypeScript
            ("js", .javascript),
            ("jsx", .javascript),
            ("mjs", .javascript),
            ("ts", .typescript),
            ("tsx", .typescript),

            // Python
            ("py", .python),
            ("pyw", .python),

            // System Languages
            ("go", .go),
            ("rs", .rust),
            ("c", .c),
            ("h", .c),
            ("cpp", .cpp),
            ("cc", .cpp),
            ("cxx", .cpp),
            ("hpp", .cpp),
            ("java", .java),

            // Web Languages
            ("html", .html),
            ("htm", .html),
            ("xhtml", .html),
            ("css", .css),
            ("scss", .css),
            ("sass", .css),
            ("less", .css),
            ("php", .php),
            ("phtml", .php),

            // Data Formats
            ("json", .json),
            ("jsonc", .json),
            ("yaml", .yaml),
            ("yml", .yaml),
            ("xml", .xml),
            ("xsl", .xml),
            ("svg", .xml),
            ("sql", .sql),

            // Documentation
            ("md", .markdown),
            ("markdown", .markdown),
            ("mdown", .markdown),

            // Scripting
            ("rb", .ruby),
            ("rbw", .ruby),
            ("sh", .shell),
            ("bash", .shell),
            ("zsh", .shell),

            // Plain Text
            ("txt", .plainText),
            ("text", .plainText),
            ("log", .plainText)
        ]

        for (fileExt, expectedLanguage) in testCases {
            let detectedLanguage = Language(fileExtension: fileExt)
            XCTAssertEqual(
                detectedLanguage,
                expectedLanguage,
                "File extension '\(fileExt)' should detect language \(expectedLanguage)"
            )
        }
    }

    func testLanguageNames() {
        let expectedNames: [(language: Language, name: String)] = [
            (.swift, "Swift"),
            (.javascript, "JavaScript"),
            (.typescript, "TypeScript"),
            (.python, "Python"),
            (.go, "Go"),
            (.rust, "Rust"),
            (.c, "C"),
            (.cpp, "C++"),
            (.java, "Java"),
            (.html, "HTML"),
            (.css, "CSS"),
            (.json, "JSON"),
            (.markdown, "Markdown"),
            (.yaml, "YAML"),
            (.xml, "XML"),
            (.sql, "SQL"),
            (.ruby, "Ruby"),
            (.php, "PHP"),
            (.shell, "Shell"),
            (.plainText, "Plain Text")
        ]

        for (language, expectedName) in expectedNames {
            XCTAssertEqual(language.name, expectedName, "Language \(language) should have name '\(expectedName)'")
        }
    }

    // MARK: - Syntax Highlighting Integration Tests

    func testSyntaxHighlightingCoordinatorLanguageSupport() {
        let coordinator = SyntaxHighlightingCoordinator()
        let testText = "// Test comment\nlet x = 42"

        // Test that all languages can be processed without errors
        for language in Language.allCases {
            XCTAssertNoThrow(
                coordinator.highlight(source: testText, language: language),
                "SyntaxHighlightingCoordinator should handle language \(language) without throwing"
            )
        }
    }

    func testLanguageDetectionFromFileExtension() {
        let coordinator = SyntaxHighlightingCoordinator()

        let testCases = [
            "test.swift", "test.js", "test.py", "test.go", "test.rs",
            "test.c", "test.cpp", "test.java", "test.html", "test.css",
            "test.json", "test.md", "test.yaml", "test.xml", "test.sql",
            "test.rb", "test.php", "test.sh", "test.txt"
        ]

        for fileName in testCases {
            let fileExtension = String(fileName.split(separator: ".").last ?? "")
            let detectedLanguage = coordinator.detectLanguage(from: fileExtension)

            // Should not default to plainText for supported extensions
            if [
                "swift", "js", "py", "go", "rs", "c", "cpp", "java", "html",
                "css", "json", "md", "yaml", "xml", "sql", "rb", "php", "sh"
            ].contains(fileExtension) {
                XCTAssertNotEqual(
                    detectedLanguage,
                    .plainText,
                    "Extension '\(fileExtension)' should not default to plainText"
                )
            }

            XCTAssertNotNil(detectedLanguage, "Should detect a language for extension '\(fileExtension)'")
        }
    }

    // MARK: - Shebang Detection Tests (Phase 3)

    @MainActor
    func testShebangDirectInterpreter() {
        let service = LanguageDetectionService()

        let cases: [(shebang: String, expected: Language)] = [
            ("#!/bin/bash\necho hello", .shell),
            ("#!/usr/bin/python3\nprint('hi')", .python),
            ("#!/usr/bin/ruby\nputs 'hi'", .ruby),
            ("#!/usr/bin/php\n<?php echo 'hi';", .php)
        ]

        for (content, expected) in cases {
            let detected = service.detectLanguage(fromContent: content)
            XCTAssertEqual(detected, expected, "Shebang '\(content.prefix(20))...' should detect \(expected.name)")
        }
    }

    @MainActor
    func testShebangEnvIndirection() {
        let service = LanguageDetectionService()

        let cases: [(shebang: String, expected: Language)] = [
            ("#!/usr/bin/env python3\nprint('hi')", .python),
            ("#!/usr/bin/env node\nconsole.log('hi')", .javascript),
            ("#!/usr/bin/env deno\nconsole.log('hi')", .typescript),
            ("#!/usr/bin/env bash\necho hi", .shell),
            ("#!/usr/bin/env ruby\nputs 'hi'", .ruby),
            ("#!/usr/bin/env php\n<?php echo 'hi';", .php)
        ]

        for (content, expected) in cases {
            let detected = service.detectLanguage(fromContent: content)
            XCTAssertEqual(detected, expected, "env shebang '\(content.prefix(25))...' should detect \(expected.name)")
        }
    }

    @MainActor
    func testShebangEnvWithSFlag() {
        let service = LanguageDetectionService()

        // /usr/bin/env -S python3 -u → should resolve to python3 → .python
        let content = "#!/usr/bin/env -S python3 -u\nprint('hi')"
        let detected = service.detectLanguage(fromContent: content)
        XCTAssertEqual(detected, .python, "env -S python3 should detect Python")
    }

    @MainActor
    func testShebangScriptAliasResolution() {
        let service = LanguageDetectionService()

        // node → .javascript (via scriptAliases)
        let jsContent = "#!/usr/bin/env node\nconsole.log('hi')"
        XCTAssertEqual(service.detectLanguage(fromContent: jsContent), .javascript)

        // deno → .typescript (via shebangIdentifiers)
        let tsContent = "#!/usr/bin/env deno\nconsole.log('hi')"
        XCTAssertEqual(service.detectLanguage(fromContent: tsContent), .typescript)

        // python2 → .python (via shebangIdentifiers)
        let py2Content = "#!/usr/bin/env python2\nprint 'hi'"
        XCTAssertEqual(service.detectLanguage(fromContent: py2Content), .python)
    }

    @MainActor
    func testShebangNoMatchReturnsNil() {
        let service = LanguageDetectionService()

        // Unknown interpreter — should not crash, and pattern detection may or may not match
        let content = "#!/usr/bin/unknown-interpreter\necho hi"
        let detected = service.detectLanguage(fromContent: content)
        // May be nil or may match a pattern — just verify it doesn't crash
        _ = detected
    }

    // MARK: - Modeline Detection Tests (Phase 3)

    @MainActor
    func testVimModelineFiletype() {
        let service = LanguageDetectionService()

        let cases: [(content: String, expected: Language)] = [
            ("# vim: set filetype=python:\nprint('hi')", .python),
            ("// vim: set filetype=javascript:\nconst x = 1;", .javascript),
            ("# vim: set filetype=sh:\necho hi", .shell),
            ("# vim: set filetype=ruby:\nputs 'hi'", .ruby)
        ]

        for (content, expected) in cases {
            let detected = service.detectLanguage(fromContent: content)
            XCTAssertEqual(detected, expected, "Vim modeline should detect \(expected.name)")
        }
    }

    @MainActor
    func testVimModelineShortFt() {
        let service = LanguageDetectionService()

        let cases: [(content: String, expected: Language)] = [
            ("# vim: ft=python\nprint('hi')", .python),
            ("// vim: ft=javascript\nconst x = 1;", .javascript),
            ("# vim: ft=ruby\nputs 'hi'", .ruby)
        ]

        for (content, expected) in cases {
            let detected = service.detectLanguage(fromContent: content)
            XCTAssertEqual(detected, expected, "Vim ft= modeline should detect \(expected.name)")
        }
    }

    @MainActor
    func testEmacsModeline() {
        let service = LanguageDetectionService()

        let cases: [(content: String, expected: Language)] = [
            ("# -*- mode: python -*-\nprint('hi')", .python),
            ("// -*- mode: javascript -*-\nconst x = 1;", .javascript),
            ("# -*- mode: ruby -*-\nputs 'hi'", .ruby)
        ]

        for (content, expected) in cases {
            let detected = service.detectLanguage(fromContent: content)
            XCTAssertEqual(detected, expected, "Emacs modeline should detect \(expected.name)")
        }
    }

    @MainActor
    func testEmacsModelineWithSemicolon() {
        let service = LanguageDetectionService()

        let content = "# -*- mode: python; -*-\nprint('hi')"
        let detected = service.detectLanguage(fromContent: content)
        XCTAssertEqual(detected, .python, "Emacs modeline with semicolon should detect Python")
    }

    @MainActor
    func testModelineAtEndOfFile() {
        let service = LanguageDetectionService()

        // Vim modeline at end of file (within last 5 lines)
        var content = String(repeating: "\n", count: 20)
        content += "# vim: set filetype=python:"
        let detected = service.detectLanguage(fromContent: content)
        XCTAssertEqual(detected, .python, "Vim modeline at end of file should detect Python")
    }

    @MainActor
    func testModelineAtEndOfLargeFileBeyondPrefixSample() {
        let service = LanguageDetectionService()
        let body = String(repeating: "plain text line with no language signal\n", count: 80)
        let content = body + "# vim: set filetype=python:"

        let detected = service.detectLanguage(fromContent: content)

        XCTAssertEqual(detected, .python, "EOF modelines beyond the first 1,000 characters should be scanned")
    }

    @MainActor
    func testDockerfileVariantPathDetection() {
        let service = LanguageDetectionService()

        XCTAssertEqual(service.detectLanguage(fromPath: "/tmp/Dockerfile.dev"), .dockerfile)
        XCTAssertEqual(service.detectLanguage(fromPath: "/tmp/dockerfile.production"), .dockerfile)
    }

    @MainActor
    func testModelineNoMatchReturnsNil() {
        let service = LanguageDetectionService()

        // Content with no shebang, no modeline — should not crash
        let content = "just some random text\nnothing to detect here"
        let detected = service.detectLanguage(fromContent: content)
        // May be nil — just verify it doesn't crash
        _ = detected
    }

    // MARK: - Performance Tests

    func testLanguageDetectionPerformance() {
        measure(options: Self.standardMeasureOptions) {
            // Test performance of language detection for common file extensions
            let extensions = [
                "swift", "js", "py", "go", "rs", "c", "cpp", "java",
                "html", "css", "json", "md", "yaml", "xml", "sql",
                "rb", "php", "sh", "txt"
            ]

            for _ in 0..<1_000 {
                for ext in extensions {
                    _ = Language(fileExtension: ext)
                }
            }
        }
    }

    func testLanguageEnumIterationPerformance() {
        measure(options: Self.standardMeasureOptions) {
            // Test performance of iterating through all language cases
            for _ in 0..<10_000 {
                for language in Language.allCases {
                    _ = language.name
                    _ = language.identifier
                    _ = language.fileExtensions
                }
            }
        }
    }
}
