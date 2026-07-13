import Foundation

// MARK: - Language

/// Represents the programming languages supported by the code editor.
///
/// The Language enum defines all supported languages for syntax highlighting,
/// code completion, and other language-specific features. Each language has
/// associated file extensions and display names.
///
/// ## Supported Languages
///
/// The editor supports 30 languages plus plain text, grouped by category:
///
/// ### Web Development
/// - `.html` - HTML markup
/// - `.css` - CSS stylesheets
/// - `.javascript` - JavaScript (.js, .mjs, .cjs)
/// - `.typescript` - TypeScript (.ts, .tsx)
///
/// ### Systems Programming
/// - `.swift` - Swift (with AST-based highlighting)
/// - `.rust` - Rust (.rs)
/// - `.c` - C language (.c, .h)
/// - `.cpp` - C++ (.cpp, .cc, .cxx, .hpp)
/// - `.go` - Go (.go)
///
/// ### Scripting Languages
/// - `.python` - Python (.py, .pyw)
/// - `.ruby` - Ruby (.rb)
/// - `.php` - PHP (.php)
/// - `.shell` - Shell scripts (.sh, .bash, .zsh)
///
/// ### Data & Configuration
/// - `.json` - JSON (.json)
/// - `.yaml` - YAML (.yml, .yaml)
/// - `.xml` - XML (.xml)
/// - `.sql` - SQL (.sql)
///
/// ### Documentation
/// - `.markdown` - Markdown (.md, .markdown)
/// - `.plainText` - Plain text (no highlighting)
///
/// ### Diagram DSLs
/// - `.mermaid` - Mermaid (.mmd, .mermaid)
/// - `.d2` - D2 (.d2)
/// - `.dot` - Graphviz DOT (.dot, .gv)
/// - `.structurizr` - Structurizr DSL (.dsl)
/// - `.plantuml` - PlantUML (.puml, .plantuml, .pu)
///
/// ## Example
///
/// ```swift
/// // Set language directly
/// editor.language = .swift
///
/// // Get display name
/// let name = Language.python.name  // "Python"
///
/// // Check file extensions
/// let extensions = Language.javascript.fileExtensions  // ["js", "mjs", "cjs"]
///
/// // Detect from file extension
/// if let language = Language(fileExtension: "py") {
///     editor.language = language  // .python
/// }
/// ```
///
/// - SeeAlso: `CodeEditorView.language`, `CodeEditorView.setLanguage(fileExtension:)`
public enum Language: String, CaseIterable, Equatable, Hashable, Sendable, Codable {
    case swift
    case javascript
    case typescript
    case python
    case go
    case rust
    case c // swiftlint:disable:this identifier_name
    case cpp
    case java
    case html
    case css
    case json
    case markdown
    case yaml
    case xml
    case sql
    case ruby
    case php
    case shell
    case dockerfile
    case toml
    case lua
    case csharp
    case kotlin
    case dart
    case mermaid
    case d2
    case dot
    case structurizr
    case plantuml
    case plainText = "plaintext"

    /// The human-readable display name for the language.
    ///
    /// Use this property to show language names in UI elements like
    /// language selectors or status bars.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let languages = Language.allCases.map { $0.name }
    /// // ["Swift", "JavaScript", "TypeScript", ...]
    /// ```
    public var name: String {
        LanguageDescriptor.descriptor(for: self)?.displayName ?? rawValue.capitalized
    }

    /// The file extensions associated with this language.
    ///
    /// Returns an array of common file extensions (without dots) that are
    /// typically used for files of this language type.
    ///
    /// ## Example
    ///
    /// ```swift
    /// Language.python.fileExtensions    // ["py", "pyw"]
    /// Language.cpp.fileExtensions       // ["cpp", "cc", "cxx", "hpp", "h", "hh"]
    /// ```
    public var fileExtensions: [String] {
        LanguageDescriptor.descriptor(for: self)?.fileExtensions ?? []
    }

    /// The Language Server Protocol identifier for the language.
    ///
    /// This identifier is used when communicating with Language Server Protocol (LSP) servers.
    /// It follows the standard LSP language identifiers as defined in the specification.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let language = Language.swift
    /// let lspId = language.lspIdentifier // "swift"
    ///
    /// // Use with LSP client
    /// lspClient.initialize(languageId: language.lspIdentifier)
    /// ```
    ///
    /// - SeeAlso: [LSP Specification - Text Document Item](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocumentItem)
    public var lspIdentifier: String {
        LanguageDescriptor.descriptor(for: self)?.lspIdentifier ?? rawValue
    }

    /// Initialize from file extension
    public init?(fileExtension: String) {
        let lowercased = fileExtension.lowercased()
        for language in Self.allCases where language.fileExtensions.contains(lowercased) {
            self = language
            return
        }
        return nil
    }
}

// MARK: - Language Extensions

extension Language {
    /// Unique identifier for the language (used by plugin system)
    public var identifier: String {
        rawValue
    }

    /// Get language from identifier
    public init?(identifier: String) {
        self.init(rawValue: identifier)
    }
}
