import Foundation

/// Archived prior art — not wired into any production code path.
///
/// This was an early prototype of a red-black tree line index cache. It has
/// been superseded by `LineGeometryStore` (`Sources/CodeEditorPlugin/Text/`),
/// which adds:
/// - UTF-16-correct offsets (this cache uses Swift `Character` counts)
/// - Height tracking (estimated + measured, with y-position lookup)
/// - Fold state per line
/// - Subtree metadata (UTF-16 length, line count, height)
/// - Incremental edit integration via `TextEditEventHub`
/// - `@MainActor` class isolation (not `actor`) for hot synchronous paths
///
/// The red-black tree balancing code (rotations, fixup-after-insertion)
/// in this file was studied as reference during `LineGeometryStore`
/// development. The tree is correct but its data model (character offsets,
/// no heights, stub multi-line edits) makes it unsuitable for production.
@available(*, deprecated, message: "Use LineGeometryStore instead")
public actor OptimizedLineIndexCache {
    // MARK: - Types

    /// Red-Black Tree node for efficient line tracking
    private class LineNode {
        var lineStart: Int
        var lineLength: Int
        var subtreeLineCount: Int = 1
        var subtreeCharCount: Int = 0
        var isRed: Bool = true

        weak var parent: LineNode?
        var left: LineNode?
        var right: LineNode?

        init(start: Int, length: Int) {
            self.lineStart = start
            self.lineLength = length
            self.subtreeCharCount = length
        }
    }

    // MARK: - Properties

    private var root: LineNode?
    private var lineCount: Int = 0
    private var totalCharacters: Int = 0

    // Cache for recent lookups
    private var lookupCache: [Int: (line: Int, column: Int)] = [:]
    private let maxCacheSize = 100

    // MARK: - Public Interface

    /// Creates a new optimized line index cache.
    public init() {}

    /// Builds the index from text content
    public func buildIndex(from text: String) {
        self.root = nil
        self.lineCount = 0
        self.totalCharacters = text.count
        self.lookupCache.removeAll()

        var lineStart = 0
        var currentIndex = 0

        for char in text {
            if char.isNewline {
                let lineLength = currentIndex - lineStart + 1
                self.insertLine(start: lineStart, length: lineLength)
                lineStart = currentIndex + 1
            }
            currentIndex += 1
        }

        // Handle last line if it doesn't end with newline
        if lineStart < text.count {
            self.insertLine(start: lineStart, length: text.count - lineStart)
        }
    }

    /// Updates the index for a text change - O(log n)
    public func updateForTextChange(at range: NSRange, replacementLength: Int) {
        let delta = replacementLength - range.length
        self.totalCharacters += delta

        // Find affected lines
        let startLine = self.lineIndexForCharacterOffset(range.location)
        let endLine = self.lineIndexForCharacterOffset(range.location + range.length)

        // Update line information
        if startLine == endLine {
            // Change within single line
            self.updateLineLength(at: startLine, delta: delta)
        } else {
            // Change spans multiple lines - requires more complex update
            self.handleMultiLineChange(
                startLine: startLine,
                endLine: endLine,
                range: range,
                replacementLength: replacementLength
            )
        }

        // Invalidate lookup cache for affected region
        self.invalidateLookupCache(from: range.location)
    }

    /// Returns line and column for character offset - O(log n)
    public func lineAndColumn(for offset: Int) -> (line: Int, column: Int) {
        // Check cache first
        if let cached = lookupCache[offset] {
            return cached
        }

        // Calculate and cache
        let line = lineIndexForCharacterOffset(offset)
        let lineStart = characterOffsetForLine(line)
        let column = offset - lineStart

        let result = (line: line, column: column)

        // Update cache
        if lookupCache.count >= maxCacheSize {
            lookupCache.removeAll() // Simple eviction strategy
        }
        lookupCache[offset] = result

        return result
    }

    /// Returns character offset for line index - O(log n)
    public func characterOffset(for line: Int) -> Int {
        characterOffsetForLine(line)
    }

    /// Returns total line count - O(1)
    public var count: Int {
        lineCount
    }

    /// Returns line information - O(log n)
    public func lineInfo(at index: Int) -> (start: Int, length: Int)? {
        guard let node = findNode(for: index) else { return nil }
        return (start: node.lineStart, length: node.lineLength)
    }

    // MARK: - Private Methods

    private func insertLine(start: Int, length: Int) {
        let newNode = LineNode(start: start, length: length)

        if root == nil {
            root = newNode
            newNode.isRed = false
        } else {
            insertNode(newNode)
            fixupAfterInsertion(newNode)
        }

        lineCount += 1
    }

    private func insertNode(_ node: LineNode) {
        var current = root
        var parent: LineNode?

        while let unwrappedCurrent = current {
            parent = unwrappedCurrent
            if node.lineStart < unwrappedCurrent.lineStart {
                current = unwrappedCurrent.left
            } else {
                current = unwrappedCurrent.right
            }
        }

        node.parent = parent

        if let parent {
            if node.lineStart < parent.lineStart {
                parent.left = node
            } else {
                parent.right = node
            }
            updateSubtreeCounts(parent)
        }
    }

    private func lineIndexForCharacterOffset(_ offset: Int) -> Int {
        guard var current = root else { return 0 }

        var lineIndex = 0
        var currentOffset = 0

        while true {
            let leftChars = current.left?.subtreeCharCount ?? 0

            if offset < currentOffset + leftChars {
                // Go left
                if let left = current.left {
                    current = left
                } else {
                    break
                }
            } else if offset >= currentOffset + leftChars + current.lineLength {
                // Go right
                lineIndex += (current.left?.subtreeLineCount ?? 0) + 1
                currentOffset += leftChars + current.lineLength

                if let right = current.right {
                    current = right
                } else {
                    break
                }
            } else {
                // Found the line
                lineIndex += current.left?.subtreeLineCount ?? 0
                break
            }
        }

        return lineIndex
    }

    private func characterOffsetForLine(_ line: Int) -> Int {
        guard var current = root else { return 0 }

        var remainingLines = line
        var offset = 0

        while remainingLines > 0 && current.subtreeLineCount > remainingLines {
            let leftLines = current.left?.subtreeLineCount ?? 0

            if remainingLines <= leftLines {
                // Go left
                if let left = current.left {
                    current = left
                } else {
                    break
                }
            } else {
                // Go right
                offset += (current.left?.subtreeCharCount ?? 0) + current.lineLength
                remainingLines -= leftLines + 1

                if let right = current.right {
                    current = right
                } else {
                    break
                }
            }
        }

        // Add remaining offset from left subtree
        if remainingLines == 0 {
            offset += current.left?.subtreeCharCount ?? 0
        }

        return offset
    }

    private func findNode(for lineIndex: Int) -> LineNode? {
        guard var current = root else { return nil }

        var remainingLines = lineIndex

        while true {
            let leftLines = current.left?.subtreeLineCount ?? 0

            if remainingLines < leftLines {
                // Go left
                if let left = current.left {
                    current = left
                } else {
                    return nil
                }
            } else if remainingLines > leftLines {
                // Go right
                remainingLines -= leftLines + 1
                if let right = current.right {
                    current = right
                } else {
                    return nil
                }
            } else {
                // Found it
                return current
            }
        }
    }

    private func updateLineLength(at lineIndex: Int, delta: Int) {
        guard let node = findNode(for: lineIndex) else { return }

        node.lineLength += delta

        // Update subtree counts up the tree
        var current: LineNode? = node
        while let parent = current?.parent {
            updateSubtreeCounts(parent)
            current = parent
        }
    }

    private func handleMultiLineChange(
        startLine _: Int,
        endLine _: Int,
        range _: NSRange,
        replacementLength _: Int
    ) {
        // This is a simplified implementation
        // In production, this would handle line merging/splitting more efficiently

        // For now, mark cache as needing full rebuild
        // A more sophisticated implementation would incrementally update the tree
        lookupCache.removeAll()
    }

    private func updateSubtreeCounts(_ node: LineNode) {
        node.subtreeLineCount = 1 +
            (node.left?.subtreeLineCount ?? 0) +
            (node.right?.subtreeLineCount ?? 0)

        node.subtreeCharCount = node.lineLength +
            (node.left?.subtreeCharCount ?? 0) +
            (node.right?.subtreeCharCount ?? 0)
    }

    private func invalidateLookupCache(from offset: Int) {
        lookupCache = lookupCache.filter { $0.key < offset }
    }

    // MARK: - Red-Black Tree Balancing

    private func fixupAfterInsertion(_ node: LineNode) {
        var current = node

        while current.parent?.isRed == true {
            if let parent = current.parent,
               let grandparent = parent.parent {
                if parent === grandparent.left {
                    let uncle = grandparent.right

                    if uncle?.isRed == true {
                        // Case 1: Uncle is red
                        parent.isRed = false
                        uncle?.isRed = false
                        grandparent.isRed = true
                        current = grandparent
                    } else {
                        if current === parent.right {
                            // Case 2: Current is right child
                            current = parent
                            rotateLeft(current)
                        }

                        // Case 3: Current is left child
                        current.parent?.isRed = false
                        grandparent.isRed = true
                        rotateRight(grandparent)
                    }
                } else {
                    // Mirror cases for right side
                    let uncle = grandparent.left

                    if uncle?.isRed == true {
                        parent.isRed = false
                        uncle?.isRed = false
                        grandparent.isRed = true
                        current = grandparent
                    } else {
                        if current === parent.left {
                            current = parent
                            rotateRight(current)
                        }

                        current.parent?.isRed = false
                        grandparent.isRed = true
                        rotateLeft(grandparent)
                    }
                }
            }
        }

        root?.isRed = false
    }

    private func rotateLeft(_ node: LineNode) {
        guard let rightChild = node.right else { return }

        node.right = rightChild.left
        rightChild.left?.parent = node

        rightChild.parent = node.parent

        if node.parent == nil {
            root = rightChild
        } else if node === node.parent?.left {
            node.parent?.left = rightChild
        } else {
            node.parent?.right = rightChild
        }

        rightChild.left = node
        node.parent = rightChild

        updateSubtreeCounts(node)
        updateSubtreeCounts(rightChild)
    }

    private func rotateRight(_ node: LineNode) {
        guard let leftChild = node.left else { return }

        node.left = leftChild.right
        leftChild.right?.parent = node

        leftChild.parent = node.parent

        if node.parent == nil {
            root = leftChild
        } else if node === node.parent?.right {
            node.parent?.right = leftChild
        } else {
            node.parent?.left = leftChild
        }

        leftChild.right = node
        node.parent = leftChild

        updateSubtreeCounts(node)
        updateSubtreeCounts(leftChild)
    }
}

// MARK: - Performance Test Helper

@available(*, deprecated, message: "Use LineGeometryStore instead")
extension OptimizedLineIndexCache {
    /// Validates the tree structure (for testing)
    func validateTree() -> Bool {
        guard let root else { return true }

        // Check red-black properties
        if root.isRed { return false }

        return validateNode(root).isValid
    }

    private func validateNode(_ node: LineNode?) -> (isValid: Bool, blackHeight: Int) {
        guard let node else {
            return (true, 1) // NIL nodes are black
        }

        // Check no two reds in a row
        if node.isRed {
            if node.left?.isRed == true || node.right?.isRed == true {
                return (false, 0)
            }
        }

        let leftResult = validateNode(node.left)
        let rightResult = validateNode(node.right)

        // Check black height consistency
        if !leftResult.isValid || !rightResult.isValid ||
           leftResult.blackHeight != rightResult.blackHeight {
            return (false, 0)
        }

        let blackHeight = leftResult.blackHeight + (node.isRed ? 0 : 1)
        return (true, blackHeight)
    }
}
