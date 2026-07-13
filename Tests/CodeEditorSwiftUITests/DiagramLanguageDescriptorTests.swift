import CodeEditorLanguages
@testable import CodeEditorSyntaxHighlighting
import Testing

/// Covers the diagram-DSL language cohort (Mermaid, D2, DOT, Structurizr,
/// PlantUML) added for DiagramKit's editor migration: every case must have a
/// descriptor, and the regex pipeline must compile a working definition that
/// tokenizes representative source.
@Suite("Diagram language descriptors")
struct DiagramLanguageDescriptorTests {
    private static let diagramLanguages: [Language] = [
        .mermaid, .d2, .dot, .structurizr, .plantuml
    ]

    @Test("Every Language case has a registered descriptor")
    func descriptorCatalogCoversAllCases() {
        for language in Language.allCases {
            #expect(
                LanguageDescriptor.descriptor(for: language) != nil,
                "missing descriptor for \(language)"
            )
        }
        #expect(LanguageDescriptor.allDescriptors.count == Language.allCases.count)
    }

    @Test("Diagram DSLs route through the regex highlighter")
    func diagramLanguagesUseRegexPipeline() {
        for language in Self.diagramLanguages {
            let descriptor = LanguageDescriptor.descriptor(for: language)
            #expect(descriptor?.usesRegexHighlighter == true, "\(language)")
        }
    }

    @Test("Regex definitions compile and tokenize representative source")
    @MainActor
    func definitionsTokenizeRepresentativeSource() {
        let samples: [Language: String] = [
            .mermaid: """
            flowchart LR
                %% comment
                a["Node"] --> b
            """,
            .d2: """
            # comment
            direction: right
            a -> b: "label"
            """,
            .dot: """
            // comment
            digraph g { a -> b [label="edge"]; }
            """,
            .structurizr: """
            // comment
            workspace {
                model { a = person "User" }
            }
            """,
            .plantuml: """
            @startuml
            ' comment
            actor User
            User --> System: "request"
            @enduml
            """
        ]

        let highlighter = RegexSyntaxHighlighter()
        for (language, source) in samples {
            guard let definition = highlighter.languageDefinition(for: language) else {
                Issue.record("no regex language definition for \(language)")
                continue
            }
            let scoped = RegexSyntaxHighlighter(customLanguage: definition)
            let tokens = scoped.highlight(source: source)
            #expect(!tokens.isEmpty, "expected tokens for \(language)")
            let kinds = Set(tokens.map(\.type))
            #expect(kinds.contains(.keyword) || kinds.contains(.type), "\(language) keywords")
            #expect(kinds.contains(.comment), "\(language) comments")
        }
    }
}
