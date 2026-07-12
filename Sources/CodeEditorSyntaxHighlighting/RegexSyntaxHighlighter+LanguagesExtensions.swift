import CodeEditorCommon
import CodeEditorLanguages
import Foundation

// MARK: - Language Definition Factory Methods

extension RegexSyntaxHighlighter {
    /// Constructs a HighlightRule, logging a fault and returning nil if the
    /// pattern fails to compile. In debug builds an `assertionFailure` surfaces
    /// the broken pattern so it gets fixed before shipping; in release the
    /// rule is dropped and highlighting continues with the remaining rules.
    package static func rule(
        _ pattern: String,
        _ tokenType: RegexSyntaxTokenType,
        _ priority: Int = 0,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> RegexHighlightRule? {
        do {
            return try RegexHighlightRule(pattern: pattern, tokenType: tokenType, priority: priority)
        } catch {
            Self.logger.fault(
                "RegexSyntaxHighlighter: failed to compile pattern \"\(pattern)\": \(error.localizedDescription)"
            )
            assertionFailure(
                "RegexSyntaxHighlighter: failed to compile pattern \"\(pattern)\": \(error)",
                file: file,
                line: line
            )
            return nil
        }
    }

    package static func createLanguageDefinitions() -> [String: RegexLanguageDefinition] {
        var languages: [String: RegexLanguageDefinition] = [:]

        for descriptor in LanguageDescriptor.allDescriptors where descriptor.usesRegexHighlighter {
            languages[descriptor.lspIdentifier] = createDefinition(from: descriptor)
        }

        return languages
    }

    /// Create efficient Language enum to LanguageDefinition mapping.
    package static func createLanguageMap(from definitions: [String: RegexLanguageDefinition]) -> [Language: RegexLanguageDefinition] {
        var languageMap: [Language: RegexLanguageDefinition] = [:]

        for descriptor in LanguageDescriptor.allDescriptors where descriptor.usesRegexHighlighter {
            languageMap[descriptor.language] = definitions[descriptor.lspIdentifier]
        }

        return languageMap
    }

    private static func createDefinition(from descriptor: LanguageDescriptor) -> RegexLanguageDefinition {
        var builder = LanguageDefinitionBuilder()

        builder = builder.addComments(
            singleLine: descriptor.lineComment,
            multiLineStart: descriptor.blockCommentStart,
            multiLineEnd: descriptor.blockCommentEnd
        )

        builder = builder.addStrings(
            single: descriptor.stringDelimiters.contains("'"),
            double: descriptor.stringDelimiters.contains("\""),
            backtick: descriptor.stringDelimiters.contains("`")
        )

        builder = builder.addNumbers(pattern: numberPattern(for: descriptor))

        let caseFlag = descriptor.caseInsensitiveKeywords ? "(?i)" : ""

        let keywordTerms = descriptor.keywords + descriptor.literals
        if !keywordTerms.isEmpty {
            builder = builder.addCustomRule(
                pattern: caseFlag + wordPattern(for: keywordTerms),
                type: .keyword,
                priority: 7
            )
        }

        if !descriptor.types.isEmpty {
            builder = builder.addCustomRule(
                pattern: caseFlag + wordPattern(for: descriptor.types),
                type: .type,
                priority: 7
            )
        }

        if !descriptor.functions.isEmpty {
            builder = builder.addCustomRule(
                pattern: caseFlag + wordPattern(for: descriptor.functions),
                type: .function,
                priority: 7
            )
        }

        builder = builder.addFunctionCalls(pattern: functionCallPattern(for: descriptor))
        builder = builder.addOperators(pattern: operatorPattern(for: descriptor))

        for rule in descriptor.highlightingRules {
            builder = builder.addCustomRule(
                pattern: rule.pattern,
                type: rule.tokenType,
                priority: rule.priority
            )
        }

        return builder.build(name: descriptor.displayName, fileExtensions: descriptor.fileExtensions)
    }

    private static func wordPattern(for terms: [String]) -> String {
        let escaped = terms
            .filter { !$0.isEmpty }
            .map(NSRegularExpression.escapedPattern(for:))
            .sorted { $0.count > $1.count }
            .joined(separator: "|")

        return #"(?<![A-Za-z0-9_])("# + escaped + #")(?![A-Za-z0-9_])"#
    }

    private static func numberPattern(for descriptor: LanguageDescriptor) -> String {
        switch descriptor.language {
        case .c, .cpp:
            #"\b\d+\.?\d*[fFlL]?\b"#

        case .java:
            #"\b\d+\.?\d*[fFlLdD]?\b"#

        default:
            #"\b\d+\.?\d*\b"#
        }
    }

    private static func functionCallPattern(for descriptor: LanguageDescriptor) -> String {
        switch descriptor.language {
        case .css, .html, .xml, .yaml, .toml, .markdown, .dockerfile:
            #"(?!)"#

        default:
            #"\b\w+(?=\s*\()"#
        }
    }

    private static func operatorPattern(for descriptor: LanguageDescriptor) -> String {
        switch descriptor.language {
        case .shell:
            #"[|&;<>()]+"#

        case .sql:
            #"[+\-*/%=<>!]+"#

        case .html, .xml, .yaml, .toml, .markdown:
            #"(?!)"#

        default:
            #"[+\-*/%=<>!&|^~?:]+"#
        }
    }
}
