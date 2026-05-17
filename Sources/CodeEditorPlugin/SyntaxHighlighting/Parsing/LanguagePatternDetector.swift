import CodeEditorLanguages
import Foundation

// MARK: - Language Pattern Detector

/// Detects programming languages from content patterns and provides language-specific metadata.
public enum LanguagePatternDetector {
    // MARK: - Public API

    /// Detects programming language from content analysis
    public static func detectLanguageFromContent(_ text: String) -> Language? {
        let firstLine = text.components(separatedBy: .newlines).first ?? ""

        // Check for shebangs
        if firstLine.hasPrefix("#!") {
            if firstLine.contains("python") { return .python }
            if firstLine.contains("node") { return .javascript }
            if firstLine.contains("ruby") { return .ruby }
            if firstLine.contains("bash") || firstLine.contains("sh") { return .shell }
        }

        // Check for language-specific patterns
        let patterns: [(Language, [String])] = [
            (.swift, ["import Foundation", "import UIKit", "import SwiftUI", "func ", "var ", "let "]),
            (.javascript, ["function ", "const ", "let ", "var ", "=>", "require(", "import {"]),
            (.typescript, ["interface ", "type ", "export ", "import ", ": string", ": number"]),
            (.python, ["def ", "import ", "from ", "class ", "if __name__"]),
            (.rust, ["fn ", "let mut", "use ", "impl ", "struct ", "enum "]),
            (.go, ["package ", "func ", "import ", "var ", "type "]),
            (.java, ["public class", "import java", "public static void main"]),
            (.c, ["#include", "int main", "printf", "malloc"]),
            (.cpp, ["#include <iostream>", "using namespace", "std::", "cout"]),
            (.html, ["<!DOCTYPE", "<html", "<head", "<body", "</html>"]),
            (.css, ["{", ":", ";", "color:", "font-", "margin:"]),
            (.json, ["{", "}", "\":", "\",", "true", "false", "null"]),
            (.yaml, ["---", "- ", ": ", "  - "]),
            (.xml, ["<?xml", "<root", "</root", "xmlns"]),
            (.markdown, ["# ", "## ", "```", "[", "](", "**"]),
            (.shell, ["#!/bin/bash", "echo ", "if [", "for ", "while "]),
            (.sql, ["SELECT ", "FROM ", "WHERE ", "INSERT ", "UPDATE ", "DELETE "]),
            (.php, ["<?php", "function ", "$", "->", "echo "])
        ]

        for (language, keywords) in patterns {
            let matchCount = keywords.reduce(0) { count, keyword in
                count + text.components(separatedBy: keyword).count - 1
            }

            if matchCount > 2 { // Threshold for confidence
                return language
            }
        }

        return nil
    }

    /// Gets keywords for a specific language
    public static func getKeywords(for language: Language) -> Set<String> {
        switch language {
        case .swift:
            return ["func", "var", "let", "class", "struct", "enum", "protocol", "import"]

        case .javascript:
            return ["function", "var", "let", "const", "class", "import", "export"]

        case .python:
            return ["def", "class", "import", "from", "if", "else", "for", "while"]

        default:
            return []
        }
    }

    /// Gets string delimiters for a specific language
    public static func getStringDelimiters(for language: Language) -> [Character] {
        switch language {
        case .swift, .javascript, .typescript, .java, .c, .cpp:
            return ["\"", "'"]

        case .python:
            return ["\"", "'", "`"] // Triple quotes need special handling

        default:
            return ["\"", "'"]
        }
    }

    /// Gets identifier pattern for a specific language
    public static func getIdentifierPattern(for language: Language) -> String {
        switch language {
        case .swift, .java, .c, .cpp:
            return "[a-zA-Z_][a-zA-Z0-9_]*"

        case .javascript, .typescript:
            return "[a-zA-Z_$][a-zA-Z0-9_$]*"

        case .python:
            return "[a-zA-Z_][a-zA-Z0-9_]*"

        default:
            return "[a-zA-Z_][a-zA-Z0-9_]*"
        }
    }

    /// Extracts string literals with proper escape handling
    public static func extractStringLiterals(from text: String, language: Language) -> [NSRange] {
        let delimiters = getStringDelimiters(for: language)
        var ranges: [NSRange] = []

        for delimiter in delimiters {
            ranges.append(contentsOf: findStringRanges(in: text, delimiter: delimiter))
        }

        return ranges.sorted { $0.location < $1.location }
    }

    /// Extracts all identifiers from text
    public static func extractIdentifiers(from text: String, language: Language) -> [TokenExtractor.TextToken] {
        let identifierPattern = getIdentifierPattern(for: language)
        return TokenExtractor.extractTokensMatching(pattern: identifierPattern, in: text, language: language)
            .filter { $0.type == .identifier }
    }

    // MARK: - Private Helpers

    private static func findStringRanges(in text: String, delimiter: Character) -> [NSRange] {
        var ranges: [NSRange] = []
        var isInString = false
        var stringStart = 0
        var index = 0
        var isEscaped = false

        for char in text {
            if char == delimiter && !isEscaped {
                if isInString {
                    // End of string
                    ranges.append(NSRange(location: stringStart, length: index - stringStart + 1))
                    isInString = false
                } else {
                    // Start of string
                    stringStart = index
                    isInString = true
                }
            }

            isEscaped = char == "\\" && !isEscaped
            index += 1
        }

        return ranges
    }
}
