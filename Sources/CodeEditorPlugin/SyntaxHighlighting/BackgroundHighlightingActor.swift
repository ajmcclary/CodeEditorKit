import Foundation

// MARK: - Highlighting Actor

/// Actor for managing concurrent highlighting operations
actor HighlightingActor {
    /// Perform syntax highlighting for text
    func highlight(
        text: String,
        language: Language,
        priority _: HighlightingPriority,
        maxConcurrentOperations: Int
    ) async throws -> [HighlightedToken] {
        try Task.checkCancellation()
        _ = maxConcurrentOperations // Reserved for future use

        // Use inherited task priority to avoid "Task policy set failed" errors
        return await Task {
            createBasicHighlighting(for: text, language: language)
        }.value
    }

    private func createBasicHighlighting(for text: String, language: Language) -> [HighlightedToken] {
        // Simple keyword-based highlighting that doesn't require MainActor
        var tokens: [HighlightedToken] = []

        let keywords: [String]
        switch language {
        case .swift:
            keywords = ["func", "var", "let", "class", "struct", "enum", "import", "if", "else", "for", "while", "return", "public", "private", "internal"]

        case .javascript, .typescript:
            keywords = ["function", "var", "const", "let", "if", "else", "for", "while", "return", "class", "new", "async", "await"]

        case .python:
            keywords = ["def", "class", "if", "elif", "else", "for", "while", "return", "import", "from", "as", "try", "except", "with"]

        case .go:
            keywords = ["func", "var", "const", "if", "else", "for", "return", "package", "import", "type", "struct", "interface"]

        case .rust:
            keywords = ["fn", "let", "mut", "const", "if", "else", "for", "while", "return", "use", "mod", "struct", "enum", "impl"]

        case .java:
            keywords = ["class", "public", "private", "static", "void", "if", "else", "for", "while", "return", "import", "new", "extends", "implements"]

        case .c, .cpp:
            keywords = ["int", "char", "void", "if", "else", "for", "while", "return", "include", "define", "typedef", "struct", "class"]

        default:
            keywords = ["function", "var", "if", "else", "for", "while", "return"]
        }

        // swiftlint:disable:next legacy_objc_type
        let nsString = NSString(string: text)

        for keyword in keywords {
            var searchRange = NSRange(location: 0, length: nsString.length)

            while searchRange.location < nsString.length {
                let foundRange = nsString.range(of: keyword, options: [.caseInsensitive], range: searchRange)

                if foundRange.location == NSNotFound {
                    break
                }

                // Create a token for the keyword
                let token = HighlightedToken(
                    range: foundRange,
                    type: .keyword,
                    text: nsString.substring(with: foundRange)
                )
                tokens.append(token)

                // Update search range to continue after this match
                searchRange.location = foundRange.location + foundRange.length
                searchRange.length = nsString.length - searchRange.location
            }
        }

        return tokens
    }
}
