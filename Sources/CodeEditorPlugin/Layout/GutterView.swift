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
    
    public weak var textView: CodeEditorView?
    
    /// Array to store notification observer tokens for proper cleanup
    internal nonisolated(unsafe) var observers: [Any] = []
    
    /// The renderer responsible for drawing line numbers
    private let renderer = GutterViewRenderer()
    
    #if canImport(UIKit)
    private nonisolated(unsafe) var displayLink: CADisplayLink?
    private var lastContentOffset: CGPoint = .zero
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
    }
    
    // MARK: - Display Updates
    
    public func setNeedsDisplayLineNumbers() {
        UnifiedDrawingCoordinator.setNeedsDisplay(for: self)
    }
    
    // MARK: - Drawing
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawLineNumbers(in: dirtyRect)
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
        guard let scrollView = textView?.enclosingScrollView else { return }
        let currentOffset = scrollView.contentOffset
        
        if currentOffset != lastContentOffset {
            lastContentOffset = currentOffset
            setNeedsDisplay()
        }
    }
    #endif
    
    // MARK: - Cleanup
    
    deinit {
        #if canImport(UIKit)
        displayLink?.invalidate()
        displayLink = nil
        #endif
        
        // Remove all notification observers (safe since observers is nonisolated(unsafe))
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        
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
        if let scrollView = textView.enclosingScrollView {
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
        }
        #else
        // For UIKit, scrolling is handled via UIScrollViewDelegate
        if let scrollView = textView as? UIScrollView {
            scrollView.delegate = self
        }
        #endif
    }
    
    /// Remove all text view observers
    func removeTextViewObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}

// MARK: - UIScrollViewDelegate

#if canImport(UIKit)
extension GutterView: UIScrollViewDelegate {
    public func scrollViewDidScroll(_: UIScrollView) {
        displayLink?.isPaused = false
    }
}
#endif
