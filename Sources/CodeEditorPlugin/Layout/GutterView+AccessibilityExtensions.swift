import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - GutterView Accessibility Support

extension GutterView {
    /// Set up accessibility for the gutter view
    internal func setupAccessibility() {
        #if canImport(UIKit)
        setupAccessibilityUIKit()
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        setupAccessibilityAppKit()
        #endif
    }

    #if canImport(UIKit)
    private func setupAccessibilityUIKit() {
        // Make the gutter accessible as a container
        isAccessibilityElement = false
        accessibilityContainerType = .list

        // Set accessibility label for the gutter
        accessibilityLabel = "Line numbers"
        accessibilityHint = "Shows line numbers for the code editor"
    }

    /// Create accessibility elements for visible line numbers
    internal func updateAccessibilityElements() {
        guard let textView else {
            accessibilityElements = nil
            return
        }

        // Get visible line range
        let visibleRange = getVisibleLineRange()
        var elements: [UIAccessibilityElement] = []

        for lineNumber in visibleRange.lowerBound..<visibleRange.upperBound {
            let element = LineNumberAccessibilityElement(
                lineNumber: lineNumber,
                in: self,
                textView: textView
            )
            elements.append(element)
        }

        accessibilityElements = elements
    }

    /// Get the range of visible line numbers
    private func getVisibleLineRange() -> Range<Int> {
        guard let textView else { return 0..<1 }

        // Calculate visible line range based on scroll position
        let visibleRect = bounds
        let textStorage = textView.textStorage
        let string = String(textStorage.string)

        // Estimate first visible line
        let lineHeight = textView.font?.lineHeight ?? 17.0
        let firstVisibleLine = max(1, Int(visibleRect.minY / lineHeight))
        let lastVisibleLine = min(
            string.components(separatedBy: .newlines).count,
            Int(visibleRect.maxY / lineHeight) + 1
        )

        return firstVisibleLine..<(lastVisibleLine + 1)
    }

    #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
    private func setupAccessibilityAppKit() {
        // macOS accessibility configuration
        setAccessibilityRole(.list)
        setAccessibilityRoleDescription("Line numbers")
        setAccessibilityLabel("Line numbers for code editor")
        setAccessibilityEnabled(true)
    }

    /// Create accessibility elements for visible line numbers (macOS)
    internal func updateAccessibilityElements() {
        guard let textView else {
            setAccessibilityChildren(nil)
            return
        }

        // Get visible line range
        let visibleRange = getVisibleLineRange()
        var elements: [NSAccessibilityElement] = []

        for lineNumber in visibleRange.lowerBound..<visibleRange.upperBound {
            let element = LineNumberAccessibilityElement(
                lineNumber: lineNumber,
                in: self,
                textView: textView
            )
            elements.append(element)
        }

        setAccessibilityChildren(elements)
    }

    /// Get the range of visible line numbers (macOS)
    private func getVisibleLineRange() -> Range<Int> {
        guard let textView else { return 0..<1 }

        // Calculate visible line range based on scroll position
        let visibleRect = bounds
        let textStorage = textView.textStorage
        let string = textStorage?.string ?? ""

        // Estimate first visible line
        let lineHeight = textView.font?.capHeight ?? 17.0
        let firstVisibleLine = max(1, Int(visibleRect.minY / lineHeight))
        let lastVisibleLine = min(
            String(string).components(separatedBy: .newlines).count,
            Int(visibleRect.maxY / lineHeight) + 1
        )

        return firstVisibleLine..<(lastVisibleLine + 1)
    }
    #endif
}

// MARK: - Line Number Accessibility Element

#if canImport(UIKit)
/// Custom accessibility element for individual line numbers
class LineNumberAccessibilityElement: UIAccessibilityElement {
    private let lineNumber: Int
    private weak var containerView: GutterView?
    private weak var textView: CodeEditorView?

    init(lineNumber: Int, in containerView: GutterView, textView: CodeEditorView) {
        self.lineNumber = lineNumber
        self.containerView = containerView
        self.textView = textView
        super.init(accessibilityContainer: containerView)

        setupAccessibility()
    }

    private func setupAccessibility() {
        setupAccessibilityUIKit()
    }

    private func setupAccessibilityUIKit() {
        isAccessibilityElement = true
        accessibilityTraits = [.staticText, .button]
        accessibilityLabel = "Line \(lineNumber)"

        // Add contextual information if available
        if textView != nil,
           let lineContent = getLineContent() {
            let trimmedContent = lineContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedContent.isEmpty {
                let preview = String(trimmedContent.prefix(50))
                accessibilityHint = "Contains: \(preview)"
            }
        }
    }

    override var accessibilityFrame: CGRect {
        get {
            guard let containerView else { return .zero }

            // Calculate frame for this line number
            let lineHeight = textView?.font?.lineHeight ?? 17.0
            let y = CGFloat(lineNumber - 1) * lineHeight
            let frame = CGRect(x: 0, y: y, width: containerView.bounds.width, height: lineHeight)

            // Convert to screen coordinates
            return containerView.convert(frame, to: nil)
        }
        set {
            // Not settable
        }
    }

    override func accessibilityActivate() -> Bool {
        // Jump to this line when activated
        jumpToLine()
        return true
    }

    // MARK: - Helper Methods

    /// Get the content of the line
    private func getLineContent() -> String? {
        guard let textView else { return nil }

        #if canImport(UIKit)
        let text = textView.text ?? ""
        #else
        let text = textView.string
        #endif
        let lines = String(text).components(separatedBy: .newlines)

        guard lineNumber > 0 && lineNumber <= lines.count else { return nil }
        return lines[lineNumber - 1]
    }

    /// Jump to the line when activated
    @MainActor
    private func jumpToLine() {
        guard let textView else { return }

        #if canImport(UIKit)
        let text = textView.text ?? ""
        #else
        let text = textView.string
        #endif
        let lines = String(text).components(separatedBy: .newlines)

        // Calculate character position for the start of the line
        var position = 0
        for index in 0..<min(lineNumber - 1, lines.count) {
            position += lines[index].count + 1 // +1 for newline
        }

        // Set selection to start of line
        let range = NSRange(location: position, length: 0)
        #if canImport(UIKit)
        // For UIKit, we need to use text positions
        if let start = textView.position(from: textView.beginningOfDocument, offset: position),
           let end = textView.position(from: start, offset: 0) {
            textView.selectedTextRange = textView.textRange(from: start, to: end)
        }

        // Scroll to make the line visible
        if let start = textView.position(from: textView.beginningOfDocument, offset: position) {
            let rect = textView.caretRect(for: start)
            textView.scrollRectToVisible(rect, animated: true)
        }
        #else
        textView.setSelectedRange(range)

        // Scroll to make the line visible
        textView.scrollRangeToVisible(range)
        #endif

        // Announce the navigation
        textView.announceChange("Jumped to line \(lineNumber)")
    }
}

#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
/// Custom accessibility element for individual line numbers
final class LineNumberAccessibilityElement: NSAccessibilityElement, @unchecked Sendable {
    private let lineNumber: Int

    init(lineNumber: Int, in _: GutterView, textView _: CodeEditorView) {
        self.lineNumber = lineNumber
        super.init()

        setupAccessibility()
    }

    private func setupAccessibility() {
        setupAccessibilityAppKit()
    }

    private func setupAccessibilityAppKit() {
        // NSAccessibilityElement properties are set directly
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("Line \(lineNumber)")
        setAccessibilityHelp("Click to jump to line \(lineNumber)")
    }

    override func accessibilityFrame() -> NSRect {
        // Return a basic frame - actual positioning is handled by parent
        let lineHeight = 17.0
        let y = CGFloat(lineNumber - 1) * lineHeight
        return NSRect(x: 0, y: y, width: 50, height: lineHeight)
    }

    override func accessibilityPerformPress() -> Bool {
        // The action will be handled by the parent GutterView
        true
    }
}
#endif
