import Foundation

// MARK: - Multi Cursor Editor

/// Handles multi-cursor editing functionality
@MainActor
public final class MultiCursorEditor {
    // MARK: - Properties

    /// All active cursors
    public private(set) var cursors: [TextCursor] = []

    /// Whether multi-cursor mode is active
    public var isMultiCursorMode: Bool {
        !cursors.isEmpty && cursors.count > 1
    }

    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "MultiCursorEditor")

    // MARK: - Initialization

    /// Creates a new multi-cursor editor instance
    public init() {}

    // MARK: - Cursor Management

    /// Add a cursor at the specified location
    /// - Parameter location: The text location for the new cursor
    public func addCursor(at location: Int) {
        let newCursor = TextCursor(location: location)

        // Ensure cursor isn't duplicate
        if !cursors.contains(where: { $0.location == location }) {
            cursors.append(newCursor)
            cursors.sort { $0.location < $1.location }
        }
    }

    /// Add cursors at all occurrences of the selected text
    /// - Parameter textView: The code editor view
    public func addCursorsAtOccurrences(in textView: CodeEditorView) {
        guard textView.selectedRange.length > 0 else { return }

        let bridge = textView.textKitBridge
        guard let selectedText = bridge.substring(in: textView.selectedRange) else { return }

        // Find all occurrences
        let text = bridge.documentString
        var searchRange = NSRange(location: 0, length: text.count)

        cursors.removeAll()

        while searchRange.location < text.count {
            guard let swiftRange = Range(searchRange, in: text) else { break }
            let foundSwiftRange = text.range(of: selectedText, options: [], range: swiftRange)
            let foundRange = foundSwiftRange.map { NSRange($0, in: text) } ?? NSRange(location: NSNotFound, length: 0)

            if foundRange.location == NSNotFound {
                break
            }

            addCursor(at: foundRange.location)

            searchRange.location = NSMaxRange(foundRange)
            searchRange.length = text.count - searchRange.location
        }

        logger.info("Added \(self.cursors.count) cursors for occurrences of '\(selectedText)'")
    }

    /// Clear all extra cursors
    public func clearAllCursors() {
        cursors.removeAll()
    }

    // MARK: - Multi-Cursor Input

    /// Handle text input with multiple cursors
    /// - Parameters:
    ///   - text: The text to insert
    ///   - textView: The code editor view
    /// - Returns: True if input was handled, false otherwise
    public func handleInput(_ text: String, in textView: CodeEditorView) -> Bool {
        guard !cursors.isEmpty else { return false }

        let bridge = textView.textKitBridge

        // Insert text at each cursor location (in reverse order to maintain positions)
        for cursor in cursors.reversed() {
            let range = NSRange(location: cursor.location, length: cursor.selection)
            bridge.replaceCharacters(in: range, with: text)

            // Update cursor positions for remaining cursors
            let lengthChange = text.count - cursor.selection
            for index in 0..<cursors.count where cursors[index].location > cursor.location {
                cursors[index].location += lengthChange
            }
        }

        // Update cursor positions
        for index in 0..<cursors.count {
            cursors[index].location += text.count
            cursors[index].selection = 0
        }

        return true
    }

    /// Update visual indicators for multiple cursors
    public func updateVisuals() {
        // This would update visual indicators for multiple cursors
        // Implementation depends on platform-specific drawing
    }
}
