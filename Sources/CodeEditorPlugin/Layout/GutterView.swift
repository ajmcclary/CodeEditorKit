// MARK: - GutterView Cross-Platform Implementation
//
// This file provides a unified GutterView implementation that works across
// both iOS and macOS platforms, eliminating code duplication.

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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        needsDisplay = true
        #else
        setNeedsDisplay()
        #endif
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
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Drawing Extension

extension GutterView {
    /// Common line number drawing implementation
    func drawLineNumbers(in rect: CGRect) {
        guard let textView else { return }
        
        // Platform-specific drawing implementation
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        drawLineNumbersAppKit(in: rect, textView: textView)
        #else
        drawLineNumbersUIKit(in: rect, textView: textView)
        #endif
    }
}
