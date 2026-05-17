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
/// - Mutable state: `cache: [CacheKey: NSParagraphStyle]` (line ~37) — capped at `capacity`.
/// - Synchronization: every read/write goes through `cacheQueue`, a serial
///   `DispatchQueue` (line ~38). Public accessors `paragraphStyle(...)` and
///   `clear()` use `sync` to preserve the synchronous API drawing code expects.
/// - Why not synthesized: the type is a reference type owning a mutable
///   dictionary; Swift cannot prove safety automatically. The serial-queue
///   discipline below is what makes the cross-actor crossings safe.
/// - `NSParagraphStyle` values stored in the dictionary are themselves
///   immutable copies (see `createParagraphStyle` returning `paragraphStyle.copy()`).
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

    // MARK: - Properties

    private var cache: [CacheKey: NSParagraphStyle] = [:]
    private var accessOrder: [CacheKey] = []
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
            if let cached = cache[key] {
                markAccessed(key)
                return cached
            }

            let paragraphStyle = createParagraphStyle(
                tabWidth: tabWidth,
                lineHeightMultiple: lineHeightMultiple,
                spaceWidth: spaceWidth
            )

            cache[key] = paragraphStyle
            markAccessed(key)
            while cache.count > capacity, let oldestKey = accessOrder.first {
                accessOrder.removeFirst()
                cache.removeValue(forKey: oldestKey)
            }

            return paragraphStyle
        }
    }

    /// Clear the cache
    public func clear() {
        cacheQueue.sync {
            cache.removeAll()
            accessOrder.removeAll()
        }
    }

    // MARK: - Private Methods

    private func calculateSpaceWidth(for font: PlatformFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let spaceString = "    " // Four spaces
        let size = spaceString.size(withAttributes: attributes)
        return size.width / 4.0
    }

    private func markAccessed(_ key: CacheKey) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
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
