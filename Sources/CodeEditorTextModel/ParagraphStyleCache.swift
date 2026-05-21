import CodeEditorPlatform
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Cache for paragraph styles to avoid recomputation.
///
/// `@unchecked Sendable` rationale (Swift 6 strict concurrency):
/// - Mutable state: `nodes`, `head`, `tail` form a doubly-linked-list LRU keyed
///   by `CacheKey` and capped at `capacity`. All access is serialized through
///   `cacheQueue`, a serial `DispatchQueue`. Public accessors `paragraphStyle(...)`
///   and `clear()` use `sync` to preserve the synchronous API drawing code
///   expects.
/// - Why not synthesized: the type is a reference type owning mutable
///   collections; Swift cannot prove safety automatically. The serial-queue
///   discipline below is what makes the cross-actor crossings safe.
/// - `NSParagraphStyle` values stored in the cache are themselves immutable
///   copies (see `createParagraphStyle` returning `paragraphStyle.copy()`).
public final class ParagraphStyleCache: @unchecked Sendable {
    // MARK: - Types

    /// Key for caching paragraph styles
    private struct CacheKey: Hashable {
        let tabWidth: Int
        let lineHeightMultiple: CGFloat
        let fontSize: CGFloat
        let spaceWidth: CGFloat

        // Round floating point values to avoid cache misses due to precision
        init(tabWidth: Int, lineHeightMultiple: CGFloat, fontSize: CGFloat, spaceWidth: CGFloat) {
            self.tabWidth = tabWidth
            self.lineHeightMultiple = (lineHeightMultiple * 1_000).rounded() / 1_000
            self.fontSize = (fontSize * 100).rounded() / 100
            self.spaceWidth = (spaceWidth * 1_000).rounded() / 1_000
        }
    }

    /// Doubly-linked-list node holding one cached paragraph style. Owned
    /// exclusively by the cache; `prev`/`next` are mutated under `cacheQueue`.
    private final class Node {
        let key: CacheKey
        let value: NSParagraphStyle
        var prev: Node?
        var next: Node?

        init(key: CacheKey, value: NSParagraphStyle) {
            self.key = key
            self.value = value
        }
    }

    // MARK: - Properties

    private var nodes: [CacheKey: Node] = [:]
    private var head: Node?
    private var tail: Node?
    private let cacheQueue = DispatchQueue(label: "com.codeeditor.paragraphstyle-cache")
    private let capacity: Int

    // MARK: - Initialization

    /// Creates a new paragraph style cache with the specified capacity.
    /// - Parameter capacity: Maximum number of paragraph styles to cache (defaults to 50)
    public init(capacity: Int = 50) {
        self.capacity = capacity
    }

    // MARK: - Public Methods

    /// Get or create a paragraph style for the given parameters
    public func paragraphStyle(
        tabWidth: Int,
        lineHeightMultiple: CGFloat,
        font: PlatformFont
    ) -> NSParagraphStyle {
        let spaceWidth = calculateSpaceWidth(for: font)

        let key = CacheKey(
            tabWidth: tabWidth,
            lineHeightMultiple: lineHeightMultiple,
            fontSize: font.pointSize,
            spaceWidth: spaceWidth
        )

        return cacheQueue.sync {
            if let existing = nodes[key] {
                moveToHead(existing)
                return existing.value
            }

            let paragraphStyle = createParagraphStyle(
                tabWidth: tabWidth,
                lineHeightMultiple: lineHeightMultiple,
                spaceWidth: spaceWidth
            )

            let node = Node(key: key, value: paragraphStyle)
            nodes[key] = node
            insertAtHead(node)

            if nodes.count > capacity, let evict = tail {
                detach(evict)
                nodes.removeValue(forKey: evict.key)
            }

            return paragraphStyle
        }
    }

    /// Clear the cache
    public func clear() {
        cacheQueue.sync {
            nodes.removeAll()
            head = nil
            tail = nil
        }
    }

    // MARK: - LRU Helpers (call only under `cacheQueue`)

    private func insertAtHead(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil {
            tail = node
        }
    }

    private func detach(_ node: Node) {
        let prev = node.prev
        let next = node.next
        prev?.next = next
        next?.prev = prev
        if head === node {
            head = next
        }
        if tail === node {
            tail = prev
        }
        node.prev = nil
        node.next = nil
    }

    private func moveToHead(_ node: Node) {
        if head === node {
            return
        }
        detach(node)
        insertAtHead(node)
    }

    // MARK: - Private Methods

    private func calculateSpaceWidth(for font: PlatformFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let spaceString = "    " // Four spaces
        let size = spaceString.size(withAttributes: attributes)
        return size.width / 4.0
    }

    private func createParagraphStyle(
        tabWidth: Int,
        lineHeightMultiple: CGFloat,
        spaceWidth: CGFloat
    ) -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()

        // Set line spacing multiplier
        paragraphStyle.lineHeightMultiple = lineHeightMultiple

        // Calculate tab interval
        let tabInterval = spaceWidth * CGFloat(tabWidth)

        // Clear existing tab stops and set new ones
        paragraphStyle.tabStops = []
        var tabPosition: CGFloat = tabInterval

        // Create tab stops - 50 is usually enough for reasonable content
        for _ in 0..<50 {
            let tabStop = NSTextTab(
                textAlignment: .left,
                location: tabPosition,
                options: [:]
            )
            paragraphStyle.tabStops.append(tabStop)
            tabPosition += tabInterval
        }

        // Set default tab interval for positions beyond the explicit tab stops
        paragraphStyle.defaultTabInterval = tabInterval

        // Return immutable copy
        guard let copy = paragraphStyle.copy() as? NSParagraphStyle else {
            // This should never fail, but return default if it does
            return NSParagraphStyle()
        }
        return copy
    }
}

// MARK: - Shared Paragraph Styles

extension ParagraphStyleCache {
    /// Cached hidden paragraph style for code folding
    public static var hiddenParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = 0
        style.maximumLineHeight = 0
        style.lineSpacing = 0
        style.paragraphSpacing = 0
        style.paragraphSpacingBefore = 0
        guard let copy = style.copy() as? NSParagraphStyle else {
            // This should never fail, but return default if it does
            return NSParagraphStyle()
        }
        return copy
    }
}
