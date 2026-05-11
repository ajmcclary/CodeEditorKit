import Foundation

// MARK: - LanguageDetectionService

/// Service responsible for language detection and management
/// Separates language detection logic from UI implementation
@MainActor
public final class LanguageDetectionService {
    // MARK: - Properties

    private let logger = CrossPlatformLogger.logger(subsystem: "com.codeeditor.plugin", category: "LanguageDetectionService")

    // Cache for language detection results
    private var extensionCache: [String: Language] = [:]
    private var contentCache: [Int: Language] = [:]  // Hash -> Language

    // MARK: - Initialization

    /// Creates a new language detection service.
    ///
    /// The service initializes with cached common file extensions for
    /// improved performance on subsequent language detection calls.
    public init() {
        // Preload common extensions into cache
        preloadCommonExtensions()
    }

    // MARK: - Public Methods

    /// Detects language from file extension
    public func detectLanguage(fromExtension fileExtension: String) -> Language {
        let normalizedExtension = fileExtension.lowercased()

        // Check cache first
        if let cached = extensionCache[normalizedExtension] {
            return cached
        }

        // Detect language
        let language = Language(fileExtension: normalizedExtension) ?? .plainText

        // Cache the result
        extensionCache[normalizedExtension] = language

        logger.debug("Detected language \(language.name) for extension .\(normalizedExtension)")
        return language
    }

    /// Detects language from file path
    public func detectLanguage(fromPath path: String) -> Language {
        let url = URL(fileURLWithPath: path)
        let filename = url.lastPathComponent
        let filenameLanguage = detectLanguage(fromFilename: filename)
        if filenameLanguage != .plainText {
            return filenameLanguage
        }

        let fileExtension = url.pathExtension

        guard !fileExtension.isEmpty else {
            return filenameLanguage
        }

        return detectLanguage(fromExtension: fileExtension)
    }

    /// Detects language from filename (for special cases like Dockerfile, Makefile)
    public func detectLanguage(fromFilename filename: String) -> Language {
        let lowercasedFilename = filename.lowercased()

        switch lowercasedFilename {
        case let name where name == "dockerfile" || name.hasPrefix("dockerfile."):
            return .dockerfile

        case "makefile", "gnumakefile":
            return .shell

        case "rakefile":
            return .ruby

        case "gemfile":
            return .ruby

        case "podfile":
            return .ruby

        case "package.json":
            return .json

        case "tsconfig.json":
            return .json

        case ".gitignore", ".dockerignore":
            return .plainText

        case "readme", "license", "changelog":
            return .markdown

        default:
            return .plainText
        }
    }

    /// Detects language from content analysis (heuristic)
    public func detectLanguage(fromContent content: String) -> Language? {
        // Quick return for empty content
        guard !content.isEmpty else { return nil }

        // Check cache
        let contentHash = content.hashValue
        if let cached = contentCache[contentHash] {
            return cached
        }

        // Keep content analysis bounded while still honoring EOF modelines.
        let prefixSample = String(content.prefix(1_000))
        let suffixSample = String(content.suffix(1_000))

        // Try to detect by shebang (strongest signal)
        if let shebangLanguage = detectLanguageFromShebang(prefixSample) {
            contentCache[contentHash] = shebangLanguage
            return shebangLanguage
        }

        // Try to detect by modelines (editor directive)
        if let modelineLanguage = detectLanguageFromModelines(prefix: prefixSample, suffix: suffixSample) {
            contentCache[contentHash] = modelineLanguage
            return modelineLanguage
        }

        // Try to detect by content patterns
        if let patternLanguage = detectLanguageFromPatterns(prefixSample) {
            contentCache[contentHash] = patternLanguage
            return patternLanguage
        }

        return nil
    }

    /// Gets all supported file extensions
    public func getAllSupportedExtensions() -> Set<String> {
        var extensions = Set<String>()
        for language in Language.allCases {
            extensions.formUnion(language.fileExtensions)
        }
        return extensions
    }

    /// Checks if a file extension is supported
    public func isExtensionSupported(_ fileExtension: String) -> Bool {
        detectLanguage(fromExtension: fileExtension) != .plainText
    }

    /// Gets language display information
    public func getLanguageInfo(for language: Language) -> LanguageInfo {
        LanguageInfo(
            identifier: language.rawValue,
            displayName: language.name,
            fileExtensions: language.fileExtensions,
            primaryExtension: language.fileExtensions.first ?? ""
        )
    }

    /// Validates language change
    public func validateLanguageChange(from oldLanguage: Language, to newLanguage: Language) -> LanguageChangeValidation {
        if oldLanguage == newLanguage {
            return .noChange
        }

        // Check if switching between similar languages
        let similarGroups: [[Language]] = [
            [.javascript, .typescript],
            [.c, .cpp],
            [.html, .xml],
            [.yaml, .json]
        ]

        for group in similarGroups {
            if group.contains(oldLanguage) && group.contains(newLanguage) {
                return .similar
            }
        }

        return .different
    }

    // MARK: - Cache Management

    /// Clears all language detection caches
    public func clearCache() {
        extensionCache.removeAll()
        contentCache.removeAll()
        logger.debug("Language detection cache cleared")
    }

    /// Clears content-based detection cache
    public func clearContentCache() {
        contentCache.removeAll()
    }

    // MARK: - Private Methods

    private func preloadCommonExtensions() {
        let commonExtensions = [
            "swift", "js", "ts", "py", "go", "rs", "c", "cpp", "java",
            "html", "css", "json", "md", "yml", "xml", "sql", "rb", "php", "sh"
        ]

        for ext in commonExtensions {
            _ = detectLanguage(fromExtension: ext)
        }
    }

    /// Structurally parses a shebang line to extract the interpreter name,
    /// resolves `/usr/bin/env` indirection (including `-S` flags), and looks
    /// up the result in ``LanguageDescriptor``'s `shebangIdentifiers` and
    /// `scriptAliases` sets.
    ///
    /// Examples handled:
    /// - `#!/bin/bash`                  → .shell
    /// - `#!/usr/bin/python3`           → .python
    /// - `#!/usr/bin/env python3`       → .python
    /// - `#!/usr/bin/env -S python3 -u` → .python
    /// - `#!/usr/bin/env node`          → .javascript
    /// - `#!/usr/bin/env deno`          → .typescript
    private func detectLanguageFromShebang(_ content: String) -> Language? {
        guard content.hasPrefix("#!") else { return nil }

        let firstLine = content.split(separator: "\n", maxSplits: 1).first ?? ""
        let shebang = String(firstLine).dropFirst(2) // Remove "#!"
            .trimmingCharacters(in: .whitespaces)

        let words = shebang.split(separator: " ", omittingEmptySubsequences: true)
        guard let firstWord = words.first else { return nil }

        let interpreter: String

        // Resolve /usr/bin/env indirection
        if firstWord.hasSuffix("/env") || firstWord == "env" {
            guard words.count >= 2 else { return nil }
            let secondWord = String(words[1])

            // Handle `env -S python3 -u` → extract "python3" from the -S argument
            if secondWord == "-S", words.count >= 3 {
                let splitArgs = words[2...].joined(separator: " ").split(separator: " ")
                guard let resolved = splitArgs.first else { return nil }
                interpreter = String(resolved)
            } else {
                interpreter = secondWord
            }
        } else {
            // Strip path prefix: /usr/bin/python3 → python3
            interpreter = String(firstWord.split(separator: "/").last ?? firstWord)
        }

        let name = interpreter.lowercased()
        return resolveScriptAlias(name)
    }

    /// Looks up a shebang interpreter / script alias in ``LanguageDescriptor``.
    ///
    /// Checks `shebangIdentifiers` first (canonical interpreter names like
    /// `python3`, `node`), then `scriptAliases` (convenience names like `js`).
    private func resolveScriptAlias(_ name: String) -> Language? {
        for (language, descriptor) in LanguageDescriptor.all where descriptor.shebangIdentifiers.contains(name) {
            return language
        }
        for (language, descriptor) in LanguageDescriptor.all where descriptor.scriptAliases.contains(name) {
            return language
        }
        return nil
    }

    /// Scans the first and last few lines of content for Vim or Emacs
    /// modelines and resolves the declared filetype to a `Language`.
    ///
    /// Supported modeline formats:
    /// - Vim:  `vim: set filetype=python:`, `vim: ft=python`
    /// - Emacs: `-*- mode: python -*-`, `-*- mode: python; -*-`
    private func detectLanguageFromModelines(prefix: String, suffix: String) -> Language? {
        let prefixLines = prefix.split(separator: "\n", omittingEmptySubsequences: false).prefix(5)
        let suffixLines = suffix.split(separator: "\n", omittingEmptySubsequences: false).suffix(5)

        for line in prefixLines + suffixLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Vim modeline: vim: set filetype=NAME or vim:ft=NAME
            if let filetype = matchVimModeline(trimmed) {
                if let language = resolveModelineFiletype(filetype) { return language }
            }

            // Emacs modeline: -*- mode: NAME -*- or -*- mode: NAME; -*-
            if let filetype = matchEmacsModeline(trimmed) {
                if let language = resolveModelineFiletype(filetype) { return language }
            }
        }

        return nil
    }

    /// Matches Vim modeline patterns: `vim:.*(?:filetype|ft)\s*=\s*(\w+)`
    private func matchVimModeline(_ line: String) -> String? {
        guard line.contains("vim:") else { return nil }

        let patterns = [
            #"vim:.*filetype\s*=\s*(\w+)"#,
            #"vim:.*ft\s*=\s*(\w+)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, options: [], range: range),
               let captureRange = Range(match.range(at: 1), in: line) {
                return String(line[captureRange]).lowercased()
            }
        }

        return nil
    }

    /// Matches Emacs modeline patterns: `-\*-.*mode:\s*(\w+)`
    private func matchEmacsModeline(_ line: String) -> String? {
        guard line.contains("-*-") else { return nil }

        let pattern = #"-\*-.*mode:\s*(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }

        let range = NSRange(line.startIndex..., in: line)
        if let match = regex.firstMatch(in: line, options: [], range: range),
           let captureRange = Range(match.range(at: 1), in: line) {
            return String(line[captureRange]).lowercased()
        }

        return nil
    }

    /// Resolves a modeline filetype string to a `Language`.
    ///
    /// First checks `treeSitterName`, then tries matching the `Language`
    /// raw value, then falls back to `shebangIdentifiers`.
    private func resolveModelineFiletype(_ filetype: String) -> Language? {
        // Check tree-sitter names first (most common modeline values)
        for (language, descriptor) in LanguageDescriptor.all where descriptor.treeSitterName == filetype {
            return language
        }
        // Try raw value match
        if let language = Language(rawValue: filetype) { return language }
        // Check shebang identifiers
        for (language, descriptor) in LanguageDescriptor.all where descriptor.shebangIdentifiers.contains(filetype) {
            return language
        }
        return nil
    }

    private func detectLanguageFromPatterns(_ content: String) -> Language? {
        // Swift patterns
        if content.contains("import Foundation") || content.contains("import UIKit") ||
           content.contains("func ") && content.contains("->") {
            return .swift
        }

        // Python patterns
        if content.contains("import ") && content.contains("from ") ||
           content.contains("def ") && content.contains(":") {
            return .python
        }

        // JavaScript patterns
        if content.contains("const ") || content.contains("let ") ||
           content.contains("function ") || content.contains("=>") {
            return .javascript
        }

        // HTML patterns
        if content.contains("<!DOCTYPE") || content.contains("<html") ||
           content.contains("<body") || content.contains("<head") {
            return .html
        }

        // JSON patterns
        if (content.hasPrefix("{") && content.contains(":")) ||
           (content.hasPrefix("[") && content.contains("{")) {
            return .json
        }

        return nil
    }
}

// MARK: - Supporting Types

/// Information about a programming language.
///
/// `LanguageInfo` provides comprehensive details about a programming language,
/// including its identifier, display name, and supported file extensions.
///
/// ## Example
///
/// ```swift
/// let swiftInfo = LanguageInfo(
///     identifier: "swift",
///     displayName: "Swift",
///     fileExtensions: ["swift"],
///     primaryExtension: "swift"
/// )
/// ```
public struct LanguageInfo {
    /// Unique identifier for the language (e.g., "swift", "python")
    public let identifier: String
    /// Human-readable display name (e.g., "Swift", "Python")
    public let displayName: String
    /// All supported file extensions for this language
    public let fileExtensions: [String]
    /// The most common/primary file extension
    public let primaryExtension: String
}

/// Validation result for language changes.
///
/// `LanguageChangeValidation` indicates the type of change when switching
/// between programming languages, helping optimize editor behavior.
public enum LanguageChangeValidation {
    /// No language change occurred
    case noChange
    /// Languages are in the same family (e.g., JavaScript ↔ TypeScript)
    case similar
    /// Completely different languages (e.g., Swift ↔ Python)
    case different
}
