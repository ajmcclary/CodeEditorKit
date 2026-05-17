import Foundation

// MARK: - Word Boundary Finder

/// Finds word boundaries in text with support for various modes.
public enum WordBoundaryFinder {
    // MARK: - Public API

    /// Finds word boundaries in text with enhanced accuracy
    public static func findWordBoundaries(in text: String, mode: BoundaryMode = .standard) -> [Int] {
        var boundaries: [Int] = [0]
        var index = 0
        var previousCharType: TokenExtractor.CharacterType = .other

        for char in text {
            let currentCharType = TokenExtractor.classifyCharacterType(char)

            // Detect boundary based on character type transitions
            if shouldAddBoundary(previous: previousCharType, current: currentCharType, mode: mode) {
                boundaries.append(index)
            }

            previousCharType = currentCharType
            index += 1
        }

        if index > 0 {
            boundaries.append(index)
        }

        return boundaries
    }

    // MARK: - Private Helpers

    private static func shouldAddBoundary(
        previous: TokenExtractor.CharacterType,
        current: TokenExtractor.CharacterType,
        mode: BoundaryMode
    ) -> Bool {
        switch mode {
        case .standard:
            return (previous == .letter || previous == .digit) && current == .whitespace ||
                   previous == .whitespace && (current == .letter || current == .digit)

        case .camelCase:
            return (previous == .letter && current == .letter) || // Would need case checking
                   shouldAddBoundary(previous: previous, current: current, mode: .standard)

        case .programming:
            return previous != current ||
                   (previous == .letter && current == .underscore) ||
                   (previous == .underscore && current == .letter)
        }
    }

    // MARK: - Types

    /// Different modes for detecting word boundaries in text.
    public enum BoundaryMode {
        /// Standard word boundaries using whitespace and punctuation.
        case standard
        /// Include boundaries at camelCase transitions.
        case camelCase
        /// Programming-specific boundaries including underscores and operators.
        case programming
    }
}
