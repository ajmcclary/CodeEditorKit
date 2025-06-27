// MARK: - GutterView Cross-Platform Implementation
//
// This file serves as the main entry point for the GutterView component.
// Platform-specific implementations are located in:
// - GutterView+AppKit.swift (macOS implementation)
// - GutterView+UIKit.swift (iOS implementation)

import Foundation

// Platform-specific imports to make GutterView class available
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Shared GutterView Protocol

/// Protocol defining the common interface for both AppKit and UIKit implementations
@MainActor
public protocol GutterViewProtocol: AnyObject {
    var textView: CodeEditorView? { get set }
    func setNeedsDisplayLineNumbers()
}

// MARK: - Platform-Specific GutterView Implementations

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
/// macOS implementation for displaying line numbers
public class GutterView: NSView, GutterViewProtocol {
    public weak var textView: CodeEditorView?

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = PlatformColors.controlBackground.cgColor
    }
    
    public func setNeedsDisplayLineNumbers() {
        needsDisplay = true
    }
    
    override public func draw(_ dirtyRect: NSRect) {
        // Implementation details moved to AppKit extension
        super.draw(dirtyRect)
        drawLineNumbers(in: dirtyRect)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

#elseif canImport(UIKit)
/// iOS implementation for displaying line numbers  
public class GutterView: UIView, GutterViewProtocol {
    public weak var textView: CodeEditorView?
    private nonisolated(unsafe) var displayLink: CADisplayLink?
    private var lastContentOffset: CGPoint = .zero
    
    override public init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = PlatformColors.controlBackground
        setupDisplayLink()
    }
    
    public func setNeedsDisplayLineNumbers() {
        setNeedsDisplay()
    }
    
    override public func draw(_ rect: CGRect) {
        // Implementation details in UIKit extension
        super.draw(rect)
        drawLineNumbers(in: rect)
    }
    
    deinit {
        displayLink?.invalidate()
        displayLink = nil
        NotificationCenter.default.removeObserver(self)
    }
}
#endif
