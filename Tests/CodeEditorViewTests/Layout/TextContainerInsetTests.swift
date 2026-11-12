#if canImport(AppKit)
import AppKit
import CodeEditorAnnotations
import CodeEditorCommon
import CodeEditorConfiguration
import CodeEditorPlatform
@testable import CodeEditorView
import XCTest

/// `layout.textContainerInset` used to be stored, encoded and offered by host
/// settings while the macOS editor ignored it. These tests pin what it does
/// now: each edge is added to the editor's own padding, an untouched
/// configuration renders as it always did, and everything placed over the
/// text starts from the container's origin rather than from AppKit's
/// symmetric inset.
@MainActor
final class TextContainerInsetTests: XCTestCase {
    /// Asymmetric on both axes, so a site that reads the symmetric inset
    /// (the mean of each pair) cannot pass by accident.
    private let inset = EdgeInsets(top: 12, left: 20, bottom: 30, right: 44)

    private static let longDocument = (1...120)
        .map { "let value\($0) = \($0) // " + String(repeating: "word ", count: 40) }
        .joined(separator: "\n")

    private var windows: [NSWindow] = []

    override func setUp() async throws {
        try await super.setUp()
        windows = []
    }

    override func tearDown() async throws {
        windows.forEach { $0.close() }
        windows.removeAll()
        try await super.tearDown()
    }

    // MARK: - Fixtures

    private func makeContainer(
        text: String = TextContainerInsetTests.longDocument,
        _ change: (inout EditorConfiguration) -> Void = { _ in }
    ) -> CodeEditorContainerView {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 600, height: 400))
        var configuration = container.configuration
        change(&configuration)
        container.configuration = configuration
        container.textView.string = text
        settle(container)
        return container
    }

    private func configure(_ container: CodeEditorContainerView, _ change: (inout EditorConfiguration) -> Void) {
        var configuration = container.configuration
        change(&configuration)
        container.configuration = configuration
        settle(container)
    }

    private func settle(_ container: CodeEditorContainerView) {
        container.layoutSubtreeIfNeeded()
        if let layoutManager = container.textView.textLayoutManager {
            layoutManager.ensureLayout(for: layoutManager.documentRange)
            // AppKit sizes the text view to its text during a viewport
            // layout, which on screen comes with every display pass.
            layoutManager.textViewportLayoutController.layoutViewport()
        }
        container.layoutSubtreeIfNeeded()
    }

    private func host(_ container: CodeEditorContainerView) {
        let window = NSWindow(contentRect: container.frame, styleMask: [.titled], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.contentView = container
        windows.append(window)
        settle(container)
    }

    /// The editor's own horizontal padding: what `lineNumberPadding` gives.
    private func ownPadding(_ container: CodeEditorContainerView) -> CGFloat {
        let padding = container.configuration.layout.lineNumberPadding
        return container.configuration.display.isLineNumbersEnabled ? padding : padding / 2
    }

    /// The extent of the laid-out text, in the text container's coordinates.
    private func documentExtent(_ view: CodeEditorView) throws -> CGRect {
        let layoutManager = try XCTUnwrap(view.textLayoutManager)
        layoutManager.ensureLayout(for: layoutManager.documentRange)
        var extent = CGRect.null
        layoutManager.enumerateTextLayoutFragments(from: layoutManager.documentRange.location) { fragment in
            for line in fragment.textLineFragments {
                extent = extent.union(line.typographicBounds.offsetBy(
                    dx: fragment.layoutFragmentFrame.minX,
                    dy: fragment.layoutFragmentFrame.minY
                ))
            }
            return true
        }
        return extent
    }

    private func lineHeight(_ view: CodeEditorView) -> CGFloat {
        view.lineGeometryStore.estimatedRect(forLineAt: 0, containerWidth: 100).height
    }

    /// Every combination the inset has to hold in.
    private func forEachArrangement(
        _ body: (_ container: CodeEditorContainerView, _ label: String) throws -> Void
    ) rethrows {
        for wrap in [false, true] {
            for gutter in [false, true] {
                for minimap in [false, true] {
                    let container = makeContainer {
                        $0.layout.wrapLines = wrap
                        $0.display.isLineNumbersEnabled = gutter
                        $0.display.isMinimapVisible = minimap
                        $0.layout.textContainerInset = self.inset
                    }
                    try body(container, "wrap: \(wrap), gutter: \(gutter), minimap: \(minimap)")
                }
            }
        }
    }

    // MARK: - A host that never sets the inset

    func testTheDefaultInsetIsZero() {
        XCTAssertEqual(EditorConfiguration().layout.textContainerInset, .zero)
        XCTAssertEqual(PlatformConstants.defaultTextContainerInset, .zero)
    }

    func testAnUntouchedConfigurationRendersAsBefore() {
        for wrap in [false, true] {
            for minimap in [false, true] {
                let container = makeContainer {
                    $0.layout.wrapLines = wrap
                    $0.display.isMinimapVisible = minimap
                    $0.display.isLineNumbersEnabled = true
                }
                let view = container.textView
                let padding = container.configuration.layout.lineNumberPadding
                let label = "wrap: \(wrap), minimap: \(minimap)"

                // Exactly what the editor set before the inset was read:
                // `lineNumberPadding` on both sides, nothing above or below.
                XCTAssertEqual(view.textContainerInset, NSSize(width: padding, height: 0), label)
                XCTAssertEqual(view.textContainerOriginShift, .zero, label)
                XCTAssertEqual(view.textContainerOrigin, NSPoint(x: padding, y: 0), label)

                configure(container) { $0.display.isLineNumbersEnabled = false }
                XCTAssertEqual(view.textContainerInset, NSSize(width: padding / 2, height: 0), label)
                XCTAssertEqual(view.textContainerOrigin, NSPoint(x: padding / 2, y: 0), label)
            }
        }
    }

    // MARK: - Each edge

    func testTopAndLeftMoveTheTextContainer() {
        forEachArrangement { container, label in
            let view = container.textView
            let origin = view.textContainerOrigin
            XCTAssertEqual(origin.x, ownPadding(container) + inset.left, accuracy: 0.01, label)
            XCTAssertEqual(origin.y, inset.top, accuracy: 0.01, label)

            // AppKit itself places the text there: a point just inside the
            // origin is the first character, and one line further down, left
            // of the text, is the start of the second line.
            XCTAssertEqual(view.characterIndexForInsertion(at: NSPoint(x: origin.x + 1, y: origin.y + 1)), 0, label)
            guard !container.configuration.layout.wrapLines else { return }
            let secondLineStart = view.lineGeometryStore.utf16Offset(forLineIndex: 1)
            let leftOfSecondLine = NSPoint(x: origin.x - 4, y: origin.y + lineHeight(view) * 1.5)
            XCTAssertEqual(view.characterIndexForInsertion(at: leftOfSecondLine), secondLineStart, label)
        }
    }

    func testBottomIsLeftBelowTheLastLine() throws {
        try forEachArrangement { container, label in
            let view = container.textView
            let extent = try documentExtent(view)
            let below = view.frame.height - (view.textContainerOrigin.y + extent.maxY)
            XCTAssertEqual(below, inset.bottom, accuracy: 1, label)
        }
    }

    func testRightNarrowsTheWrappingWidth() throws {
        try forEachArrangement { container, label in
            guard container.configuration.layout.wrapLines else { return }
            let view = container.textView
            let textContainer = try XCTUnwrap(view.textContainer)
            let viewWidth = try XCTUnwrap(view.enclosingScrollView).contentView.bounds.width
            let rightEdge = view.textContainerOrigin.x + textContainer.size.width
            XCTAssertEqual(viewWidth - rightEdge, ownPadding(container) + inset.right, accuracy: 0.5, label)

            let extent = try documentExtent(view)
            XCTAssertLessThanOrEqual(extent.maxX, textContainer.size.width + 0.5, label)
        }
    }

    /// Without wrapping the container is unbounded, so the right inset is not
    /// a width: it is the room AppKit adds after the longest line when it
    /// sizes the view to its text, which it takes from the symmetric inset
    /// (text width plus twice the inset's width). What is left after the
    /// origin has taken the left-hand share must be the right inset.
    ///
    /// The view's resulting frame is not asserted: headless, AppKit sizes it
    /// from an estimate of the text's width that varies between runs, and the
    /// container caps the view's `maxSize` at its first width whatever the
    /// inset is.
    func testRightIsTheRoomAfterTheTextWithoutWrapping() throws {
        try forEachArrangement { container, label in
            guard !container.configuration.layout.wrapLines else { return }
            let view = container.textView
            let textContainer = try XCTUnwrap(view.textContainer)
            XCTAssertFalse(textContainer.widthTracksTextView, label)
            XCTAssertEqual(textContainer.size.width, CGFloat.greatestFiniteMagnitude, label)

            let addedByAppKit = view.textContainerInset.width * 2
            let roomAfterText = addedByAppKit - view.textContainerOrigin.x
            XCTAssertEqual(roomAfterText, ownPadding(container) + inset.right, accuracy: 0.01, label)
        }
    }

    func testEachEdgeIsIndependent() {
        let container = makeContainer { $0.display.isLineNumbersEnabled = true }
        let view = container.textView
        let padding = ownPadding(container)
        let edges: [(WritableKeyPath<EdgeInsets, CGFloat>, String)] = [
            (\.top, "top"), (\.left, "left"), (\.bottom, "bottom"), (\.right, "right")
        ]

        for (edge, name) in edges {
            var only = EdgeInsets.zero
            only[keyPath: edge] = 17
            configure(container) { $0.layout.textContainerInset = only }

            var expected = EdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
            expected[keyPath: edge] += 17
            let applied = view.unifiedTextContainerInsets
            XCTAssertEqual(applied.top, expected.top, accuracy: 0.01, name)
            XCTAssertEqual(applied.left, expected.left, accuracy: 0.01, name)
            XCTAssertEqual(applied.bottom, expected.bottom, accuracy: 0.01, name)
            XCTAssertEqual(applied.right, expected.right, accuracy: 0.01, name)
        }

        configure(container) { $0.layout.textContainerInset = .zero }
        XCTAssertEqual(view.textContainerInset, NSSize(width: padding, height: 0))
        XCTAssertEqual(view.textContainerOriginShift, .zero)
    }

    func testNegativeEdgesAreTreatedAsZero() {
        let container = makeContainer {
            $0.display.isLineNumbersEnabled = true
            $0.layout.textContainerInset = EdgeInsets(top: -5, left: -50, bottom: -5, right: -50)
        }
        let padding = ownPadding(container)
        XCTAssertEqual(container.textView.textContainerInset, NSSize(width: padding, height: 0))
        XCTAssertEqual(container.textView.textContainerOrigin, NSPoint(x: padding, y: 0))
    }

    // MARK: - Line number padding

    func testLineNumberPaddingKeepsItsOwnEffect() {
        forEachArrangement { container, label in
            let view = container.textView
            let before = view.unifiedTextContainerInsets
            let factor: CGFloat = container.configuration.display.isLineNumbersEnabled ? 1 : 0.5

            configure(container) { $0.layout.lineNumberPadding += 10 }
            let after = view.unifiedTextContainerInsets
            XCTAssertEqual(after.left - before.left, 10 * factor, accuracy: 0.01, label)
            XCTAssertEqual(after.right - before.right, 10 * factor, accuracy: 0.01, label)
            XCTAssertEqual(after.top, before.top, accuracy: 0.01, label)
            XCTAssertEqual(after.bottom, before.bottom, accuracy: 0.01, label)
        }
    }

    func testTogglingTheGutterKeepsTheInset() {
        let container = makeContainer {
            $0.display.isLineNumbersEnabled = true
            $0.layout.textContainerInset = self.inset
        }
        let view = container.textView
        let padding = container.configuration.layout.lineNumberPadding

        container.showsLineNumbers = false
        settle(container)
        XCTAssertEqual(view.textContainerOrigin.x, padding / 2 + inset.left, accuracy: 0.01)
        XCTAssertEqual(view.textContainerOrigin.y, inset.top, accuracy: 0.01)
        XCTAssertEqual(container.baseTextContainerInsetWidth, padding / 2, accuracy: 0.01)

        container.showsLineNumbers = true
        settle(container)
        XCTAssertEqual(view.textContainerOrigin.x, padding + inset.left, accuracy: 0.01)
        XCTAssertEqual(view.unifiedTextContainerInsets.right, padding + inset.right, accuracy: 0.01)
        XCTAssertEqual(container.baseTextContainerInsetWidth, padding, accuracy: 0.01)
    }

    // MARK: - The view's own four-edge API

    func testTheViewRoundTripsFourEdges() {
        let view = CodeEditorView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        view.setUnifiedTextContainerInsets(inset)
        XCTAssertEqual(view.unifiedTextContainerInsets, inset)
        XCTAssertEqual(view.textContainerOrigin, NSPoint(x: inset.left, y: inset.top))
        // AppKit sizes the view and a tracking container from the symmetric
        // inset, so it has to hold the mean of each pair.
        XCTAssertEqual(view.textContainerInset.width * 2, inset.left + inset.right, accuracy: 0.01)
        XCTAssertEqual(view.textContainerInset.height * 2, inset.top + inset.bottom, accuracy: 0.01)
        XCTAssertNotNil(view.textLayoutManager, "the override must not drop the view to TextKit 1")

        view.setUnifiedTextContainerInsets(.zero)
        XCTAssertEqual(view.textContainerOriginShift, .zero)
        XCTAssertEqual(view.textContainerOrigin, .zero)
    }

    // MARK: - Geometry consumers

    func testAnAnnotationIsPlacedFromTheContainerOrigin() throws {
        try forEachArrangement { container, label in
            let view = container.textView
            let dataSource = TestAnnotationDataSource()
            view.annotationsDataSource = dataSource
            let annotation = Annotation(range: NSRange(location: 4, length: 6), content: "note", kind: .warning)
            view.addAnnotation(annotation)

            let layoutManager = try XCTUnwrap(view.textLayoutManager)
            let textRange = try XCTUnwrap(view.textKitBridge.textRangeFromNSRange(annotation.range))
            let segment = try XCTUnwrap(layoutManager.textSegmentFrame(in: textRange, type: .standard))
            let badge = container.configuration.layout.annotationBadgeSize
            let badgePadding = container.configuration.layout.annotationBadgePadding
            let origin = view.textContainerOrigin
            let expected = CGRect(
                x: origin.x + segment.maxX + badgePadding,
                y: origin.y + segment.midY - badge / 2,
                width: badge,
                height: badge
            ).integral

            let frame = try XCTUnwrap(view.annotationViews[annotation.id]).frame
            XCTAssertEqual(frame, expected, label)
            // Not where the symmetric inset would have put it.
            XCTAssertNotEqual(frame.minY, (view.textContainerInset.height + segment.midY - badge / 2).rounded(.down), label)
        }
    }

    func testTheSelectedLineHighlightSitsOnItsLine() throws {
        try forEachArrangement { container, label in
            let view = container.textView
            configure(container) { $0.display.isSelectedLineHighlighted = true }
            let thirdLine = view.lineGeometryStore.utf16Offset(forLineIndex: 2)
            view.setSelectedRange(NSRange(location: thirdLine, length: 0))
            view.updateSelectedLineHighlight()

            let lineRange = NSRange(
                location: thirdLine,
                length: view.lineGeometryStore.utf16Offset(forLineIndex: 3) - thirdLine
            )
            let lineRect = try XCTUnwrap(view.calculateLineRect(for: lineRange))
            let highlight = try XCTUnwrap(view.lineHighlightView)
            XCTAssertEqual(highlight.frame.minY, view.textContainerOrigin.y + lineRect.minY, accuracy: 0.5, label)
            XCTAssertEqual(highlight.frame.minX, 0, label)
            XCTAssertEqual(highlight.frame.width, view.bounds.width, accuracy: 0.5, label)
        }
    }

    func testLinePositionsAndPointsGoThroughTheContainerOrigin() throws {
        try forEachArrangement { container, label in
            guard !container.configuration.layout.wrapLines else { return }
            let view = container.textView
            let origin = view.textContainerOrigin
            let height = lineHeight(view)
            let service = LineNumberCalculationService()

            // Line 3 starts two line heights below the container's origin.
            let position = try XCTUnwrap(
                service.calculateLinePosition(lineNumber: 3, in: view, configuration: container.configuration)
            )
            XCTAssertEqual(position, origin.y + 2 * height, accuracy: 0.5, label)

            // And a point in the view maps back to the line drawn there.
            let inThirdLine = CGPoint(x: origin.x + 10, y: origin.y + 2.5 * height)
            XCTAssertEqual(service.lineNumber(at: inThirdLine, in: view), 3, label)
            XCTAssertEqual(TextKitLineNumberHelper(textView: view).lineNumber(at: inThirdLine), 3, label)

            // The top padding belongs to no later line: it is the first.
            let inTopPadding = CGPoint(x: origin.x + 10, y: origin.y / 2)
            XCTAssertEqual(TextKitLineNumberHelper(textView: view).lineNumber(at: inTopPadding), 1, label)

            // A point this far down would be line 3 if the top inset were
            // ignored; with it, the point is still on line 2.
            let nearTopOfThirdLine = CGPoint(x: origin.x + 10, y: 2 * height + 1)
            XCTAssertEqual(TextKitLineNumberHelper(textView: view).lineNumber(at: nearTopOfThirdLine), 2, label)
        }
    }

    func testTheVisibleRangeStartsAtTheFirstLine() throws {
        try forEachArrangement { container, label in
            host(container)
            let view = container.textView
            let visible = try XCTUnwrap(view.textKitBridge.visibleRange, label)
            XCTAssertEqual(visible.location, 0, label)
            XCTAssertLessThan(NSMaxRange(visible), view.string.utf16.count, label)

            // The same rectangle in the container's coordinates, which is
            // what layout fragment frames are compared against.
            let origin = view.textContainerOrigin
            XCTAssertEqual(
                view.visibleContainerRect,
                view.visibleRect.offsetBy(dx: -origin.x, dy: -origin.y),
                label
            )
        }
    }

    // MARK: - What is drawn

    /// The bounding box, in points from the top left, of everything drawn
    /// in `view` that is not its background (its most common colour).
    private func inkBounds(of view: NSView) throws -> CGRect {
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        let data = try XCTUnwrap(rep.bitmapData)
        let samples = rep.samplesPerPixel
        let rowBytes = rep.bytesPerRow
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        XCTAssertGreaterThanOrEqual(samples, 3)

        func key(_ x: Int, _ y: Int) -> UInt32 {
            let pixel = data + y * rowBytes + x * samples
            return UInt32(pixel[0]) << 16 | UInt32(pixel[1]) << 8 | UInt32(pixel[2])
        }
        func distance(_ first: UInt32, _ second: UInt32) -> Int {
            var total = 0
            for shift in [UInt32(16), 8, 0] {
                total += abs(Int((first >> shift) & 0xFF) - Int((second >> shift) & 0xFF))
            }
            return total
        }

        var counts: [UInt32: Int] = [:]
        for y in 0..<height {
            for x in 0..<width {
                counts[key(x, y), default: 0] += 1
            }
        }
        let background = try XCTUnwrap(counts.max { $0.value < $1.value }?.key)

        var minX = Int.max
        var minY = Int.max
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width where distance(key(x, y), background) > 96 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return .null }
        let scale = CGFloat(width) / view.bounds.width
        return CGRect(
            x: CGFloat(minX) / scale,
            y: CGFloat(minY) / scale,
            width: CGFloat(maxX - minX + 1) / scale,
            height: CGFloat(maxY - minY + 1) / scale
        )
    }

    private func makeDrawnContainer(gutter: Bool) -> CodeEditorContainerView {
        let container = makeContainer(text: "MMMM\nMMMM\nMMMM") {
            $0.display.isLineNumbersEnabled = gutter
            // Both draw across the padding and would hide where the text is.
            $0.display.isSelectedLineHighlighted = false
            $0.display.isMinimapVisible = false
        }
        host(container)
        return container
    }

    func testTheTextIsDrawnAtTheContainerOriginAndFollowsIt() throws {
        let container = makeDrawnContainer(gutter: false)
        let view = container.textView
        let before = try inkBounds(of: view)
        XCTAssertFalse(before.isNull, "the text view drew nothing")
        let linePadding = try XCTUnwrap(view.textContainer).lineFragmentPadding
        XCTAssertEqual(before.minX, view.textContainerOrigin.x + linePadding, accuracy: 2)

        configure(container) { $0.layout.textContainerInset = self.inset }
        let moved = try inkBounds(of: view)
        XCTAssertEqual(moved.minX - before.minX, inset.left, accuracy: 1)
        XCTAssertEqual(moved.minY - before.minY, inset.top, accuracy: 1)

        // Mirrored edges give AppKit the same symmetric inset, so only the
        // origin's shift changes: the text already laid out has to move too.
        let mirrored = EdgeInsets(top: inset.bottom, left: inset.right, bottom: inset.top, right: inset.left)
        let symmetricBefore = view.textContainerInset
        configure(container) { $0.layout.textContainerInset = mirrored }
        XCTAssertEqual(view.textContainerInset, symmetricBefore)
        let mirroredInk = try inkBounds(of: view)
        XCTAssertEqual(mirroredInk.minX - before.minX, mirrored.left, accuracy: 1)
        XCTAssertEqual(mirroredInk.minY - before.minY, mirrored.top, accuracy: 1)
    }

    func testTheGutterNumbersFollowTheTopInset() throws {
        let container = makeDrawnContainer(gutter: true)
        let ruler = try XCTUnwrap(container.scrollView.verticalRulerView)
        let before = try inkBounds(of: ruler)
        XCTAssertFalse(before.isNull, "the gutter drew nothing")

        configure(container) { $0.layout.textContainerInset = self.inset }
        let after = try inkBounds(of: ruler)
        XCTAssertEqual(after.minY - before.minY, inset.top, accuracy: 1)
        XCTAssertEqual(after.minX, before.minX, accuracy: 1, "the left inset must not move the numbers")
        XCTAssertEqual(ruler.ruleThickness, container.configuration.layout.gutterWidth)
    }

    // MARK: - Coding

    func testTheInsetRoundTripsThroughCoding() throws {
        var layout = EditorConfiguration.Layout()
        layout.textContainerInset = inset
        let decoded = try JSONDecoder().decode(
            EditorConfiguration.Layout.self,
            from: JSONEncoder().encode(layout)
        )
        XCTAssertEqual(decoded.textContainerInset, inset)

        let empty = try JSONDecoder().decode(EditorConfiguration.Layout.self, from: Data("{}".utf8))
        XCTAssertEqual(empty.textContainerInset, .zero)
    }
}
#endif
