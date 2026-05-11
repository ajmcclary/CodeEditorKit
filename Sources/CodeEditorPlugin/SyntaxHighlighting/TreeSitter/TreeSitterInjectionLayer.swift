import Foundation

// MARK: - Tree-sitter Injection Support

/// Defines a language injection rule parsed from Tree-sitter's
/// `injections.scm` query file.
///
/// Injections allow nested language highlighting — for example,
/// JavaScript inside Markdown fenced code blocks or CSS inside HTML
/// `<style>` tags.
internal struct TreeSitterInjectionRule: Sendable {
    /// The Tree-sitter language name to inject (e.g. "javascript", "css").
    let language: String

    /// Combined query pattern that matches the injection boundary.
    let pattern: String

    /// Optional content capture name that isolates the injected text.
    let contentCapture: String?
}

// MARK: - Injection Layer

/// Manages language injection rules and coordinates recursive parsing
/// for embedded languages.
///
/// Phase 6b architecture: loads `injections.scm` queries per language
/// and schedules recursive parse passes for injected regions. The
/// actual recursive parsing is stubbed in the spike; real implementation
/// requires a parse-tree-aware parser (Phase 6+ C Tree-sitter).
internal struct TreeSitterInjectionLayer: Sendable {
    /// Injection rules keyed by host language.
    private let rules: [Language: [TreeSitterInjectionRule]]

    init() {
        self.rules = Self.buildDefaultRules()
    }

    /// Returns injection rules for a host language, if any.
    func rules(for language: Language) -> [TreeSitterInjectionRule] {
        rules[language] ?? []
    }

    // MARK: - Default Rules

    /// Predefined injection rules for common embedded-language scenarios.
    /// In the full Tree-sitter integration these are derived from
    /// `injections.scm` query files.
    private static func buildDefaultRules() -> [Language: [TreeSitterInjectionRule]] {
        var rules: [Language: [TreeSitterInjectionRule]] = [:]

        // Markdown: fenced code blocks
        rules[.markdown] = [
            TreeSitterInjectionRule(
                language: "javascript",
                pattern: "```(?:js|javascript)",
                contentCapture: "content"
            ),
            TreeSitterInjectionRule(
                language: "typescript",
                pattern: "```(?:ts|typescript)",
                contentCapture: "content"
            ),
            TreeSitterInjectionRule(
                language: "python",
                pattern: "```(?:py|python)",
                contentCapture: "content"
            ),
            TreeSitterInjectionRule(
                language: "swift",
                pattern: "```(?:swift)",
                contentCapture: "content"
            ),
            TreeSitterInjectionRule(
                language: "bash",
                pattern: "```(?:sh|bash|shell)",
                contentCapture: "content"
            )
        ]

        // HTML: <script> and <style> tags
        rules[.html] = [
            TreeSitterInjectionRule(
                language: "javascript",
                pattern: "<script[^>]*>",
                contentCapture: "content"
            ),
            TreeSitterInjectionRule(
                language: "css",
                pattern: "<style[^>]*>",
                contentCapture: "content"
            )
        ]

        // JavaScript: template literals with embedded expressions
        rules[.javascript] = [
            TreeSitterInjectionRule(
                language: "javascript",
                pattern: "\\$\\{",
                contentCapture: nil
            )
        ]

        rules[.typescript] = [
            TreeSitterInjectionRule(
                language: "typescript",
                pattern: "\\$\\{",
                contentCapture: nil
            )
        ]

        return rules
    }
}
