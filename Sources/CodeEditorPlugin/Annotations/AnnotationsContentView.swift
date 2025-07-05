// MARK: - AnnotationsContentView Cross-Platform Implementation
//
// This file provides a unified AnnotationsContentView implementation that works across
// both iOS and macOS platforms, eliminating code duplication.

import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - AnnotationsContentView Protocol

/// Protocol defining the common interface for annotations content view functionality
@MainActor
public protocol AnnotationsContentViewProtocol: AnyObject {
    var annotations: [Annotation] { get set }
    
    func setNeedsDisplayAnnotations()
}

// MARK: - Unified AnnotationsContentView Implementation

/// Cross-platform view for displaying annotation content
@MainActor
public class AnnotationsContentView: PlatformView, AnnotationsContentViewProtocol {
    // MARK: - Properties
    
    public var annotations: [Annotation] = [] {
        didSet {
            setNeedsDisplayAnnotations()
        }
    }
    
    private var annotationViews: [AnnotationView] = []
    
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
        layer?.backgroundColor = PlatformColors.clear.cgColor
        #else
        backgroundColor = PlatformColors.clear
        #endif
    }
    
    // MARK: - Display Updates
    
    public func setNeedsDisplayAnnotations() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        needsDisplay = true
        #else
        setNeedsDisplay()
        #endif
        
        // Update annotation views
        updateAnnotationViews()
    }
    
    // MARK: - Annotation View Management
    
    private func updateAnnotationViews() {
        // Remove existing annotation views
        annotationViews.forEach { $0.removeFromSuperview() }
        annotationViews.removeAll()
        
        // Create new annotation views
        for annotation in annotations {
            if let lineAnnotation = annotation as? LineAnnotation {
                // Create annotation view with appropriate size
                let size: CGFloat = 20
                let annotationView = AnnotationView(
                    annotation: lineAnnotation,
                    frame: CGRect(x: 0, y: 0, width: size, height: size)
                )
                
                addSubview(annotationView)
                annotationViews.append(annotationView)
            }
        }
        
        // Layout annotation views
        layoutAnnotationViews()
    }
    
    private func layoutAnnotationViews() {
        // Simple layout: stack annotations vertically
        var yOffset: CGFloat = 10
        let xOffset: CGFloat = 10
        let spacing: CGFloat = 5
        
        for annotationView in annotationViews {
            annotationView.frame.origin = CGPoint(x: xOffset, y: yOffset)
            yOffset += annotationView.frame.height + spacing
        }
    }
    
    // MARK: - Platform-Specific Overrides
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Text views need a flipped coordinate system on macOS
    nonisolated override public var isFlipped: Bool { true }
    #endif
    
    // MARK: - Layout
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func layout() {
        // Ensure we're on the main thread for layout operations
        if Thread.isMainThread {
            super.layout()
            layoutAnnotationViews()
        } else {
            // Use Swift concurrency to dispatch to main actor
            Task { @MainActor [weak self] in
                self?.layout()
            }
        }
    }
    #else
    override public func layoutSubviews() {
        super.layoutSubviews()
        layoutAnnotationViews()
    }
    #endif
    
    deinit {
        // Cleanup is handled by ARC
    }
}
