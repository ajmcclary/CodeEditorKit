import Foundation

extension LanguageDescriptor {
    // ── Dockerfile ─────────────────────────────────────────────────
    static let dockerfileDescriptor = Self(
            language: .dockerfile,
            displayName: "Dockerfile",
            fileExtensions: ["dockerfile"],
            lspIdentifier: "dockerfile",
            usesRegexHighlighter: true,
            lineComment: "#",
            blockCommentStart: nil,
            blockCommentEnd: nil,
            identifierPattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            stringDelimiters: ["\""],
            highlightingRules: [
                .init(#"^\s*(FROM|RUN|CMD|ENTRYPOINT|COPY|ADD|WORKDIR|ENV|ARG|EXPOSE|VOLUME|USER|LABEL|MAINTAINER|ONBUILD|STOPSIGNAL|HEALTHCHECK|SHELL)\b"#, .keyword, priority: 10),
                .init(#"\\\s*$"#, .operator, priority: 6),
                .init(#"\$\{[^}]+\}"#, .identifier, priority: 8),
                .init(#"\$[a-zA-Z_][a-zA-Z0-9_]*"#, .identifier, priority: 7),
                .init(#"--[a-zA-Z][a-zA-Z-]*(?==)"#, .property, priority: 7)
            ],
            keywords: [
                "FROM", "RUN", "CMD", "ENTRYPOINT", "COPY", "ADD", "WORKDIR", "ENV",
                "ARG", "EXPOSE", "VOLUME", "USER", "LABEL", "MAINTAINER", "ONBUILD",
                "STOPSIGNAL", "HEALTHCHECK", "SHELL", "AS"
            ],
            types: [],
            functions: [],
            literals: [],
            triggerCharacters: [" ", "$"],
            snippets: DescriptorSnippetData.dockerfile,
            memberCompletions: nil,
            commonModules: [],
            parserName: "dockerfile",
            shebangIdentifiers: [],
            scriptAliases: []
        )
}
