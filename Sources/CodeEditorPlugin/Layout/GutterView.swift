// MARK: - GutterView Cross-Platform Implementation
//
// This file provides a unified GutterView implementation that works across
// both iOS and macOS platforms, eliminating code duplication.

import CoreGraphics
import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
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
    private let renderer = GutterViewRenderer()
    
    /// The interaction handler for clicks/taps
    private var interactionHandler: GutterInteractionHandler?
    
    #if canImport(UIKit)
    private nonisolated(unsafe) var displayLink: CADisplayLink?
    private var lastContentOffset: CGPoint = .zero
    private var pauseTask: Task<Void, Never>?
    #endif
    
    // MARK: - Initialization
    
    override public init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    // MARK: - Setup
    
    private func setup() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        wantsLayer = true
        // Make gutter transparent so it doesn't block text
        layer?.backgroundColor = PlatformColors.clear.cgColor
        #else
        backgroundColor = PlatformColors.controlBackground
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Force a complete redraw on macOS to ensure line numbers are visible
        self.needsDisplay = true
        #else
        UnifiedDrawingCoordinator.setNeedsDisplay(for: self)
        #endif
    }
    
    // MARK: - Drawing
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Always draw the full bounds to ensure line numbers are visible when scrolling
        drawLineNumbers(in: bounds)
    }
    
    /// Text views need a flipped coordinate system on macOS
    nonisolated override public var isFlipped: Bool { true }
    #else
    override public func draw(_ rect: CGRect) {
        super.draw(rect)
        drawLineNumbers(in: rect)
    }
    #endif
    
    // MARK: - Platform-Specific Setup
    
    #if canImport(UIKit)
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.add(to: .main, forMode: .common)
        displayLink?.isPaused = true
    }
    
    @objc private func displayLinkFired() {
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
                    self?.displayLink?.isPaused = true
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
        displayLink?.invalidate()
        displayLink = nil
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
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let fillBackground = false // AppKit doesn't need background fill
        #else
        let fillBackground = true // UIKit needs background fill
        #endif
        
        // Use the renderer to draw line numbers
        renderer.draw(
            in: rect,
            context: context,
            textView: textView,
            gutterBounds: bounds,
            fillBackground: fillBackground
        )
    }
}

// MARK: - Click/Tap Handling

extension GutterView {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
    
    // Click handling logic has been moved to GutterInteractionHandler
    // The following method is kept for backward compatibility but will be removed
    @available(*, deprecated, message: "Use GutterInteractionHandler instead")
    private func handleClickAt(point: CGPoint, in textView: CodeEditorView) -> Bool {
        // Only handle clicks if folding is enabled
        guard textView.configuration.display.enableCodeFolding &&
              textView.configuration.display.showFoldingControls else {
            return false
        }
        
        // Find which line was clicked
        guard let clickedLineNumber = findLineNumber(at: point, in: textView) else {
            return false
        }
        
        // Check if click was on a folding control
        if isFoldingControlClick(at: point, for: clickedLineNumber, in: textView) {
            // Toggle folding for this line
            let wasToggled = textView.toggleFold(at: clickedLineNumber)
            
            if wasToggled {
                // Trigger display update
                setNeedsDisplayLineNumbers()
                
                // Provide haptic feedback on iOS
                #if canImport(UIKit)
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                #endif
            }
            
            return wasToggled
        }
        
        return false
    }
    
    /// Find the line number at the given point
    private func findLineNumber(at point: CGPoint, in textView: CodeEditorView) -> Int? {
        // Use TextKitLineNumberHelper to avoid forcing TextKit 1
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
        
        // Clear any existing observers first
        removeTextViewObservers()
        
        // Observe text changes
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let notificationName = NSText.didChangeNotification
        #else
        let notificationName = UITextView.textDidChangeNotification
        #endif
        
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
        
        // Observe scrolling
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // The scroll view will be set up separately via observeScrollView()
        // since it might not be available when this method is called
        #else
        // For UIKit, scrolling is handled via the container's UIScrollViewDelegate
        // The container will forward scroll events to us, so we don't set delegate here
        // This avoids conflicts with other components that need the delegate
        #endif
    }
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
    @objc public func scrollViewDidScroll(_: UIScrollView) {
        // Activate display link for smooth updates during scrolling
        displayLink?.isPaused = false
        
        // Also trigger an immediate update
        setNeedsDisplay()
    }
    
    @objc public func scrollViewWillBeginDragging(_: UIScrollView) {
        // Start display link when scrolling begins
        displayLink?.isPaused = false
    }
    
    public func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            // Pause display link when scrolling stops without deceleration
            displayLink?.isPaused = true
            // Ensure final update
            setNeedsDisplay()
        }
    }
    
    public func scrollViewDidEndDecelerating(_: UIScrollView) {
        // Pause display link when scrolling completely stops
        displayLink?.isPaused = true
        // Ensure final update
        setNeedsDisplay()
    }
}

// Make scroll handling methods accessible via @objc for dynamic dispatch
// These are already declared in the UITextViewDelegate extension above
// No need to redeclare them
#endif
