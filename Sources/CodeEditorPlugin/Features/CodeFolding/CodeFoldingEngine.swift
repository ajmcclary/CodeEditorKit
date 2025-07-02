import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import os.log

/// Engine for managing code folding in the editor
@MainActor
public class CodeFoldingEngine: ObservableObject {
    private let logger = Logger(subsystem: "CodeEditorPlugin", category: "CodeFoldingEngine")

    // MARK: - Published Properties

    @Published public private(set) var foldableRegions: [FoldableRegion] = []
    @Published public private(set) var foldedRegions: Set<UUID> = []
    @Published public private(set) var isProcessing = false

    // MARK: - Properties

    private weak var textView: CodeEditorView?
    private var textStorage: NSTextStorage? { textView?.textStorage }
    private var providers: [Language: CodeFoldingProvider] = [:]
    private var updateTask: Task<Void, Never>?

    // MARK: - Configuration

    public var configuration = CodeFoldingConfiguration()

    // MARK: - Initialization

    public init() {
        setupDefaultProviders()
    }

    /// Attach to a text view
    public func attach(to textView: CodeEditorView) {
        self.textView = textView
        updateFoldableRegions()
    }

    // MARK: - Provider Management

    /// Register a folding provider for a language
    public func registerProvider(_ provider: CodeFoldingProvider, for language: Language) {
        providers[language] = provider
        logger.info("Registered folding provider for \(language.name)")
    }

    private func setupDefaultProviders() {
        // Register default providers for brace-based languages
        let braceProvider = BraceFoldingProvider()
        registerProvider(braceProvider, for: .swift)
        registerProvider(braceProvider, for: .javascript)
        registerProvider(braceProvider, for: .typescript)
        registerProvider(braceProvider, for: .c)
        registerProvider(braceProvider, for: .cpp)
        registerProvider(braceProvider, for: .java)
        registerProvider(braceProvider, for: .go)
        registerProvider(braceProvider, for: .rust)
        registerProvider(braceProvider, for: .css)
        registerProvider(braceProvider, for: .json)
        registerProvider(braceProvider, for: .php)

        // Python and YAML use indentation-based folding
        let indentationProvider = IndentationFoldingProvider()
        registerProvider(indentationProvider, for: .python)
        registerProvider(indentationProvider, for: .yaml)

        // Markdown section folding
        registerProvider(MarkdownFoldingProvider(), for: .markdown)

        // XML/HTML tag folding
        let xmlProvider = XMLFoldingProvider()
        registerProvider(xmlProvider, for: .xml)
        registerProvider(xmlProvider, for: .html)

        // Specialized language providers
        registerProvider(ShellFoldingProvider(), for: .shell)
        registerProvider(SQLFoldingProvider(), for: .sql)
        registerProvider(RubyFoldingProvider(), for: .ruby)
    }

    // MARK: - Folding Operations

    /// Toggle fold at line
    public func toggleFold(at line: Int) {
        guard let region = foldableRegion(at: line) else { return }

        if foldedRegions.contains(region.id) {
            unfold(region)
        } else {
            fold(region)
        }
    }

    /// Fold a specific region
    public func fold(_ region: FoldableRegion) {
        guard !foldedRegions.contains(region.id),
              let textView else { return }

        foldedRegions.insert(region.id)

        // Apply folding visual changes
        applyFoldingVisuals(for: region, isFolded: true)

        // Hide the folded content
        if configuration.hidesFoldedContent {
            hideFoldedContent(region)
        }

        // Update gutter
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.setNeedsDisplay(textView.bounds)
        #else
        textView.setNeedsDisplay()
        #endif

        logger.debug("Folded region: \(region.title)")
    }

    /// Unfold a specific region
    public func unfold(_ region: FoldableRegion) {
        guard foldedRegions.contains(region.id),
              let textView else { return }

        foldedRegions.remove(region.id)

        // Remove folding visual changes
        applyFoldingVisuals(for: region, isFolded: false)

        // Show the unfolded content
        if configuration.hidesFoldedContent {
            showUnfoldedContent(region)
        }

        // Update gutter
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        textView.setNeedsDisplay(textView.bounds)
        #else
        textView.setNeedsDisplay()
        #endif

        logger.debug("Unfolded region: \(region.title)")
    }

    /// Fold all regions
    public func foldAll() {
        for region in foldableRegions where !foldedRegions.contains(region.id) {
            fold(region)
        }
    }

    /// Unfold all regions
    public func unfoldAll() {
        let regionsToUnfold = foldableRegions.filter { foldedRegions.contains($0.id) }

        for region in regionsToUnfold {
            unfold(region)
        }
    }

    /// Fold all regions at a specific level
    public func foldLevel(_ level: Int) {
        for region in foldableRegions where region.level == level {
            if !foldedRegions.contains(region.id) {
                fold(region)
            }
        }
    }

    /// Get foldable region at line
    public func foldableRegion(at line: Int) -> FoldableRegion? {
        foldableRegions.first { region in
            let startLine = lineNumber(for: region.range.location)
            let endLine = lineNumber(for: NSMaxRange(region.range))
            return line >= startLine && line <= endLine
        }
    }

    /// Check if line is in a folded region
    public func isLineFolded(_ line: Int) -> Bool {
        guard let region = foldableRegion(at: line) else { return false }
        return foldedRegions.contains(region.id)
    }

    // MARK: - Region Detection

    /// Update foldable regions based on current text
    public func updateFoldableRegions() {
        updateTask?.cancel()

        updateTask = Task { [weak self] in
            guard let self else { return }

            await self.detectFoldableRegions()
        }
    }

    private func detectFoldableRegions() async {
        guard let textView,
              let provider = providers[textView.language] else {
            foldableRegions = []
            return
        }

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let text = textView.textStorage?.string else {
            foldableRegions = []
            return
        }
        #else
        let text = textView.textStorage.string
        #endif

        isProcessing = true
        defer { isProcessing = false }

        let regions = await provider.detectFoldableRegions(in: text)

        // Filter and sort regions
        let validRegions = regions
            .filter { region in
                // Validate region
                region.range.location >= 0 &&
                NSMaxRange(region.range) <= text.count &&
                region.range.length >= configuration.minimumLineCount
            }
            .sorted { $0.range.location < $1.range.location }

        // Build hierarchy
        let hierarchicalRegions = buildHierarchy(from: validRegions)

        // Update regions, preserving fold state
        updateRegions(hierarchicalRegions)
    }

    private func buildHierarchy(from regions: [FoldableRegion]) -> [FoldableRegion] {
        var hierarchicalRegions: [FoldableRegion] = []

        for region in regions {
            // Find parent region
            var parent: FoldableRegion?
            var level = 0

            for existing in hierarchicalRegions.reversed() where RangeUtilities.contains(existing.range, region.range) {
                parent = existing
                level = existing.level + 1
                break
            }

            // Create hierarchical region
            var updatedRegion = region
            updatedRegion.level = level
            updatedRegion.parentId = parent?.id

            hierarchicalRegions.append(updatedRegion)
        }

        return hierarchicalRegions
    }

    private func updateRegions(_ newRegions: [FoldableRegion]) {
        // Preserve fold state for regions that still exist
        var newFoldedRegions = Set<UUID>()

        for newRegion in newRegions {
            // Check if this region was previously folded
            if let existingRegion = foldableRegions.first(where: {
                $0.range == newRegion.range && $0.type == newRegion.type
            }), foldedRegions.contains(existingRegion.id) {
                newFoldedRegions.insert(newRegion.id)
            }
        }

        foldableRegions = newRegions
        foldedRegions = newFoldedRegions
    }

    // MARK: - Visual Updates

    private func applyFoldingVisuals(for region: FoldableRegion, isFolded: Bool) {
        guard let textStorage else { return }

        if isFolded {
            // Add fold indicator at the end of the first line
            let firstLineEnd = firstLineEndLocation(for: region.range)
            let indicatorRange = NSRange(location: firstLineEnd, length: 0)

            // Apply folding attributes
            textStorage.addAttributes([
                .foldingIndicator: true,
                .foregroundColor: configuration.indicatorColor
            ], range: indicatorRange)
        } else {
            // Remove fold indicator
            let firstLineEnd = firstLineEndLocation(for: region.range)
            let indicatorRange = NSRange(location: firstLineEnd, length: region.foldedText?.count ?? 0)

            textStorage.removeAttribute(.foldingIndicator, range: indicatorRange)
        }
    }

    private func hideFoldedContent(_ region: FoldableRegion) {
        guard let textStorage else { return }

        // Calculate content range (excluding first line)
        let firstLineEnd = firstLineEndLocation(for: region.range)
        let contentStart = min(firstLineEnd + 1, NSMaxRange(region.range))
        let contentLength = NSMaxRange(region.range) - contentStart

        guard contentLength > 0 else { return }

        let contentRange = NSRange(location: contentStart, length: contentLength)

        // Hide content using attributes
        textStorage.addAttributes([
            .hidden: true,
            .foldedRegion: region.id
        ], range: contentRange)
    }

    private func showUnfoldedContent(_ region: FoldableRegion) {
        guard let textStorage else { return }

        // Remove hidden attributes from the entire region
        textStorage.removeAttribute(.hidden, range: region.range)
        textStorage.removeAttribute(.foldedRegion, range: region.range)
    }

    // MARK: - Utilities

    private func lineNumber(for location: Int) -> Int {
        guard let text = textStorage?.string else { return 0 }
        return RangeUtilities.lineNumber(for: location, in: text)
    }

    private func firstLineEndLocation(for range: NSRange) -> Int {
        guard let text = textStorage?.string else { return range.location }

        let lineRange = RangeUtilities.lineRange(containing: range.location, in: text)

        // Return end of line minus newline character
        let lineEnd = NSMaxRange(lineRange)
        if lineEnd > 0, let charIndex = text.utf16.index(text.utf16.startIndex, offsetBy: lineEnd - 1, limitedBy: text.utf16.endIndex),
           text.utf16[charIndex] == 10 { // \n
            return lineEnd - 1
        }
        return lineEnd
    }

    deinit {
        // Cleanup is handled automatically by ARC
    }
}

// MARK: - Supporting Types

/// Foldable region in the text
public struct FoldableRegion: Identifiable {
    public let id = UUID()
    public var range: NSRange
    public var title: String
    public var type: FoldingType
    public var level: Int = 0
    public var parentId: UUID?
    public var foldedText: String?

    public init(range: NSRange, title: String, type: FoldingType) {
        self.range = range
        self.title = title
        self.type = type
    }
}

/// Types of foldable regions
public enum FoldingType: Equatable {
    case function
    case `class`
    case method
    case block
    case comment
    case imports
    case region
    case custom(String)
}

/// Code folding configuration
public struct CodeFoldingConfiguration {
    public var enabled = true
    public var showGutterControls = true
    public var hidesFoldedContent = true
    public var minimumLineCount = 3
    public var foldedIndicator = " ⋯ "

    public var indicatorColor = PlatformColors.secondaryLabel

    public var animatesFolding = true
    public var saveFoldState = true
}

/// Protocol for language-specific folding providers
public protocol CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion]
}

// MARK: - Default Providers

/// Brace-based folding provider (C-style languages)
struct BraceFoldingProvider: CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []
        // Simple brace matching
        var braceStack: [(Character, Int)] = []

        for index in 0..<text.utf16.count {
            guard let charIndex = text.utf16.index(text.utf16.startIndex, offsetBy: index, limitedBy: text.utf16.endIndex) else { continue }
            let char = text.utf16[charIndex]
            let unicodeChar = Character(UnicodeScalar(char)!)

            switch unicodeChar {
            case "{":
                braceStack.append(("{", index))

            case "}":
                if let (openBrace, openIndex) = braceStack.popLast(), openBrace == "{" {
                    let range = NSRange(location: openIndex, length: index - openIndex + 1)

                    // Determine type based on context
                    let type = determineFoldingType(at: openIndex, in: text)
                    let title = extractTitle(at: openIndex, in: text, type: type)

                    regions.append(FoldableRegion(
                        range: range,
                        title: title,
                        type: type
                    ))
                }

            default:
                break
            }
        }

        return regions
    }

    private func determineFoldingType(at location: Int, in text: String) -> FoldingType {
        // Simple heuristic - check for keywords before the brace
        let prefix = String(text.prefix(location))

        if prefix.hasSuffix("class ") || prefix.hasSuffix("struct ") {
            return .class
        } else if prefix.hasSuffix("func ") || prefix.hasSuffix("function ") {
            return .function
        } else if prefix.contains("//") || prefix.contains("/*") {
            return .comment
        } else {
            return .block
        }
    }

    private func extractTitle(at location: Int, in text: String, type _: FoldingType) -> String {
        let lineRange = RangeUtilities.lineRange(containing: location, in: text)
        let lineStart = lineRange.location

        guard let startIndex = text.index(text.startIndex, offsetBy: lineStart, limitedBy: text.endIndex),
              let endIndex = text.index(text.startIndex, offsetBy: location, limitedBy: text.endIndex) else {
            return ""
        }

        let linePrefix = String(text[startIndex..<endIndex])
        return linePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Indentation-based folding provider (Python, YAML)
struct IndentationFoldingProvider: CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []
        let lines = text.components(separatedBy: .newlines)

        var indentStack: [(Int, Int, String)] = [] // (lineIndex, indentLevel, title)

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { continue }

            let indentLevel = line.prefix { $0 == " " || $0 == "\t" }.count

            // Close regions with higher indent level
            while let last = indentStack.last, last.1 >= indentLevel {
                let (startLine, _, title) = indentStack.removeLast()

                if index - startLine >= 2 { // Minimum lines for folding
                    let startLocation = locationForLine(startLine, in: lines)
                    let endLocation = locationForLine(index - 1, in: lines) + lines[index - 1].count

                    regions.append(FoldableRegion(
                        range: NSRange(location: startLocation, length: endLocation - startLocation),
                        title: title,
                        type: .block
                    ))
                }
            }

            // Start new region if this line ends with ":"
            if trimmedLine.hasSuffix(":") {
                indentStack.append((index, indentLevel, trimmedLine))
            }
        }

        return regions
    }

    private func locationForLine(_ lineIndex: Int, in lines: [String]) -> Int {
        var location = 0
        for index in 0..<lineIndex {
            location += lines[index].count + 1 // +1 for newline
        }
        return location
    }
}

/// Markdown folding provider
struct MarkdownFoldingProvider: CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []
        let lines = text.components(separatedBy: .newlines)

        var headerStack: [(Int, Int, String)] = [] // (lineIndex, level, title)

        for (index, line) in lines.enumerated() {
            if let headerLevel = markdownHeaderLevel(line) {
                // Close sections at same or higher level
                while let last = headerStack.last, last.1 >= headerLevel {
                    let (startLine, _, title) = headerStack.removeLast()

                    let startLocation = locationForLine(startLine, in: lines)
                    let endLocation = locationForLine(index - 1, in: lines) + lines[index - 1].count

                    regions.append(FoldableRegion(
                        range: NSRange(location: startLocation, length: endLocation - startLocation),
                        title: title,
                        type: .region
                    ))
                }

                headerStack.append((index, headerLevel, line))
            }
        }

        // Close remaining sections
        while let (startLine, _, title) = headerStack.popLast() {
            let startLocation = locationForLine(startLine, in: lines)
            let endLocation = text.count

            regions.append(FoldableRegion(
                range: NSRange(location: startLocation, length: endLocation - startLocation),
                title: title,
                type: .region
            ))
        }

        return regions
    }

    private func markdownHeaderLevel(_ line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }

        let level = trimmed.prefix { $0 == "#" }.count
        return level <= 6 ? level : nil
    }

    private func locationForLine(_ lineIndex: Int, in lines: [String]) -> Int {
        var location = 0
        for index in 0..<lineIndex {
            location += lines[index].count + 1 // +1 for newline
        }
        return location
    }
}

/// XML/HTML folding provider
struct XMLFoldingProvider: CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion] {
        var regions: [FoldableRegion] = []

        // Simple XML tag matching
        let tagPattern = "<([^/>\\s]+)[^>]*>"
        let closeTagPattern = "</([^>]+)>"

        guard let tagRegex = try? NSRegularExpression(pattern: tagPattern),
              let closeTagRegex = try? NSRegularExpression(pattern: closeTagPattern) else {
            return regions
        }

        let range = NSRange(location: 0, length: text.utf16.count)

        let openTags = tagRegex.matches(in: text, range: range)
        let closeTags = closeTagRegex.matches(in: text, range: range)

        // Match opening and closing tags
        for openMatch in openTags {
            let tagNameRange = openMatch.range(at: 1)
            guard let startIndex = text.index(text.startIndex, offsetBy: tagNameRange.location, limitedBy: text.endIndex),
                  let endIndex = text.index(startIndex, offsetBy: tagNameRange.length, limitedBy: text.endIndex) else { continue }
            let tagName = String(text[startIndex..<endIndex])

            // Find corresponding close tag
            if let closeMatch = closeTags.first(where: { closeMatch in
                let closeNameRange = closeMatch.range(at: 1)
                guard let closeStartIndex = text.index(text.startIndex, offsetBy: closeNameRange.location, limitedBy: text.endIndex),
                      let closeEndIndex = text.index(closeStartIndex, offsetBy: closeNameRange.length, limitedBy: text.endIndex) else { return false }
                let closeName = String(text[closeStartIndex..<closeEndIndex])
                return closeName == tagName && closeMatch.range.location > openMatch.range.location
            }) {
                let foldRange = NSRange(
                    location: openMatch.range.location,
                    length: NSMaxRange(closeMatch.range) - openMatch.range.location
                )

                regions.append(FoldableRegion(
                    range: foldRange,
                    title: "<\(tagName)>",
                    type: .block
                ))
            }
        }

        return regions
    }
}

// MARK: - NSAttributedString Keys

extension NSAttributedString.Key {
    static let foldingIndicator = NSAttributedString.Key("CodeEditor.foldingIndicator")
    static let hidden = NSAttributedString.Key("CodeEditor.hidden")
    static let foldedRegion = NSAttributedString.Key("CodeEditor.foldedRegion")
}
