import CodeEditorTextModel
import Foundation

/// TOML folding: `[section]` and `[[array-of-tables]]` header bodies. A new
/// header closes the previously-open section; trailing `# comments` after a
/// header are tolerated. Multi-line strings are skipped so headers nested
/// inside them are not misdetected.
struct TomlFoldingProvider: CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        let lines = text.components(separatedBy: .newlines)
        var lineLocations = [Int]()
        lineLocations.reserveCapacity(lines.count)
        var cursor = 0
        for line in lines {
            lineLocations.append(cursor)
            cursor += TextRangeUtilities.utf16Length(of: line) + 1
        }

        var regions: [FoldableRegion] = []
        var openSection: (headerIndex: Int, title: String)?

        // Track multi-line string state so headers inside `"""..."""` or `'''...'''`
        // are ignored. Quoted keys with `[` cannot span multiple lines, so per-line
        // detection is enough for non-string content.
        var multilineDelimiter: String?

        for (index, rawLine) in lines.enumerated() {
            if let delimiter = multilineDelimiter {
                if rawLine.contains(delimiter) { multilineDelimiter = nil }
                continue
            }

            // Enter a multi-line string state if the line opens one without closing it.
            if let opener = detectMultilineStringOpener(rawLine) {
                if !lineClosesMultiline(rawLine, opener: opener) {
                    multilineDelimiter = opener
                }
                continue
            }

            guard let header = parseHeader(rawLine) else { continue }

            if let open = openSection {
                emit(open: open, endingBefore: index, lines: lines, lineLocations: lineLocations, into: &regions)
            }
            openSection = (headerIndex: index, title: header)
        }

        if let open = openSection {
            emit(open: open, endingBefore: lines.count, lines: lines, lineLocations: lineLocations, into: &regions)
        }

        return regions
    }

    // MARK: - Heuristics

    // A TOML header line begins with `[` and contains a matching `]` (single or
    // double), optionally followed by whitespace and a `#` comment. Quoted keys
    // containing `]` (e.g. `["a]b"]`) are not handled — an exotic corner.
    private func parseHeader(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("[") else { return nil }
        guard let closingIndex = trimmed.firstIndex(of: "]") else { return nil }

        let isArray = trimmed.hasPrefix("[[")
        let endIndex: String.Index
        if isArray {
            // `[[name]]` requires two consecutive `]`s. Walk forward from the first `]`.
            let after = trimmed.index(after: closingIndex)
            guard after < trimmed.endIndex, trimmed[after] == "]" else { return nil }
            endIndex = trimmed.index(after: after)
        } else {
            endIndex = trimmed.index(after: closingIndex)
        }

        let header = String(trimmed[..<endIndex])
        let rest = trimmed[endIndex...].trimmingCharacters(in: .whitespaces)
        // Anything after the closing bracket(s) other than whitespace + `# comment` means
        // this is not a header line.
        if !rest.isEmpty && !rest.hasPrefix("#") { return nil }
        return header
    }

    private func detectMultilineStringOpener(_ line: String) -> String? {
        if line.contains("\"\"\"") { return "\"\"\"" }
        if line.contains("'''") { return "'''" }
        return nil
    }

    /// True if the line both opens and closes a multi-line string (so the state
    /// shouldn't carry over to subsequent lines).
    private func lineClosesMultiline(_ line: String, opener: String) -> Bool {
        guard let range = line.range(of: opener) else { return false }
        return line[range.upperBound...].contains(opener)
    }

    // MARK: - Region assembly

    private func emit(
        open: (headerIndex: Int, title: String),
        endingBefore endIndex: Int,
        lines: [String],
        lineLocations: [Int],
        into regions: inout [FoldableRegion]
    ) {
        let lastLine = endIndex - 1
        guard lastLine > open.headerIndex else { return }
        let start = lineLocations[open.headerIndex]
        let endLocation = lineLocations[lastLine]
        let endLineLength = TextRangeUtilities.utf16Length(of: lines[lastLine])
        let length = (endLocation + endLineLength) - start
        regions.append(FoldableRegion(
            range: NSRange(location: start, length: length),
            title: open.title,
            type: .block
        ))
    }
}
