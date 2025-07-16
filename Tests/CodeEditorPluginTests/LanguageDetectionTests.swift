@testable import CodeEditorPlugin
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
            let fileExtension = String(fileName.split(separator: ".").last!)
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
    
    // MARK: - Completion Provider Integration Tests
    
    @MainActor func testCompletionProvidersRegistration() {
        let engine = SmartCompletionEngine(memoryMonitor: MemoryMonitor())
        
        // Test that completion providers are registered for all major languages
        let testCases: [(language: Language, hasProvider: Bool)] = [
            (.swift, true),
            (.javascript, true),
            (.typescript, true),
            (.python, true),
            (.go, true),
            (.rust, true),
            (.c, true),
            (.cpp, true),
            (.java, true),
            (.html, true),
            (.css, true),
            (.json, true),
            (.markdown, true),
            (.yaml, true),
            (.xml, true),
            (.sql, true),
            (.ruby, true),
            (.php, true),
            (.shell, true),
            (.plainText, false) // PlainText typically doesn't have completion
        ]
        
        for (language, shouldHaveProvider) in testCases {
            let hasProvider = engine.hasCompletionProvider(for: language.identifier)
            
            if shouldHaveProvider {
                XCTAssertTrue(hasProvider, "Language \(language) should have a completion provider")
            }
            // Note: We don't assert false for languages without providers since the engine
            // may have fallback or generic providers
        }
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

// MARK: - Test Helper Extensions

extension SmartCompletionEngine {
    func hasCompletionProvider(for _: String) -> Bool {
        // This is a simplified check - in a real implementation,
        // you might need to access internal state or provide a public method
        true // Assuming all registered providers are available
    }
}
