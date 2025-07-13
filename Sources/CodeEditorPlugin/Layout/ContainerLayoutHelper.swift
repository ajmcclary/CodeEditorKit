import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Helper for container layout calculations
/// Provides shared layout logic for CodeEditorContainerView
@MainActor
internal enum ContainerLayoutHelper {
    // MARK: - Layout Calculations
    
    /// Calculate the width for the minimap
    static func minimapWidth(for configuration: EditorConfiguration) -> CGFloat {
        configuration.display.showMinimap ? configuration.layout.minimapWidth : 0
    }
    
    /// Calculate the frame for the scroll view
    static func scrollViewFrame(
        containerBounds: CGRect,
        configuration: EditorConfiguration
    ) -> CGRect {
        let minimapWidth = self.minimapWidth(for: configuration)
        
        return CGRect(
            x: 0,
            y: 0,
            width: containerBounds.width - minimapWidth,
            height: containerBounds.height
        )
    }
    
    /// Calculate the frame for the minimap
    static func minimapFrame(
        containerBounds: CGRect,
        configuration: EditorConfiguration
    ) -> CGRect? {
        guard configuration.display.showMinimap else { return nil }
        
        let minimapWidth = self.minimapWidth(for: configuration)
        let minimapX = containerBounds.width - minimapWidth
        
        return CGRect(
            x: minimapX,
            y: 0,
            width: minimapWidth,
            height: containerBounds.height
        )
    }
    
    /// Calculate the frame for the gutter view (AppKit only)
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    static func gutterFrame(
        scrollViewBounds: CGRect,
        configuration: EditorConfiguration
    ) -> CGRect? {
        guard configuration.display.isLineNumbersEnabled else { return nil }
        
        let gutterWidth = configuration.layout.gutterWidth
        
        return CGRect(
            x: 0,
            y: 0,
            width: gutterWidth,
            height: scrollViewBounds.height
        )
    }
    #endif
    
    /// Calculate text container insets
    static func textContainerInsets(
        configuration: EditorConfiguration,
        gutterVisible: Bool
    ) -> EdgeInsets {
        var insets = configuration.layout.textContainerInset
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // On AppKit, gutter is inside scroll view so we add to insets
        if gutterVisible {
            insets = EdgeInsets(
                top: insets.top,
                left: insets.left + configuration.layout.gutterWidth,
                bottom: insets.bottom,
                right: insets.right
            )
        }
        #endif
        
        return insets
    }
    
    /// Calculate text view width constraints
    static func textViewWidth(
        containerWidth: CGFloat,
        configuration: EditorConfiguration,
        gutterVisible: Bool
    ) -> CGFloat? {
        guard configuration.layout.wrapLines else { return nil }
        
        var width = containerWidth
        
        // Subtract minimap width if visible
        if configuration.display.showMinimap {
            width -= configuration.layout.minimapWidth
        }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // On AppKit, gutter is inside scroll view
        if gutterVisible {
            width -= configuration.layout.gutterWidth
        }
        #endif
        
        return width
    }
    
    // MARK: - Z-Position Management
    
    /// Standard z-positions for layers
    enum ZPosition {
        static let scrollView: CGFloat = 0
        static let gutter: CGFloat = 10
        static let minimap: CGFloat = 100
        static let minimapHighlight: CGFloat = 101
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Higher z-positions for AppKit to ensure visibility
        static let minimapAppKit: CGFloat = 1_000
        #endif
    }
    
    /// Apply standard z-position to a view's layer
    static func applyZPosition(_ position: CGFloat, to view: PlatformView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        view.layer?.zPosition = position
        #else
        view.layer.zPosition = position
        #endif
    }
    
    // MARK: - Visibility Management
    
    /// Update view visibility and display
    static func updateViewVisibility(
        _ view: PlatformView,
        isVisible: Bool,
        forceDisplay: Bool = false
    ) {
        view.isHidden = !isVisible
        
        if isVisible && forceDisplay {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            view.needsDisplay = true
            #else
            view.setNeedsDisplay()
            #endif
        }
    }
    
    // MARK: - Constraint Helpers
    
    #if canImport(UIKit)
    /// Create standard constraints for container layout
    static func createLayoutConstraints(
        for container: CodeEditorContainerView,
        scrollView: UIScrollView,
        gutterView: GutterView,
        minimapView: MinimapView,
        textView: CodeEditorView,
        configuration: EditorConfiguration
    ) -> [NSLayoutConstraint] {
        var constraints: [NSLayoutConstraint] = []
        
        // Scroll view constraints
        constraints.append(contentsOf: [
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // Gutter constraints
        constraints.append(contentsOf: [
            gutterView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gutterView.topAnchor.constraint(equalTo: container.topAnchor),
            gutterView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            gutterView.widthAnchor.constraint(equalToConstant: configuration.layout.gutterWidth)
        ])
        
        // Minimap constraints
        let minimapWidthConstraint = minimapView.widthAnchor.constraint(
            equalToConstant: configuration.layout.minimapWidth
        )
        
        constraints.append(contentsOf: [
            minimapView.topAnchor.constraint(equalTo: container.topAnchor),
            minimapView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            minimapView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            minimapWidthConstraint
        ])
        
        // Scroll view trailing constraint depends on minimap visibility
        let scrollViewTrailingConstraint = configuration.display.showMinimap ?
            scrollView.trailingAnchor.constraint(equalTo: minimapView.leadingAnchor) :
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        
        constraints.append(scrollViewTrailingConstraint)
        
        // Text view constraints
        constraints.append(contentsOf: [
            textView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            textView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            textView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ])
        
        return constraints
    }
    #endif
}
