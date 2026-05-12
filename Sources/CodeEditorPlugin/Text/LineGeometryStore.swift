import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - LineGeometry

/// Per-line geometry data stored in the tree.
///
/// `utf16Offset` is removed — line position is derived from subtree
/// metadata during tree traversal (O(log n)). Use
/// `LineGeometryStore.utf16Offset(forLineIndex:)` for the start offset
/// of any line.
public struct LineGeometry: Equatable, Sendable {
    /// Length of this line in UTF-16 code units (including the line terminator).
    public let utf16Length: Int

    /// Length of the line terminator: 1 for `\n` or `\r`, 2 for `\r\n`, 0 for
    /// the final line when the document does not end with a terminator.
    public let lineEndingLength: Int

    /// Estimated height from font metrics (always available).
    public let estimatedHeight: CGFloat

    /// Measured height from a layout pass (`nil` until first layout).
    public var measuredHeight: CGFloat?

    /// Whether this line is currently folded (collapsed).
    public var isFolded: Bool

    /// The effective height used for y-position calculations.
    public var effectiveHeight: CGFloat {
        if isFolded { return 0 }
        return measuredHeight ?? estimatedHeight
    }

    public init(
        utf16Length: Int,
        lineEndingLength: Int,
        estimatedHeight: CGFloat,
        measuredHeight: CGFloat? = nil,
        isFolded: Bool = false
    ) {
        self.utf16Length = utf16Length
        self.lineEndingLength = lineEndingLength
        self.estimatedHeight = estimatedHeight
        self.measuredHeight = measuredHeight
        self.isFolded = isFolded
    }
}

// MARK: - LineGeometryStore

/// A red-black tree storing per-line geometry with O(log n) lookup by UTF-16
/// offset, line index, and y-position. Supports incremental updates so edits
/// never require a full rebuild.
///
/// - Important: All offsets are UTF-16 code unit offsets, matching `NSRange`
///   and TextKit conventions. This store uses `NSString` line enumeration
///   internally to guarantee correctness for documents containing emoji,
///   composed characters, and surrogate pairs.
///
/// - Note: This is a `@MainActor` class, not an `actor`. Text edit events,
///   TextKit geometry, gutter updates, and folding state are UI-adjacent.
///   Async actor calls would spread through hot synchronous rendering paths.
@MainActor
public final class LineGeometryStore {
    // MARK: - Node

    private final class Node {
        var geometry: LineGeometry

        // Subtree metadata
        var subtreeUtf16Length: Int
        var subtreeLineCount: Int
        var subtreeHeight: CGFloat

        // Red-black tree structure
        var isRed: Bool = true
        weak var parent: Node?
        var left: Node?
        var right: Node?

        init(geometry: LineGeometry) {
            self.geometry = geometry
            self.subtreeUtf16Length = geometry.utf16Length
            self.subtreeLineCount = 1
            self.subtreeHeight = geometry.effectiveHeight
        }

        /// Recompute subtree metadata from children.
        func updateSubtreeMetadata() {
            subtreeUtf16Length = geometry.utf16Length
                + (left?.subtreeUtf16Length ?? 0)
                + (right?.subtreeUtf16Length ?? 0)
            subtreeLineCount = 1
                + (left?.subtreeLineCount ?? 0)
                + (right?.subtreeLineCount ?? 0)
            subtreeHeight = geometry.effectiveHeight
                + (left?.subtreeHeight ?? 0)
                + (right?.subtreeHeight ?? 0)
        }

        /// Propagate subtree metadata updates up to the root.
        func propagateMetadataUpward() {
            var current: Node? = self
            while let node = current {
                node.updateSubtreeMetadata()
                current = node.parent
            }
        }
    }

    // MARK: - Stored Properties

    private var root: Node?
    /// Number of lines in the store.
    public private(set) var lineCount: Int = 0

    /// Total UTF-16 length of all lines.
    public var totalUtf16Length: Int { root?.subtreeUtf16Length ?? 0 }

    /// Total height of all lines (respects fold state).
    public var totalHeight: CGFloat { root?.subtreeHeight ?? 0 }

    /// Default estimated line height used when no font is provided.
    private let defaultEstimatedHeight: CGFloat

    /// Cached last lookup for hot-path optimization.
    private var lastLookupNode: Node?
    private var lastLookupLineIndex: Int = 0

    // MARK: - Initialization

    /// Creates a new empty line geometry store.
    /// - Parameter defaultEstimatedHeight: Default line height used until
    ///   measured heights are provided via `updateMeasuredHeight`.
    public init(defaultEstimatedHeight: CGFloat = 17.0) {
        self.defaultEstimatedHeight = defaultEstimatedHeight
    }

    // MARK: - Build

    /// Build the store from an `NSTextStorage` using `NSString` line
    /// enumeration for UTF-16 correctness.
    ///
    /// Uses balanced tree construction from the sorted line array (O(n))
    /// followed by a post-order coloring pass that guarantees red-black
    /// invariants. For a balanced BST, subtrees of any node differ in
    /// height by at most 1, so coloring reduces to: when children have
    /// equal black-height the node is black; when they differ by 1 the
    /// deeper child is recolored red (reducing its bh by 1).
    ///
    /// - Parameter textStorage: The text storage to build geometry from.
    public func build(from textStorage: NSTextStorage) {
        reset()
        // swiftlint:disable:next legacy_objc_type
        let nsString = textStorage.string as NSString
        let length = nsString.length
        guard length > 0 else {
            let emptyGeometry = LineGeometry(
                utf16Length: 0,
                lineEndingLength: 0,
                estimatedHeight: defaultEstimatedHeight
            )
            root = Node(geometry: emptyGeometry)
            root?.isRed = false
            lineCount = 1
            return
        }

        // Collect all line geometries
        var geometries: [LineGeometry] = []
        var index = 0
        var anyLineTerminated = false
        while index < length {
            var lineStart = 0, lineEnd = 0, contentsEnd = 0
            nsString.getLineStart(
                &lineStart,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: index, length: 0)
            )
            let utf16Length = lineEnd - lineStart
            let lineEndingLength = lineEnd - contentsEnd
            geometries.append(LineGeometry(
                utf16Length: utf16Length,
                lineEndingLength: lineEndingLength,
                estimatedHeight: defaultEstimatedHeight
            ))
            anyLineTerminated = contentsEnd < lineEnd
            index = lineEnd
            if index >= length { break }
        }
        if anyLineTerminated && index == length {
            geometries.append(LineGeometry(
                utf16Length: 0,
                lineEndingLength: 0,
                estimatedHeight: defaultEstimatedHeight
            ))
        }

        // Build balanced BST from sorted array
        root = buildBalanced(from: geometries, start: 0, end: geometries.count - 1)

        // Color the tree to satisfy red-black invariants
        _ = colorTree(root)

        // Compute subtree metadata bottom-up
        updateMetadataPostOrder(root)

        lineCount = geometries.count
        lastLookupNode = nil
    }

    /// Recursively build a balanced BST from a sorted array slice.
    /// All nodes are initially black; the coloring pass fixes violations.
    private func buildBalanced(
        from geometries: [LineGeometry],
        start: Int,
        end: Int
    ) -> Node? {
        guard start <= end else { return nil }
        let mid = (start + end) / 2
        let node = Node(geometry: geometries[mid])
        node.isRed = false
        node.left = buildBalanced(from: geometries, start: start, end: mid - 1)
        node.left?.parent = node
        node.right = buildBalanced(from: geometries, start: mid + 1, end: end)
        node.right?.parent = node
        return node
    }

    /// Post-order red-black coloring pass.
    ///
    /// For a balanced BST where any node's subtrees differ in height by
    /// at most 1, the black heights (if all nodes were black) also differ
    /// by at most 1. The fix is:
    /// - If children have equal bh: this node stays black, bh ← child_bh + 1.
    /// - If one child is deeper: recolor the deeper child RED (reducing its
    ///   bh by exactly 1), then this node stays black.
    ///
    /// Returns the black-height of the subtree.
    @discardableResult
    private func colorTree(_ node: Node?) -> Int {
        guard let node else { return 0 }

        let leftBH = colorTree(node.left)
        let rightBH = colorTree(node.right)

        if leftBH == rightBH {
            node.isRed = false
            return leftBH + 1
        }

        // One side is deeper by exactly 1 — recolor deeper child RED
        if leftBH > rightBH {
            node.left?.isRed = true
            let newLeftBH = blackHeight(of: node.left)
            node.isRed = false
            return newLeftBH + 1
        } else {
            node.right?.isRed = true
            let newRightBH = blackHeight(of: node.right)
            node.isRed = false
            return newRightBH + 1
        }
    }

    /// Compute the black-height of a subtree (number of black nodes on
    /// any path from this node to a leaf, not counting this node).
    /// Assumes the tree satisfies red-black properties.
    private func blackHeight(of node: Node?) -> Int {
        guard let node else { return 0 }
        let childBH = max(blackHeight(of: node.left), blackHeight(of: node.right))
        return childBH + (node.isRed ? 0 : 1)
    }

    /// Post-order metadata computation. Must be called after coloring.
    private func updateMetadataPostOrder(_ node: Node?) {
        guard let node else { return }
        updateMetadataPostOrder(node.left)
        updateMetadataPostOrder(node.right)
        node.updateSubtreeMetadata()
    }

    // MARK: - Red-Black Tree Insertion (index-based)

    /// Restore red-black invariants after insertion.
    private func fixupAfterInsertion(_ node: Node) {
        var current = node

        while let parent = current.parent, parent.isRed {
            guard let grandparent = parent.parent else { break }

            if parent === grandparent.left {
                let uncle = grandparent.right

                if uncle?.isRed == true {
                    // Case 1: uncle is red — recolor
                    parent.isRed = false
                    uncle?.isRed = false
                    grandparent.isRed = true
                    current = grandparent
                } else {
                    if current === parent.right {
                        // Case 2: current is right child — rotate left
                        current = parent
                        rotateLeft(current)
                    }
                    // Case 3: current is left child — rotate right
                    if let newParent = current.parent {
                        newParent.isRed = false
                    }
                    grandparent.isRed = true
                    rotateRight(grandparent)
                }
            } else {
                // Mirror: parent is right child
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
                    if let newParent = current.parent {
                        newParent.isRed = false
                    }
                    grandparent.isRed = true
                    rotateLeft(grandparent)
                }
            }
        }

        root?.isRed = false
    }

    /// Rotate the subtree left around `node`.
    private func rotateLeft(_ node: Node) {
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

        node.updateSubtreeMetadata()
        rightChild.updateSubtreeMetadata()
        // Propagate upward from the new subtree root
        rightChild.parent?.propagateMetadataUpward()
    }

    /// Rotate the subtree right around `node`.
    private func rotateRight(_ node: Node) {
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

        node.updateSubtreeMetadata()
        leftChild.updateSubtreeMetadata()
        // Propagate upward from the new subtree root
        leftChild.parent?.propagateMetadataUpward()
    }

    // MARK: - Lookup: Offset → Line Index

    /// Returns the 0-based line index containing the given UTF-16 offset.
    /// O(log n).
    public func lineIndex(forUtf16Offset offset: Int) -> Int {
        guard let root else { return 0 }
        var current = root
        var lineIndex = 0
        var accumulatedOffset = 0

        while true {
            let leftUtf16Length = current.left?.subtreeUtf16Length ?? 0
            let leftLineCount = current.left?.subtreeLineCount ?? 0

            if offset < accumulatedOffset + leftUtf16Length {
                // Go left
                if let left = current.left {
                    current = left
                } else {
                    break
                }
            } else if offset >= accumulatedOffset + leftUtf16Length + current.geometry.utf16Length {
                // Go right — the offset is past this node's range
                lineIndex += leftLineCount + 1
                accumulatedOffset += leftUtf16Length + current.geometry.utf16Length
                if let right = current.right {
                    current = right
                } else {
                    break
                }
            } else {
                // Found the line
                lineIndex += leftLineCount
                lastLookupNode = current
                lastLookupLineIndex = lineIndex
                return lineIndex
            }
        }

        // Offset is beyond all lines — return last line
        return max(0, lineCount - 1)
    }

    // MARK: - Lookup: Line Index → Offset

    /// Returns the UTF-16 start offset for the given 0-based line index.
    /// O(log n).
    public func utf16Offset(forLineIndex lineIndex: Int) -> Int {
        guard let root else { return 0 }
        let clampedIndex = max(0, min(lineIndex, lineCount - 1))
        var current = root
        var remainingLines = clampedIndex
        var offset = 0

        while true {
            let leftLineCount = current.left?.subtreeLineCount ?? 0

            if remainingLines < leftLineCount {
                if let left = current.left {
                    current = left
                } else {
                    break
                }
            } else if remainingLines > leftLineCount {
                offset += (current.left?.subtreeUtf16Length ?? 0) + current.geometry.utf16Length
                remainingLines -= leftLineCount + 1
                if let right = current.right {
                    current = right
                } else {
                    break
                }
            } else {
                // Found the line
                offset += current.left?.subtreeUtf16Length ?? 0
                return offset
            }
        }

        return offset
    }

    // MARK: - Lookup: Line Index → Geometry

    /// Returns the `LineGeometry` for the given 0-based line index, or `nil`
    /// if the index is out of bounds.
    public func lineGeometry(at lineIndex: Int) -> LineGeometry? {
        guard lineIndex >= 0, lineIndex < lineCount, let root else { return nil }
        var current = root
        var remaining = lineIndex

        while true {
            let leftLineCount = current.left?.subtreeLineCount ?? 0
            if remaining < leftLineCount {
                if let left = current.left {
                    current = left
                } else {
                    return nil
                }
            } else if remaining > leftLineCount {
                remaining -= leftLineCount + 1
                if let right = current.right {
                    current = right
                } else {
                    return nil
                }
            } else {
                return current.geometry
            }
        }
    }

    /// Returns the `LineGeometry` containing the given UTF-16 offset.
    public func lineGeometry(atUtf16Offset offset: Int) -> LineGeometry? {
        let idx = lineIndex(forUtf16Offset: offset)
        return lineGeometry(at: idx)
    }

    // MARK: - Lookup: Y-Position ↔ Line Index

    /// Returns the 0-based line index at the given y-position.
    /// O(log n). If the y-position is beyond the total height, returns the
    /// last line index.
    public func lineIndex(forYPosition y: CGFloat) -> Int {
        guard let root else { return 0 }
        if y <= 0 { return 0 }
        var current = root
        var lineIndex = 0
        var accumulatedHeight: CGFloat = 0

        while true {
            let leftHeight = current.left?.subtreeHeight ?? 0
            let leftLineCount = current.left?.subtreeLineCount ?? 0

            if y < accumulatedHeight + leftHeight {
                if let left = current.left {
                    current = left
                } else {
                    break
                }
            } else if y >= accumulatedHeight + leftHeight + current.geometry.effectiveHeight {
                lineIndex += leftLineCount + 1
                accumulatedHeight += leftHeight + current.geometry.effectiveHeight
                if let right = current.right {
                    current = right
                } else {
                    break
                }
            } else {
                lineIndex += leftLineCount
                return lineIndex
            }
        }

        return max(0, lineCount - 1)
    }

    /// Returns the y-position of the start of the given line.
    /// O(log n).
    public func yPosition(forLineIndex lineIndex: Int) -> CGFloat {
        guard let root else { return 0 }
        let clamped = max(0, min(lineIndex, lineCount - 1))
        var current = root
        var remaining = clamped
        var y: CGFloat = 0

        while true {
            let leftLineCount = current.left?.subtreeLineCount ?? 0
            if remaining < leftLineCount {
                if let left = current.left {
                    current = left
                } else {
                    break
                }
            } else if remaining > leftLineCount {
                y += (current.left?.subtreeHeight ?? 0) + current.geometry.effectiveHeight
                remaining -= leftLineCount + 1
                if let right = current.right {
                    current = right
                } else {
                    break
                }
            } else {
                y += current.left?.subtreeHeight ?? 0
                return y
            }
        }
        return y
    }

    // MARK: - Height Updates

    /// Update the measured height for a line. Propagates subtree height
    /// changes upward. O(log n).
    public func updateMeasuredHeight(_ height: CGFloat, forLineAt lineIndex: Int) {
        guard let node = findNode(forLineIndex: lineIndex) else { return }
        node.geometry.measuredHeight = height
        node.propagateMetadataUpward()
    }

    /// Set estimated heights for all lines using the given font metrics.
    /// O(n) — use sparingly, typically only on font changes.
    public func setEstimatedHeight(_ height: CGFloat) {
        guard let root else { return }
        var stack: [Node] = [root]
        while let node = stack.popLast() {
            node.geometry = LineGeometry(
                utf16Length: node.geometry.utf16Length,
                lineEndingLength: node.geometry.lineEndingLength,
                estimatedHeight: height,
                measuredHeight: node.geometry.measuredHeight,
                isFolded: node.geometry.isFolded
            )
            if let right = node.right { stack.append(right) }
            if let left = node.left { stack.append(left) }
        }
        updateMetadataPostOrder(root)
    }

    // MARK: - Fold State

    /// Set the fold state for a line. Collapsed lines have effective height 0.
    /// O(log n).
    public func setFolded(_ folded: Bool, forLineAt lineIndex: Int) {
        guard let node = findNode(forLineIndex: lineIndex) else { return }
        node.geometry.isFolded = folded
        node.propagateMetadataUpward()
    }

    // MARK: - Tree Search Helper

    private func findNode(forLineIndex lineIndex: Int) -> Node? {
        guard lineIndex >= 0, lineIndex < lineCount, var current = root else {
            return nil
        }
        var remaining = lineIndex
        while true {
            let leftLineCount = current.left?.subtreeLineCount ?? 0
            if remaining < leftLineCount {
                if let left = current.left {
                    current = left
                } else {
                    return nil
                }
            } else if remaining > leftLineCount {
                remaining -= leftLineCount + 1
                if let right = current.right {
                    current = right
                } else {
                    return nil
                }
            } else {
                return current
            }
        }
    }

    /// Find the node containing a UTF-16 offset. Returns the node and its
    /// 0-based line index.
    private func findNode(forUtf16Offset offset: Int) -> (node: Node, lineIndex: Int)? {
        guard let root else { return nil }
        var current = root
        var lineIndex = 0
        var accumulatedOffset = 0

        while true {
            let leftUtf16Length = current.left?.subtreeUtf16Length ?? 0
            let leftLineCount = current.left?.subtreeLineCount ?? 0

            if offset < accumulatedOffset + leftUtf16Length {
                if let left = current.left {
                    current = left
                } else {
                    return nil
                }
            } else if offset >= accumulatedOffset + leftUtf16Length + current.geometry.utf16Length {
                lineIndex += leftLineCount + 1
                accumulatedOffset += leftUtf16Length + current.geometry.utf16Length
                if let right = current.right {
                    current = right
                } else {
                    return nil
                }
            } else {
                lineIndex += leftLineCount
                return (current, lineIndex)
            }
        }
    }

    // MARK: - Incremental Updates

    /// Insert one or more `LineGeometry` values at a line index.
    /// Each new node's metadata is local; offsets are derived from tree
    /// position during lookups. O(m log n) for m inserted lines.
    public func insertLines(_ lines: [LineGeometry], at lineIndex: Int) {
        guard !lines.isEmpty else { return }
        let clampedIndex = min(lineIndex, lineCount)

        for (offset, geometry) in lines.enumerated() {
            let node = Node(geometry: geometry)
            insertNode(node, atLineIndex: clampedIndex + offset)
        }
    }

    /// Remove a range of lines. O(m log n) for m removed lines.
    /// Safe to call on an empty store — no-op when `lineCount == 0` or
    /// when `range` lies entirely outside `[0, lineCount)`.
    public func removeLines(in range: ClosedRange<Int>) {
        guard lineCount > 0 else { return }
        let lower = max(0, range.lowerBound)
        let upper = min(lineCount - 1, range.upperBound)
        guard lower <= upper else { return }

        // Remove from highest to lowest to preserve indices.
        for lineIdx in (lower...upper).reversed() {
            removeNode(atLineIndex: lineIdx)
        }
    }

    /// Replace a single line's geometry. Preserves fold state unless
    /// explicitly changed. O(log n).
    public func replaceLine(at lineIndex: Int, with geometry: LineGeometry) {
        guard let node = findNode(forLineIndex: lineIndex) else { return }
        let wasFolded = node.geometry.isFolded
        node.geometry = geometry
        node.geometry.isFolded = wasFolded
        node.propagateMetadataUpward()
    }

    // MARK: - Index-Based Insertion

    /// Insert a node at a specific 0-based line index. Uses the existing
    /// red-black insertion machinery but orders by line index rather than
    /// stored offset. O(log n) for the BST insert + O(log n) for fixup.
    private func insertNode(_ node: Node, atLineIndex lineIndex: Int) {
        node.isRed = true
        node.left = nil
        node.right = nil
        node.updateSubtreeMetadata()

        guard let root else {
            self.root = node
            node.isRed = false
            lineCount = 1
            return
        }

        // Find insertion position by walking the tree using line-index ordering.
        var current = root
        var remaining = lineIndex

        while true {
            let leftLineCount = current.left?.subtreeLineCount ?? 0
            if remaining <= leftLineCount {
                if let left = current.left {
                    current = left
                } else {
                    current.left = node
                    node.parent = current
                    break
                }
            } else {
                remaining -= leftLineCount + 1
                if let right = current.right {
                    current = right
                } else {
                    current.right = node
                    node.parent = current
                    break
                }
            }
        }

        node.propagateMetadataUpward()
        fixupAfterInsertion(node)
        lineCount += 1
    }

    /// Remove the node at a specific line index. O(log n).
    private func removeNode(atLineIndex lineIndex: Int) {
        guard let node = findNode(forLineIndex: lineIndex) else { return }

        // Use standard red-black deletion: if node has two children,
        // swap with successor, then delete.
        let nodeToDelete: Node
        if node.left != nil, let rightChild = node.right {
            // Find in-order successor
            var successor = rightChild
            while let leftChild = successor.left {
                successor = leftChild
            }
            // Swap geometries
            let tempGeom = node.geometry
            node.geometry = successor.geometry
            successor.geometry = tempGeom
            nodeToDelete = successor
        } else {
            nodeToDelete = node
        }

        let child = nodeToDelete.left ?? nodeToDelete.right
        let wasRed = nodeToDelete.isRed

        // Replace nodeToDelete with its child
        if let parent = nodeToDelete.parent {
            if nodeToDelete === parent.left {
                parent.left = child
            } else {
                parent.right = child
            }
        } else {
            root = child
        }
        child?.parent = nodeToDelete.parent

        if !wasRed {
            fixupAfterDeletion(child, parent: nodeToDelete.parent)
        }

        // Propagate metadata from the replacement point upward
        (child ?? nodeToDelete.parent)?.propagateMetadataUpward()

        lineCount -= 1
    }

    /// Restore red-black invariants after deletion.
    private func fixupAfterDeletion(_ node: Node?, parent: Node?) {
        var current = node
        var currentParent = parent

        while current !== root, current?.isRed != true {
            guard let parentNode = currentParent else { break }

            if current === parentNode.left {
                var sibling = parentNode.right
                if sibling?.isRed == true {
                    sibling?.isRed = false
                    parentNode.isRed = true
                    rotateLeft(parentNode)
                    sibling = parentNode.right
                }
                if sibling?.left?.isRed != true, sibling?.right?.isRed != true {
                    sibling?.isRed = true
                    current = parentNode
                    currentParent = parentNode.parent
                } else {
                    if sibling?.right?.isRed != true {
                        sibling?.left?.isRed = false
                        sibling?.isRed = true
                        if let sibling {
                            rotateRight(sibling)
                        }
                        sibling = parentNode.right
                    }
                    sibling?.isRed = parentNode.isRed
                    parentNode.isRed = false
                    sibling?.right?.isRed = false
                    rotateLeft(parentNode)
                    current = root
                }
            } else {
                var sibling = parentNode.left
                if sibling?.isRed == true {
                    sibling?.isRed = false
                    parentNode.isRed = true
                    rotateRight(parentNode)
                    sibling = parentNode.left
                }
                if sibling?.right?.isRed != true, sibling?.left?.isRed != true {
                    sibling?.isRed = true
                    current = parentNode
                    currentParent = parentNode.parent
                } else {
                    if sibling?.left?.isRed != true {
                        sibling?.right?.isRed = false
                        sibling?.isRed = true
                        if let sibling {
                            rotateLeft(sibling)
                        }
                        sibling = parentNode.left
                    }
                    sibling?.isRed = parentNode.isRed
                    parentNode.isRed = false
                    sibling?.left?.isRed = false
                    rotateRight(parentNode)
                    current = root
                }
            }
        }

        current?.isRed = false
    }

    // MARK: - Reset

    /// Clear all data and return to initial empty state.
    public func reset() {
        root = nil
        lineCount = 0
        lastLookupNode = nil
    }

    // MARK: - Validation (Debug)

    /// Validate red-black tree invariants. Returns `true` if valid.
    /// For use in debug builds and tests.
    public func validateTree() -> Bool {
        guard let root else { return lineCount == 0 }
        if root.isRed { return false }
        let result = validateNode(root)
        return result.isValid
    }

    private func validateNode(_ node: Node?) -> (isValid: Bool, blackHeight: Int) {
        guard let node else { return (true, 1) }
        // No consecutive red nodes
        if node.isRed {
            if node.left?.isRed == true || node.right?.isRed == true {
                return (false, 0)
            }
        }
        let leftResult = validateNode(node.left)
        let rightResult = validateNode(node.right)
        guard leftResult.isValid, rightResult.isValid,
              leftResult.blackHeight == rightResult.blackHeight else {
            return (false, 0)
        }
        let bh = leftResult.blackHeight + (node.isRed ? 0 : 1)

        // Validate subtree metadata
        let expectedUtf16Length = node.geometry.utf16Length
            + (node.left?.subtreeUtf16Length ?? 0)
            + (node.right?.subtreeUtf16Length ?? 0)
        guard node.subtreeUtf16Length == expectedUtf16Length else {
            return (false, 0)
        }
        let expectedLineCount = 1
            + (node.left?.subtreeLineCount ?? 0)
            + (node.right?.subtreeLineCount ?? 0)
        guard node.subtreeLineCount == expectedLineCount else {
            return (false, 0)
        }

        return (true, bh)
    }
}

// MARK: - Iteration

extension LineGeometryStore {
    /// Returns an array of `LineGeometry` values for lines intersecting the
    /// given UTF-16 range.
    public func lineGeometries(in utf16Range: NSRange) -> [LineGeometry] {
        guard lineCount > 0 else { return [] }
        let startIndex = lineIndex(forUtf16Offset: utf16Range.location)
        let endOffset = utf16Range.location + utf16Range.length
        let endIndex = lineIndex(forUtf16Offset: max(0, endOffset - 1))
        guard startIndex <= endIndex else { return [] }
        var result: [LineGeometry] = []
        for idx in startIndex...endIndex {
            if let geom = lineGeometry(at: idx) {
                result.append(geom)
            }
        }
        return result
    }

    /// Returns an array of `LineGeometry` values for lines intersecting the
    /// given y-position range.
    public func lineGeometries(inYRange yRange: ClosedRange<CGFloat>) -> [LineGeometry] {
        guard lineCount > 0 else { return [] }
        let startIndex = lineIndex(forYPosition: yRange.lowerBound)
        let endIndex = lineIndex(forYPosition: yRange.upperBound)
        guard startIndex <= endIndex else { return [] }
        var result: [LineGeometry] = []
        for idx in startIndex...endIndex {
            if let geom = lineGeometry(at: idx) {
                result.append(geom)
            }
        }
        return result
    }

    /// Returns an array of all `LineGeometry` values in order.
    public var allLineGeometries: [LineGeometry] {
        var result: [LineGeometry] = []
        for idx in 0..<lineCount {
            if let geom = lineGeometry(at: idx) {
                result.append(geom)
            }
        }
        return result
    }
}

// MARK: - CustomStringConvertible

extension LineGeometryStore: CustomStringConvertible {
    nonisolated public var description: String {
        // Snapshot values since the store is @MainActor
        "LineGeometryStore"
    }
}
