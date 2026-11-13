import CodeEditorDiagnostics
@testable import CodeEditorSyntaxHighlighting
import XCTest

/// A memory cleanup pass is routine; dropping a highlighting request in
/// flight left the document unhighlighted until the next edit.
@MainActor
final class BackgroundHighlightingMemoryCleanupTests: XCTestCase {
    func testAPassKeepsPendingRequests() async {
        let monitor = MemoryMonitor.mock()
        let highlighter = BackgroundSyntaxHighlighter(memoryMonitor: monitor)
        highlighter.highlightingDelay = 3_600 // stays pending; nothing waits on it
        highlighter.requestHighlighting(text: "let a = 1", language: .swift, requestId: "visible") { _ in }
        XCTAssertEqual(highlighter.pendingRequests.count, 1)

        await monitor.performCleanup()

        XCTAssertEqual(Array(highlighter.pendingRequests.keys), ["visible"])
        highlighter.cancelAllRequests()
    }
}
