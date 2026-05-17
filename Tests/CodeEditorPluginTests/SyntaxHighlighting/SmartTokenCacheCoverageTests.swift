@testable import CodeEditorPlugin
import CodeEditorTextModel
import Foundation
import XCTest

/// Regression coverage for the cache-completeness bug where
/// `OptimizedSyntaxHighlightingCoordinator` stored partial viewport
/// tokens under a `CacheKey(text:language:version:)` that ignored
/// coverage, so a later full-document or non-overlapping viewport
/// request could be served from a partial cache entry and silently
/// drop tokens.
///
/// The fix models entry coverage explicitly
/// (`SmartTokenCache.CacheEntry.Coverage`) and rejects incompatible
/// hits. These tests pin both the cache primitive's hit/miss matrix
/// and the coordinator-level sequence the reviewer asked for:
/// viewport A → viewport B → full document.
final class SmartTokenCacheCoverageTests: XCTestCase {
    // MARK: - SmartTokenCache hit/miss matrix

    func testFullDocumentEntrySatisfiesAnyRequest() async {
        let cache = SmartTokenCache()
        let key = SmartTokenCache.CacheKey(text: "abc", language: .swift, version: 0)
        let tokens = [makeToken(at: 0, length: 3)]

        await cache.setCachedTokens(
            tokens,
            for: key,
            computationTime: .milliseconds(5),
            coverage: .fullDocument
        )

        let fullDocHit = await cache.getCachedTokens(for: key)
        XCTAssertEqual(fullDocHit.count, 1, "Full-doc request must hit a full-doc entry")

        let viewportHit = await cache.getCachedTokens(
            for: key,
            viewportRange: NSRange(location: 0, length: 3)
        )
        XCTAssertEqual(viewportHit.count, 1, "Viewport request must hit a full-doc entry (filter to viewport)")
    }

    func testViewportEntryRejectsFullDocumentRequest() async {
        let cache = SmartTokenCache()
        let key = SmartTokenCache.CacheKey(text: "abc", language: .swift, version: 0)
        let tokens = [makeToken(at: 100, length: 10)]

        await cache.setCachedTokens(
            tokens,
            for: key,
            computationTime: .milliseconds(5),
            coverage: .viewport(NSRange(location: 100, length: 10))
        )

        let result = await cache.getCachedTokens(for: key)
        XCTAssertTrue(
            result.isEmpty,
            "Viewport-only entry must NEVER satisfy a full-document request — was the H4 bug"
        )
    }

    func testViewportEntryRejectsNonOverlappingViewportRequest() async {
        let cache = SmartTokenCache()
        let key = SmartTokenCache.CacheKey(text: "abc", language: .swift, version: 0)

        await cache.setCachedTokens(
            [makeToken(at: 100, length: 10)],
            for: key,
            computationTime: .milliseconds(5),
            coverage: .viewport(NSRange(location: 100, length: 10))
        )

        let result = await cache.getCachedTokens(
            for: key,
            viewportRange: NSRange(location: 5_000, length: 50)
        )
        XCTAssertTrue(
            result.isEmpty,
            "Viewport entry must reject a viewport request outside its cached slice"
        )
    }

    func testViewportEntrySatisfiesContainedViewportRequest() async {
        let cache = SmartTokenCache()
        let key = SmartTokenCache.CacheKey(text: "abc", language: .swift, version: 0)
        let tokens = (0..<5).map { makeToken(at: 100 + $0 * 10, length: 5) }

        await cache.setCachedTokens(
            tokens,
            for: key,
            computationTime: .milliseconds(5),
            coverage: .viewport(NSRange(location: 100, length: 200))
        )

        let result = await cache.getCachedTokens(
            for: key,
            viewportRange: NSRange(location: 110, length: 30)
        )
        XCTAssertFalse(
            result.isEmpty,
            "Viewport entry must satisfy a viewport request fully contained in its slice"
        )
    }

    // MARK: - Coordinator regression: viewport A → viewport B → full doc

    @MainActor
    func testFullDocumentRequestAfterViewportsRehighlightsWholeDocument() async {
        // viewportPadding: 0 makes coverage math exact; the regions
        // below are deliberately too far apart to share a viewport
        // slice, which is what exercises the bug.
        let coordinator = OptimizedSyntaxHighlightingCoordinator(
            memoryMonitor: MemoryMonitor(),
            configuration: .init(
                enableViewportOptimization: true,
                viewportPadding: 0,
                maxChunkSize: 50_000,
                enableIncrementalHighlighting: true,
                cacheWarmingEnabled: false,
                circuitBreakerThreshold: 5
            )
        )

        let header = String(repeating: "let x = 0\n", count: 100)
        let regionA = "let REGION_A_MARKER = 1\n"
        let middle = String(repeating: "let y = 0\n", count: 700)
        let regionB = "let REGION_B_MARKER = 2\n"
        let footer = String(repeating: "let z = 0\n", count: 400)
        let source = header + regionA + middle + regionB + footer
        XCTAssertGreaterThan(
            TextRangeUtilities.utf16Length(of: source),
            10_000,
            "Source must exceed the coordinator's viewport-optimization threshold"
        )

        let headerLen = TextRangeUtilities.utf16Length(of: header)
        let regionALen = TextRangeUtilities.utf16Length(of: regionA)
        let middleLen = TextRangeUtilities.utf16Length(of: middle)
        let regionBLen = TextRangeUtilities.utf16Length(of: regionB)

        let viewportA = NSRange(location: headerLen, length: regionALen)
        let viewportB = NSRange(
            location: headerLen + regionALen + middleLen,
            length: regionBLen
        )

        // 1. Highlight viewport A — populates the cache with a
        //    .viewport entry covering region A only.
        let tokensA = await coordinator.highlight(text: source, language: .swift, visibleRange: viewportA)
        XCTAssertTrue(
            tokensA.contains { NSLocationInRange($0.range.location, viewportA) },
            "Viewport A highlight must produce tokens inside region A"
        )

        // 2. Highlight viewport B — with the bug, this would re-filter
        //    the cached region-A tokens through viewport B's expanded
        //    range and return effectively nothing. With the fix, the
        //    incompatible cache entry is rejected and region B is
        //    recomputed.
        let tokensB = await coordinator.highlight(text: source, language: .swift, visibleRange: viewportB)
        XCTAssertTrue(
            tokensB.contains { NSLocationInRange($0.range.location, viewportB) },
            "Viewport B highlight must produce tokens inside region B (cache cannot satisfy this from region-A coverage)"
        )

        // 3. Full-document highlight — must recompute against the
        //    viewport-only cache entry and return tokens for the whole
        //    file, including both regions.
        let tokensFull = await coordinator.highlight(text: source, language: .swift)
        XCTAssertTrue(
            tokensFull.contains { NSLocationInRange($0.range.location, viewportA) },
            "Full-doc highlight must contain tokens inside region A"
        )
        XCTAssertTrue(
            tokensFull.contains { NSLocationInRange($0.range.location, viewportB) },
            "Full-doc highlight must contain tokens inside region B — H4 regression"
        )
        let lastTokenEnd = tokensFull.map { NSMaxRange($0.range) }.max() ?? 0
        XCTAssertGreaterThan(
            lastTokenEnd,
            NSMaxRange(viewportB),
            "Full-doc highlight must cover content past region B"
        )
    }

    // MARK: - Helpers

    private func makeToken(at location: Int, length: Int) -> HighlightedToken {
        HighlightedToken(
            range: NSRange(location: location, length: length),
            type: .keyword,
            text: "x"
        )
    }
}
