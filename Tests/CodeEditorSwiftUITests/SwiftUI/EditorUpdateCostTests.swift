#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import CodeEditorConfiguration
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import DesignKitThemes
import SwiftUI
import XCTest

/// Work done by a SwiftUI update must not be proportional to the document.
/// These put a sized document in a real container and bound the time of the
/// per-update and per-keystroke paths (generous ceilings, debug build).
@MainActor
final class EditorUpdateCostTests: XCTestCase {
    private var window: NSWindow?

    override func setUp() {
        super.setUp()
        window = nil
    }

    override func tearDown() {
        window?.orderOut(nil)
        window?.close()
        window = nil
        super.tearDown()
    }

    private static let lineCount = 20_000

    private func makeContainer() -> CodeEditorContainerView {
        let container = CodeEditorContainerView()
        container.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        let window = NSWindow(contentRect: container.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = container
        self.window = window
        container.textView.string = String(
            repeating: "    let value = editor.selectedRange.location + offset // trailing\n",
            count: Self.lineCount
        )
        container.layoutSubtreeIfNeeded()
        return container
    }

    /// CPU seconds on this thread: a loaded machine does not inflate it.
    private func time(_ body: () -> Void) -> TimeInterval {
        CPUTime.onThread(body).seconds
    }

    func testReapplyingTheSameThemeDoesNotRestampTheDocument() {
        let container = makeContainer()
        container.apply(theme: .dark)
        let stampsAfterMount = container.textView.themeForegroundStampCount

        for _ in 0..<10 { container.apply(theme: .dark) }
        XCTAssertEqual(container.textView.themeForegroundStampCount, stampsAfterMount)

        // A wholesale replacement drops per-range attributes: the next apply
        // must stamp again.
        container.textView.string = "replaced"
        container.apply(theme: .dark)
        XCTAssertEqual(container.textView.themeForegroundStampCount, stampsAfterMount + 1)
    }

    func testSizingAnUnspecifiedProposalAfterAKeystrokeIsCheap() {
        let container = makeContainer()
        let textView = container.textView
        // Without wrapping the estimate is O(log n) (line count and longest
        // line from the line geometry store); with wrapping it adds one pass
        // over line lengths, which is too close to the old cost to time
        // reliably under a loaded parallel run.
        let configuration = EditorConfiguration.default
        textView.setSelectedRange(NSRange(location: 10, length: 0))

        var elapsed: TimeInterval = 0
        for _ in 0..<5 {
            textView.insertText("a", replacementRange: NSRange(location: NSNotFound, length: 0))
            elapsed += time {
                _ = CodeEditorRepresentableHelper.calculateSize(
                    for: container,
                    proposal: ProposedViewSize(width: 600, height: nil),
                    configuration: configuration
                )
                _ = CodeEditorRepresentableHelper.calculateSize(
                    for: container,
                    proposal: .unspecified,
                    configuration: configuration
                )
            }
        }

        // Measuring every line took ~0.2 s per call at this size.
        XCTAssertLessThan(elapsed, 0.5, "10 size estimates took \(elapsed) s")
    }

    func testTheWrappedSizeEstimateCountsWrappedLines() throws {
        let container = makeContainer()
        var configuration = EditorConfiguration.default
        configuration.layout.wrapLines = true
        let narrow = try XCTUnwrap(CodeEditorRepresentableHelper.calculateSize(
            for: container,
            proposal: ProposedViewSize(width: 200, height: nil),
            configuration: configuration
        ))
        let wide = try XCTUnwrap(CodeEditorRepresentableHelper.calculateSize(
            for: container,
            proposal: ProposedViewSize(width: 2_000, height: nil),
            configuration: configuration
        ))

        XCTAssertGreaterThan(narrow.height, wide.height)
    }

    func testTheSizeEstimateCoversTheDocument() throws {
        let container = makeContainer()
        let size = try XCTUnwrap(CodeEditorRepresentableHelper.calculateSize(
            for: container,
            proposal: .unspecified,
            configuration: .default
        ))
        let font = try XCTUnwrap(container.textView.font)
        let lineWidth = NSAttributedString(
            string: "    let value = editor.selectedRange.location + offset // trailing",
            attributes: [.font: font]
        ).size().width

        XCTAssertGreaterThan(size.height, CGFloat(Self.lineCount) * 10)
        XCTAssertGreaterThanOrEqual(size.width, lineWidth * 0.9)
    }

    func testTheAccessibilityLabelUpdateIsCheap() {
        let container = makeContainer()
        let textView = container.textView
        textView.setSelectedRange(NSRange(location: 5_000, length: 0))

        let elapsed = time {
            for _ in 0..<20 { textView.updateAccessibilityLabel() }
        }

        XCTAssertLessThan(elapsed, 0.5, "20 label updates took \(elapsed) s")
        XCTAssertTrue(textView.accessibilityLabel()?.contains("Line 75, Column 43") ?? false, textView.accessibilityLabel() ?? "")
    }
}
#endif
