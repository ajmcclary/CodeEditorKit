import CodeEditorPlatform
import CodeEditorTextModel
@testable import CodeEditorView
import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class ParagraphStyleCacheTests: XCTestCase {
    private var cache: ParagraphStyleCache?

    override func setUp() {
        super.setUp()
        cache = ParagraphStyleCache(capacity: 10)
    }

    override func tearDown() {
        cache = nil
        super.tearDown()
    }

    // MARK: - Caching Tests

    func testParagraphStyleCaching() {
        let font = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)

        // Get a paragraph style
        let style1 = cache?.paragraphStyle(
            tabWidth: 4,
            lineHeightMultiple: 1.2,
            font: font
        )

        // Get the same style again - should be cached
        let style2 = cache?.paragraphStyle(
            tabWidth: 4,
            lineHeightMultiple: 1.2,
            font: font
        )

        // Should be the exact same instance
        XCTAssertIdentical(style1, style2, "Cached paragraph style should return the same instance")
    }

    func testDifferentParametersCreateDifferentStyles() {
        let font = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)

        let style1 = cache?.paragraphStyle(
            tabWidth: 4,
            lineHeightMultiple: 1.2,
            font: font
        )

        let style2 = cache?.paragraphStyle(
            tabWidth: 8,  // Different tab width
            lineHeightMultiple: 1.2,
            font: font
        )

        let style3 = cache?.paragraphStyle(
            tabWidth: 4,
            lineHeightMultiple: 1.5,  // Different line height
            font: font
        )

        // All should be different instances
        XCTAssertNotIdentical(style1, style2, "Different tab width should create different style")
        XCTAssertNotIdentical(style1, style3, "Different line height should create different style")
        XCTAssertNotIdentical(style2, style3, "All styles should be different")
    }

    func testLRUEvictsLeastRecentlyAccessed() {
        // Locks the doubly-linked-list LRU semantics: the cache must evict the
        // least-recently-touched entry, and accessing an entry must promote it
        // out of the eviction window. A regression that swaps eviction order
        // (e.g. evicting most-recent first) would still pass the hit-vs-miss
        // tests above; this one fails it.
        let lruCache = ParagraphStyleCache(capacity: 3)
        let font = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)

        func style(_ tabWidth: Int) -> NSParagraphStyle {
            lruCache.paragraphStyle(tabWidth: tabWidth, lineHeightMultiple: 1.0, font: font)
        }

        let original1 = style(1)
        let original2 = style(2)
        let original3 = style(3)

        // Touch entry 1 — entry 2 is now the LRU.
        XCTAssertIdentical(style(1), original1, "touched entry should still be the same instance")

        // Insert a 4th entry — capacity exceeded, LRU (entry 2) is evicted.
        _ = style(4)

        XCTAssertIdentical(style(1), original1, "entry 1 was touched; must survive eviction")
        XCTAssertIdentical(style(3), original3, "entry 3 was never LRU; must survive eviction")
        XCTAssertNotIdentical(style(2), original2, "entry 2 was LRU at eviction time; must be a fresh instance")
    }

    func testCacheClear() {
        let font = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)

        let style1 = cache?.paragraphStyle(
            tabWidth: 4,
            lineHeightMultiple: 1.2,
            font: font
        )

        // Clear cache
        cache?.clear()

        // Get the same style again
        let style2 = cache?.paragraphStyle(
            tabWidth: 4,
            lineHeightMultiple: 1.2,
            font: font
        )

        // Should be a different instance after clearing
        XCTAssertNotIdentical(style1, style2, "After clearing cache, should create new instance")
    }

    // MARK: - Style Properties Tests

    func testParagraphStyleProperties() {
        let font = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)

        let style = cache?.paragraphStyle(
            tabWidth: 4,
            lineHeightMultiple: 1.5,
            font: font
        )

        // Check line height multiple
        XCTAssertEqual(style?.lineHeightMultiple ?? 0, 1.5, accuracy: 0.001)

        // Check tab stops
        XCTAssertFalse(style?.tabStops.isEmpty ?? true, "Should have tab stops")

        // Check default tab interval
        XCTAssertGreaterThan(style?.defaultTabInterval ?? 0, 0, "Should have positive default tab interval")
    }

    func testHiddenParagraphStyle() {
        let hiddenStyle = ParagraphStyleCache.hiddenParagraphStyle

        // Check that all height properties are zero
        XCTAssertEqual(hiddenStyle.minimumLineHeight, 0)
        XCTAssertEqual(hiddenStyle.maximumLineHeight, 0)
        XCTAssertEqual(hiddenStyle.lineSpacing, 0)
        XCTAssertEqual(hiddenStyle.paragraphSpacing, 0)
        XCTAssertEqual(hiddenStyle.paragraphSpacingBefore, 0)
    }

    // MARK: - MainActor Safety Tests

    func testMainActorSafety() {
        // Test multiple sequential accesses on MainActor
        let testCache = cache

        for index in 0..<100 {
            let font = PlatformFonts.monospacedSystemFont(ofSize: CGFloat(12 + (index % 5)), weight: .regular)

            _ = testCache?.paragraphStyle(
                tabWidth: 4 + (index % 3),
                lineHeightMultiple: 1.0 + CGFloat(index % 5) * 0.1,
                font: font
            )
        }

        // Test passed if no crashes occurred
        XCTAssertNotNil(testCache, "Cache should remain valid after multiple accesses")
    }

    // MARK: - Performance Tests

    func testCachePerformance() {
        let font = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)

        measure(options: Self.standardMeasureOptions) {
            for index in 0..<1_000 {
                // Use only a few different parameter combinations to test cache hits
                _ = cache?.paragraphStyle(
                    tabWidth: 4 + (index % 3),
                    lineHeightMultiple: 1.0 + CGFloat(index % 3) * 0.2,
                    font: font
                )
            }
        }
    }

    func testSharedInstanceAvailability() {
        let shared = CodeEditorDependencies.makeParagraphStyleCache()
        XCTAssertNotNil(shared, "Shared instance should be available")

        // Test that shared instance works
        let font = PlatformFonts.monospacedSystemFont(ofSize: 14, weight: .regular)
        let style = shared.paragraphStyle(
            tabWidth: 4,
            lineHeightMultiple: 1.2,
            font: font
        )
        XCTAssertNotNil(style)
    }
}
