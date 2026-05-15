#if canImport(AppKit)
import AppKit
@testable import CodeEditorPlugin
import XCTest

@MainActor
final class TextRenderingVisibilityTests: XCTestCase {
    func testCodeEditorViewKeepsTextViewportDelegateAttachedToTextView() throws {
        let textView = CodeEditorView(frame: NSRect(origin: .zero, size: NSSize(width: 320, height: 180)))
        let viewportDelegate = try XCTUnwrap(
            textView.textLayoutManager?.textViewportLayoutController.delegate
        )

        XCTAssertTrue(
            (viewportDelegate as AnyObject) === textView,
            "NSTextView must remain the TextKit2 viewport delegate so AppKit can configure rendering surfaces."
        )
    }

    func testPlainNSTextViewHarnessDrawsVisibleForegroundPixels() throws {
        let size = NSSize(width: 640, height: 220)
        let textView = NSTextView(frame: NSRect(origin: .zero, size: size))
        textView.string = "VISIBLE TEXT\nsecond line"
        textView.font = .monospacedSystemFont(ofSize: 24, weight: .regular)
        textView.textColor = .white
        textView.backgroundColor = .black
        textView.drawsBackground = true

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        defer { window.close() }
        window.contentView = textView
        window.makeKeyAndOrderFront(nil)

        let rep = try bitmapImageRep(for: textView)
        XCTAssertGreaterThan(
            brightOpaquePixelCount(in: rep),
            120,
            "The bitmap harness should see foreground pixels for a plain NSTextView."
        )
    }

    func testDirectCodeEditorViewDrawsVisibleForegroundPixelsWithSystemColors() throws {
        let size = NSSize(width: 640, height: 220)
        let textView = CodeEditorView(frame: NSRect(origin: .zero, size: size))

        var configuration = EditorConfiguration.minimal
        configuration.display.fontSize = 24
        configuration.display.isSelectedLineHighlighted = false
        configuration.performance.useHardwareAcceleration = false
        textView.configuration = configuration

        textView.string = "VISIBLE TEXT\nsecond line"
        textView.font = .monospacedSystemFont(ofSize: 24, weight: .regular)
        textView.textColor = .white
        textView.backgroundColor = .black
        textView.drawsBackground = true

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        defer { window.close() }
        window.contentView = textView
        window.makeKeyAndOrderFront(nil)

        let rep = try bitmapImageRep(for: textView)
        XCTAssertGreaterThan(
            brightOpaquePixelCount(in: rep),
            120,
            "A direct CodeEditorView should draw foreground pixels when given explicit system colors."
        )
    }

    func testDirectCodeEditorViewDrawsVisibleForegroundPixelsWithThemeApplied() throws {
        let size = NSSize(width: 640, height: 220)
        let textView = CodeEditorView(frame: NSRect(origin: .zero, size: size))

        var configuration = EditorConfiguration.minimal
        configuration.display.fontSize = 24
        configuration.display.isLineNumbersEnabled = false
        configuration.display.isSelectedLineHighlighted = false
        configuration.layout.wrapLines = false
        configuration.performance.useHardwareAcceleration = false

        textView.configuration = configuration
        textView.language = .plainText
        textView.string = "VISIBLE TEXT\nsecond line"
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.apply(theme: .lcarsDark)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        defer { window.close() }
        window.contentView = textView
        window.makeKeyAndOrderFront(nil)

        if let documentRange = textView.textLayoutManager?.documentRange {
            textView.textLayoutManager?.ensureLayout(for: documentRange)
        }

        let rep = try bitmapImageRep(for: textView)
        XCTAssertGreaterThan(
            brightOpaquePixelCount(in: rep),
            120,
            "A direct themed CodeEditorView should draw foreground pixels."
        )
    }

    func testTextViewDrawsVisibleForegroundPixelsWithThemeApplied() throws {
        let size = NSSize(width: 640, height: 220)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let container = CodeEditorContainerView(frame: NSRect(origin: .zero, size: size))
        defer { window.close() }

        var configuration = EditorConfiguration.minimal
        configuration.display.fontSize = 24
        configuration.display.isLineNumbersEnabled = false
        configuration.display.isSelectedLineHighlighted = false
        configuration.layout.wrapLines = false
        configuration.performance.useHardwareAcceleration = false

        container.configuration = configuration
        container.textView.language = .plainText
        container.textView.string = "VISIBLE TEXT\nsecond line"
        container.textView.setSelectedRange(NSRange(location: 0, length: 0))
        container.apply(theme: .lcarsDark)

        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        container.layoutSubtreeIfNeeded()
        container.displayIfNeeded()

        if let documentRange = container.textView.textLayoutManager?.documentRange {
            container.textView.textLayoutManager?.ensureLayout(for: documentRange)
        }

        let rep = try bitmapImageRep(for: container.textView)
        let brightPixels = brightOpaquePixelCount(in: rep)

        XCTAssertGreaterThan(
            brightPixels,
            120,
            "Expected themed foreground glyph pixels in the rendered text view, but the bitmap is effectively blank."
        )
    }

    private func bitmapImageRep(for view: NSView) throws -> NSBitmapImageRep {
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()

        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }

    private func brightOpaquePixelCount(in rep: NSBitmapImageRep) -> Int {
        var count = 0

        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.5
                else {
                    continue
                }

                let luminance =
                    (0.2126 * color.redComponent) +
                    (0.7152 * color.greenComponent) +
                    (0.0722 * color.blueComponent)

                if luminance > 0.55 {
                    count += 1
                }
            }
        }

        return count
    }
}
#endif
