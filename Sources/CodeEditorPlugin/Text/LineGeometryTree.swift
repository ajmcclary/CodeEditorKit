import CoreGraphics
import Foundation

/// Red-black tree of `LineGeometry` records. Owns the tree node type,
/// rotations, fixups, lookups, and mutations. `LineGeometryStore` is a public
/// facade over this internal type.
///
/// - Note: `@MainActor`-isolated for the same reason as `LineGeometryStore`:
///   gutter, fold, and TextKit2 callers all live on the main actor.
@MainActor
internal final class LineGeometryTree {
    // MARK: - Node

    private final class Node {
        var geometry: LineGeometry

        var subtreeUtf16Length: Int
        var subtreeLineCount: Int
        var subtreeHeight: CGFloat

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

        func propagateMetadataUpward() {
            var current: Node? = self
            while let node = current {
                node.updateSubtreeMetadata()
                current = node.parent
            }
        }
    }

    // MARK: - Storage

    private var root: Node?
    private(set) var lineCount: Int = 0

    var totalUtf16Length: Int { root?.subtreeUtf16Length ?? 0 }
    package var totalHeight: CGFloat { root?.subtreeHeight ?? 0 }

    private var lastLookupNode: Node?
    private var lastLookupLineIndex: Int = 0

    // MARK: - Bulk Replace

    /// Replace the entire tree with a balanced red-black tree built from
    /// the given sorted geometries (line index order). When `geometries` is
    /// empty the tree contains a single empty line, matching the empty
    /// `NSTextStorage` build path.
    package func replaceAll(_ geometries: [LineGeometry], defaultEstimatedHeight: CGFloat) {
        reset()

        guard !geometries.isEmpty else {
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

        root = buildBalanced(from: geometries, start: 0, end: geometries.count - 1)
        _ = colorTree(root)
        updateMetadataPostOrder(root)
        lineCount = geometries.count
        lastLookupNode = nil
    }

    /// Recursively build a balanced BST from a sorted array slice. All nodes
    /// are initially black; the coloring pass fixes red-black violations.
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
    /// For a balanced BST where any node's subtrees differ in height by at
    /// most 1, the all-black black heights also differ by at most 1. The fix:
    /// equal child black-heights → node stays black; one child deeper →
    /// recolor the deeper child RED to drop its black-height by exactly 1.
    @discardableResult
    private func colorTree(_ node: Node?) -> Int {
        guard let node else { return 0 }

        let leftBH = colorTree(node.left)
        let rightBH = colorTree(node.right)

        if leftBH == rightBH {
            node.isRed = false
            return leftBH + 1
        }

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

    private func blackHeight(of node: Node?) -> Int {
        guard let node else { return 0 }
        let childBH = max(blackHeight(of: node.left), blackHeight(of: node.right))
        return childBH + (node.isRed ? 0 : 1)
    }

    private func updateMetadataPostOrder(_ node: Node?) {
        guard let node else { return }
        updateMetadataPostOrder(node.left)
        updateMetadataPostOrder(node.right)
        node.updateSubtreeMetadata()
    }

    // MARK: - Rotations

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
        rightChild.parent?.propagateMetadataUpward()
    }

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
        leftChild.parent?.propagateMetadataUpward()
    }

    // MARK: - Insertion Fixup

    private func fixupAfterInsertion(_ node: Node) {
        var current = node

        while let parent = current.parent, parent.isRed {
            guard let grandparent = parent.parent else { break }

            if parent === grandparent.left {
                let uncle = grandparent.right

                if uncle?.isRed == true {
                    parent.isRed = false
                    uncle?.isRed = false
                    grandparent.isRed = true
                    current = grandparent
                } else {
                    if current === parent.right {
                        current = parent
                        rotateLeft(current)
                    }
                    if let newParent = current.parent {
                        newParent.isRed = false
                    }
                    grandparent.isRed = true
                    rotateRight(grandparent)
                }
            } else {
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

    // MARK: - Lookup: Offset → Line Index

    package func lineIndex(forUtf16Offset offset: Int) -> Int {
        guard let root else { return 0 }
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
                    break
                }
            } else if offset >= accumulatedOffset + leftUtf16Length + current.geometry.utf16Length {
                lineIndex += leftLineCount + 1
                accumulatedOffset += leftUtf16Length + current.geometry.utf16Length
                if let right = current.right {
                    current = right
                } else {
                    break
                }
            } else {
                lineIndex += leftLineCount
                lastLookupNode = current
                lastLookupLineIndex = lineIndex
                return lineIndex
            }
        }

        return max(0, lineCount - 1)
    }

    // MARK: - Lookup: Line Index → Offset

    package func utf16Offset(forLineIndex lineIndex: Int) -> Int {
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
                offset += current.left?.subtreeUtf16Length ?? 0
                return offset
            }
        }

        return offset
    }

    // MARK: - Lookup: Line Index → Geometry

    package func lineGeometry(at lineIndex: Int) -> LineGeometry? {
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

    package func lineGeometry(atUtf16Offset offset: Int) -> LineGeometry? {
        let idx = lineIndex(forUtf16Offset: offset)
        return lineGeometry(at: idx)
    }

    // MARK: - Lookup: Y-Position ↔ Line Index

    package func lineIndex(forYPosition y: CGFloat) -> Int {
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

    package func yPosition(forLineIndex lineIndex: Int) -> CGFloat {
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

    // MARK: - Height & Fold Mutations

    func updateMeasuredHeight(_ height: CGFloat, forLineAt lineIndex: Int) {
        guard let node = findNode(forLineIndex: lineIndex) else { return }
        node.geometry.measuredHeight = height
        node.propagateMetadataUpward()
    }

    func setEstimatedHeight(_ height: CGFloat) {
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

    func setFolded(_ folded: Bool, forLineAt lineIndex: Int) {
        guard let node = findNode(forLineIndex: lineIndex) else { return }
        node.geometry.isFolded = folded
        node.propagateMetadataUpward()
    }

    // MARK: - Tree Search Helpers

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

    // MARK: - Incremental Mutations

    func insertLines(_ lines: [LineGeometry], at lineIndex: Int) {
        guard !lines.isEmpty else { return }
        let clampedIndex = min(lineIndex, lineCount)

        for (offset, geometry) in lines.enumerated() {
            let node = Node(geometry: geometry)
            insertNode(node, atLineIndex: clampedIndex + offset)
        }
    }

    func removeLines(in range: ClosedRange<Int>) {
        guard lineCount > 0 else { return }
        let lower = max(0, range.lowerBound)
        let upper = min(lineCount - 1, range.upperBound)
        guard lower <= upper else { return }

        for lineIdx in (lower...upper).reversed() {
            removeNode(atLineIndex: lineIdx)
        }
    }

    func replaceLine(at lineIndex: Int, with geometry: LineGeometry) {
        guard let node = findNode(forLineIndex: lineIndex) else { return }
        let wasFolded = node.geometry.isFolded
        node.geometry = geometry
        node.geometry.isFolded = wasFolded
        node.propagateMetadataUpward()
    }

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

    private func removeNode(atLineIndex lineIndex: Int) {
        guard let node = findNode(forLineIndex: lineIndex) else { return }

        let nodeToDelete: Node
        if node.left != nil, let rightChild = node.right {
            var successor = rightChild
            while let leftChild = successor.left {
                successor = leftChild
            }
            let tempGeom = node.geometry
            node.geometry = successor.geometry
            successor.geometry = tempGeom
            nodeToDelete = successor
        } else {
            nodeToDelete = node
        }

        let child = nodeToDelete.left ?? nodeToDelete.right
        let wasRed = nodeToDelete.isRed

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

        (child ?? nodeToDelete.parent)?.propagateMetadataUpward()

        lineCount -= 1
    }

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

    // MARK: - Reset / Validation

    package func reset() {
        root = nil
        lineCount = 0
        lastLookupNode = nil
    }

    /// Validate red-black tree invariants. Returns `true` if valid. For use
    /// in debug builds and tests.
    package func validateTree() -> Bool {
        guard let root else { return lineCount == 0 }
        if root.isRed { return false }
        let result = validateNode(root)
        return result.isValid
    }

    private func validateNode(_ node: Node?) -> (isValid: Bool, blackHeight: Int) {
        guard let node else { return (true, 1) }
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
