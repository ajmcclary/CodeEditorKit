import CodeEditorTextModel
import Foundation

/// Dockerfile folding: multi-line backslash-continuation instruction bodies
/// and `<<TOKEN` heredoc bodies.
struct DockerfileFoldingProvider: CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        let lines = text.components(separatedBy: .newlines)
        let lineLocations = buildLineLocations(for: lines)

        var regions: [FoldableRegion] = []
        var index = 0

        while index < lines.count {
            if let token = heredocToken(in: lines[index]),
               let closeIndex = findHeredocClose(token: token, in: lines, startingAfter: index) {
                append(
                    title: "<<\(token)",
                    fromLine: index,
                    toLine: closeIndex,
                    lines: lines,
                    lineLocations: lineLocations,
                    into: &regions
                )
                index = closeIndex + 1
                continue
            }

            if endsWithBackslash(lines[index]) {
                let runStart = index
                var lastContinuation = index
                while lastContinuation < lines.count - 1 && endsWithBackslash(lines[lastContinuation]) {
                    lastContinuation += 1
                }
                append(
                    title: instructionTitle(of: lines[runStart]),
                    fromLine: runStart,
                    toLine: lastContinuation,
                    lines: lines,
                    lineLocations: lineLocations,
                    into: &regions
                )
                index = lastContinuation + 1
                continue
            }

            index += 1
        }

        return regions
    }

    // MARK: - Heuristics

    // Trailing whitespace after `\` invalidates the continuation in real Dockerfiles,
    // so trim before checking the suffix.
    private func endsWithBackslash(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasSuffix("\\")
    }

    /// Returns the heredoc terminator token if the line opens a `<<TOKEN` heredoc
    /// (optionally with `-`/`~` indent modifiers or `"`/`'` quoting).
    private func heredocToken(in line: String) -> String? {
        guard let openRange = line.range(of: "<<") else { return nil }
        var tail = line[openRange.upperBound...]
        if tail.first == "-" || tail.first == "~" {
            tail = tail.dropFirst()
        }
        let quote: Character?
        if tail.first == "\"" || tail.first == "'" {
            quote = tail.first
            tail = tail.dropFirst()
        } else {
            quote = nil
        }
        let token = tail.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
        guard !token.isEmpty else { return nil }
        if let quote, tail.dropFirst(token.count).first != quote {
            return nil
        }
        return String(token)
    }

    private func findHeredocClose(token: String, in lines: [String], startingAfter index: Int) -> Int? {
        let needle = token
        for candidate in (index + 1)..<lines.count where lines[candidate].trimmingCharacters(in: .whitespaces) == needle {
            return candidate
        }
        return nil
    }

    private func instructionTitle(of line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let keyword = trimmed.prefix { $0.isLetter || $0.isNumber }
        return keyword.isEmpty ? "block" : String(keyword).uppercased()
    }

    // MARK: - Region assembly

    private func append(
        title: String,
        fromLine startLine: Int,
        toLine endLine: Int,
        lines: [String],
        lineLocations: [Int],
        into regions: inout [FoldableRegion]
    ) {
        guard endLine > startLine else { return }
        let start = lineLocations[startLine]
        let endLocation = lineLocations[endLine]
        let endLineLength = TextRangeUtilities.utf16Length(of: lines[endLine])
        let length = (endLocation + endLineLength) - start
        regions.append(FoldableRegion(
            range: NSRange(location: start, length: length),
            title: title,
            type: .block
        ))
    }

    private func buildLineLocations(for lines: [String]) -> [Int] {
        var locations = [Int]()
        locations.reserveCapacity(lines.count)
        var cursor = 0
        for line in lines {
            locations.append(cursor)
            cursor += TextRangeUtilities.utf16Length(of: line) + 1
        }
        return locations
    }
}
