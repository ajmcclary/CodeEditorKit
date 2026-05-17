// MARK: - GutterView Cross-Platform Implementation
//
// This file provides a unified GutterView implementation that works across
// both iOS and macOS platforms, eliminating code duplication.

import CodeEditorPlatform
import CodeEditorTheming
import CoreGraphics
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
@MainActor
private final class GutterDisplayLinkTarget: NSObject {
    weak var gutterView: GutterView?

    init(gutterView: GutterView) {
        self.gutterView = gutterView
    }

    @objc func displayLinkFired() {
        gutterView?.displayLinkFired()
    }
}

// Display-link handle for the iOS gutter.
//
// `@unchecked Sendable` rationale: `target` is a constant after init, and
// display-link mutation is explicitly routed through the main thread.
private final class GutterDisplayLinkHandle: @unchecked Sendable {
    private let target: GutterDisplayLinkTarget
    private var displayLink: CADisplayLink?

    @MainActor
    init(gutterView: GutterView) {
        let target = GutterDisplayLinkTarget(gutterView: gutterView)
        let displayLink = CADisplayLink(target: target, selector: #selector(GutterDisplayLinkTarget.displayLinkFired))

        displayLink.add(to: .main, forMode: .common)
        displayLink.isPaused = true

        self.target = target
        self.displayLink = displayLink
    }

    @MainActor
    func setPaused(_ isPaused: Bool) {
        displayLink?.isPaused = isPaused
    }

    deinit {
        let displayLink = displayLink
        if Thread.isMainThread {
            displayLink?.invalidate()
        } else {
            DispatchQueue.main.async {
                displayLink?.invalidate()
            }
        }
    }
}
#endif

// MARK: - GutterView Protocol

/// Protocol defining the common interface for gutter view functionality
@MainActor
public protocol GutterViewProtocol: AnyObject {
    var textView: CodeEditorView? { get set }

    func setNeedsDisplayLineNumbers()
}

// MARK: - Unified GutterView Implementation

/// Cross-platform view for displaying line numbers
@MainActor
public class GutterView: PlatformView, GutterViewProtocol {
    // MARK: - Properties

    public weak var textView: CodeEditorView? {
        didSet {
            // Set up interaction handler when text view is assigned
            if let textView {
                interactionHandler = GutterInteractionHandler(gutterView: self, textView: textView)
            } else {
                interactionHandler = nil
            }
        }
    }

    /// Array to store notification observer tokens for proper cleanup
    internal var observers: [NSObjectProtocol] = []

    /// The renderer responsible for drawing line numbers
    let renderer = GutterViewRenderer()

    /// The interaction handler for clicks/taps
    private var interactionHandler: GutterInteractionHandler?

    /// Theme last applied via `apply(theme:)`. nil before first apply.
    public private(set) var appliedTheme: Theme?

    /// Theme-derived gutter background color. `.clear` until first apply.
    public private(set) var themedBackgroundColor: PlatformColor = .clear

    /// Apply a theme to the gutter. Equality-gated: a second call with the
    /// same theme is a no-op. Updates the renderer's themed colors and
    /// triggers a redraw.
    public func apply(theme: Theme) {
        if appliedTheme == theme { return }
        appliedTheme = theme
        themedBackgroundColor = PlatformColor(tokens: theme.style.editor.gutterBackground)
        renderer.apply(theme: theme)
        setNeedsDisplayLineNumbers()
    }

    #if canImport(UIKit)
    private var displayLinkHandle: GutterDisplayLinkHandle?
    private var lastContentOffset: CGPoint = .zero
    private var pauseTask: Task<Void, Never>?
    #endif

    // MARK: - Initialization

    override public init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        setup()
        setupAccessibility()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupAccessibility()
    }

    // MARK: - Setup

    private func setup() {
        #if canImport(AppKit)
        // Default-on at construction time — config isn't in scope here.
        // The container reapplies the configured value if needed.
        HardwareAcceleration.apply(true, to: self)
        // Make gutter transparent so it doesn't block text
        layer?.backgroundColor = PlatformColors.clear.cgColor
        #else
        // Make gutter transparent on iOS as well to avoid visible white space
        backgroundColor = PlatformColors.clear
        setupDisplayLink()
        #endif

        // Set up click handling for folding controls
        setupClickHandling()
    }

    /// Set up click/tap handling for folding controls
    private func setupClickHandling() {
        // Interaction handling is set up when textView is assigned
        // See the textView property didSet
    }

    // MARK: - Display Updates

    public func setNeedsDisplayLineNumbers() {
        #if canImport(AppKit)
        // Force a complete redraw on macOS to ensure line numbers are visible
        self.needsDisplay = true
        #else
        UnifiedDrawingCoordinator.setNeedsDisplay(for: self)
        #endif
    }

    // MARK: - Drawing

    #if canImport(AppKit)
    override public func draw(_ dirtyRect: NSRect) {
        // On macOS, GutterView should not be used - line numbers are handled by NSRulerView
        // Only draw if we're actually in the view hierarchy (which shouldn't happen on macOS)
        guard superview != nil else { return }

        super.draw(dirtyRect)
        // Always draw the full bounds to ensure line numbers are visible when scrolling
        drawLineNumbers(in: bounds)
    }

    /// Text views need a flipped coordinate system on macOS
    override nonisolated public var isFlipped: Bool { true }
    #else
    override public func draw(_ rect: CGRect) {
        super.draw(rect)

        // On iOS, force clearing the entire bounds before drawing

        // Always redraw the full bounds to ensure line numbers are visible
        // Use bounds instead of rect to force full redraw
        drawLineNumbers(in: bounds)
    }
    #endif

    // MARK: - Platform-Specific Setup

    #if canImport(UIKit)
    private func setupDisplayLink() {
        displayLinkHandle = GutterDisplayLinkHandle(gutterView: self)
    }

    func displayLinkFired() {
        guard let scrollView = textView?.crossPlatformEnclosingScrollView else { return }
        let currentOffset = scrollView.contentOffset

        if currentOffset != lastContentOffset {
            lastContentOffset = currentOffset
            setNeedsDisplay()
        }

        // Cancel any existing pause task
        pauseTask?.cancel()

        // Schedule a new pause task
        pauseTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                // Only pause if we haven't moved recently
                if self?.lastContentOffset == scrollView.contentOffset {
                    self?.displayLinkHandle?.setPaused(true)
                    self?.pauseTask = nil
                }
            } catch {
                // Task was cancelled, which is expected behavior
            }
        }
    }
    #endif

    // MARK: - Cleanup

    deinit {
        #if canImport(UIKit)
        pauseTask?.cancel()
        pauseTask = nil
        #endif

        // Observer cleanup is handled by NotificationCenter automatically on deallocation

        // Legacy cleanup for any selector-based observers
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Drawing Extension

extension GutterView {
    /// Common line number drawing implementation
    func drawLineNumbers(in rect: CGRect) {
        guard let textView else { return }

        // Get the graphics context
        guard let context = UnifiedDrawingCoordinator.currentContext() else { return }

        #if canImport(AppKit)
        let fillBackground = false // AppKit doesn't need background fill
        #else
        let fillBackground = true // UIKit needs background fill
        #endif

        let activeLineNumber = Self.computeActiveLineNumber(for: textView)

        // Use the renderer to draw line numbers
        renderer.draw(
            in: rect,
            context: context,
            textView: textView,
            gutterBounds: bounds,
            fillBackground: fillBackground,
            activeLineNumber: activeLineNumber
        )

        // Update accessibility elements for visible lines
        #if canImport(UIKit)
        updateAccessibilityElements()
        #endif
    }

    /// Resolves the 1-based line index containing the caret. Returns `nil`
    /// when no selection is set or the geometry store is empty. Used for
    /// active-line line-number coloring.
    private static func computeActiveLineNumber(for textView: CodeEditorView) -> Int? {
        #if canImport(AppKit)
        let location = textView.selectedRange().location
        guard location != NSNotFound,
              textView.lineGeometryStore.lineCount > 0 else { return nil }
        return textView.lineGeometryStore.lineIndex(forUtf16Offset: location) + 1
        #else
        guard let selectedTextRange = textView.selectedTextRange else { return nil }
        let location = textView.offset(from: textView.beginningOfDocument, to: selectedTextRange.start)
        guard textView.lineGeometryStore.lineCount > 0 else { return nil }
        return textView.lineGeometryStore.lineIndex(forUtf16Offset: location) + 1
        #endif
    }
}

// MARK: - Click/Tap Handling

extension GutterView {
    #if canImport(AppKit)
    /// Handle mouse clicks on macOS
    override public func mouseDown(with event: NSEvent) {
        // Delegate to interaction handler
        if let handled = interactionHandler?.handleMouseDown(with: event), handled {
            return
        }

        // Pass through to default handling
        super.mouseDown(with: event)
    }
    #endif

    /// Find the line number at the given point
    private func findLineNumber(at point: CGPoint, in textView: CodeEditorView) -> Int? {
        // Use TextKitLineNumberHelper to stay on the required TextKit2 surface.
        let helper = TextKitLineNumberHelper(textView: textView)
        return helper.lineNumber(at: point)
    }

    /// Check if the click was on a folding control
    private func isFoldingControlClick(at point: CGPoint, for lineNumber: Int, in textView: CodeEditorView) -> Bool {
        // Check if this line is foldable
        guard textView.isFoldable(at: lineNumber) else { return false }

        let controlSize = textView.configuration.layout.foldingControlSize
        let controlPadding = textView.configuration.layout.foldingControlPadding

        // Calculate the folding control rect for this line
        // Note: This calculation should match the one in GutterViewRenderer.drawFoldingControl
        let controlRect = CGRect(
            x: controlPadding,
            y: point.y - controlSize / 2, // Approximate - could be more precise
            width: controlSize,
            height: controlSize
        )

        return controlRect.contains(point)
    }
}

// MARK: - Observer Management

extension GutterView {
    /// Track text view changes
    func observeTextView() {
        guard let textView else { return }

        #if canImport(AppKit)
        // On macOS, GutterView is not used - line numbers are handled by NSRulerView
        // So we don't need to observe anything
        return
        #else

        // Clear any existing observers first
        removeTextViewObservers()

        // Observe text changes
        let notificationName = UITextView.textDidChangeNotification

        let textObserver = NotificationCenter.default.addObserver(
            forName: notificationName,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setNeedsDisplayLineNumbers()
            }
        }
        observers.append(textObserver)

        // For UIKit, scrolling is handled via the container's UIScrollViewDelegate
        // The container will forward scroll events to us, so we don't set delegate here
        // This avoids conflicts with other components that need the delegate
        #endif
    }

    #if canImport(AppKit)
    /// Observe scroll view changes (macOS only)
    func observeScrollView(_ scrollView: NSScrollView) {
        // Guard against early calls
        guard scrollView.contentView.bounds.width > 0 else { return }

        // Remove any existing scroll observers
        observers = observers.filter { _ in
            // Keep non-scroll observers
            true
        }

        // Observe scrolling via the content view's bounds changes
        let scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setNeedsDisplayLineNumbers()
            }
        }
        observers.append(scrollObserver)

        // Also observe the clipView's bounds changes as a backup
        let clipView = scrollView.contentView
        let clipObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setNeedsDisplayLineNumbers()
            }
        }
        observers.append(clipObserver)
    }
    #endif

    /// Remove all text view observers
    func removeTextViewObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}

// MARK: - UIScrollViewDelegate

#if canImport(UIKit)
extension GutterView: UITextViewDelegate {
    @objc public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Activate display link for smooth updates during scrolling
        displayLinkHandle?.setPaused(false)

        // Store the current offset
        lastContentOffset = scrollView.contentOffset

        // Force immediate redraw
        setNeedsDisplay()
        layer.setNeedsDisplay()

        // On iOS, we need to force the display update more aggressively
    }

    @objc public func scrollViewWillBeginDragging(_: UIScrollView) {
        // Start display link when scrolling begins
        displayLinkHandle?.setPaused(false)
    }

    public func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            // Pause display link when scrolling stops without deceleration
            displayLinkHandle?.setPaused(true)
            // Ensure final update
            setNeedsDisplay()
        }
    }

    public func scrollViewDidEndDecelerating(_: UIScrollView) {
        // Pause display link when scrolling completely stops
        displayLinkHandle?.setPaused(true)
        // Ensure final update
        setNeedsDisplay()
    }
}

// Make scroll handling methods accessible via @objc for dynamic dispatch
// These are already declared in the UITextViewDelegate extension above
// No need to redeclare them
#endif
