import CodeEditorCommon
import CoreGraphics
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Unified TextView Extensions

/// Protocol that provides a unified interface for text view operations across platforms
@MainActor
public protocol UnifiedTextViewProtocol {
    #if canImport(AppKit)
    /// The text storage associated with this text view
    var textStorage: NSTextStorage? { get }
    /// The layout manager responsible for text layout
    var layoutManager: NSLayoutManager? { get }
    /// The text container that defines the text layout area
    var textContainer: NSTextContainer? { get }
    /// The origin point of the text container
    var textContainerOrigin: NSPoint { get }
    /// The currently visible rectangle of the text view
    var visibleRect: NSRect { get }
    #else
    // For UIKit, these are non-optional, but we'll handle them differently
    /// The text storage associated with this text view
    var textStorage: NSTextStorage { get }
    /// The layout manager responsible for text layout
    var layoutManager: NSLayoutManager { get }
    /// The text container that defines the text layout area
    var textContainer: NSTextContainer { get }
    /// The content offset for scrolling
    var contentOffset: CGPoint { get }
    /// The bounds of the text view
    var bounds: CGRect { get }
    #endif
}

// MARK: - Platform Conformance

#if canImport(AppKit)
@MainActor
extension NSTextView: UnifiedTextViewProtocol {}
#else
@MainActor
extension UITextView: UnifiedTextViewProtocol {
    // UITextView already has all required properties
}
#endif

// MARK: - Unified Extensions

extension UnifiedTextViewProtocol {
    /// Returns the visible container rectangle in a platform-agnostic way
    var unifiedVisibleContainerRect: CGRect {
        #if canImport(AppKit)
        let origin = textContainerOrigin
        return visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
        #else
        return CGRect(origin: contentOffset, size: bounds.size)
        #endif
    }

    /// Returns the bounding rectangle for the given text range using TextKitBridge
    func unifiedBoundingRect(for range: NSRange) -> CGRect? {
        guard let textView = self as? PlatformTextView else { return nil }
        let textKitBridge = TextKitBridge(textView: textView)
        return textKitBridge.boundingRect(for: range)
    }
}

// MARK: - TextView Common Extensions

#if canImport(AppKit) || canImport(UIKit)
extension PlatformTextView {
    /// Returns the visible container rectangle
    var visibleContainerRect: CGRect {
        unifiedVisibleContainerRect
    }

    /// Returns the bounding rectangle for the given text range using layout manager
    public func boundingRect(for range: NSRange) -> CGRect? {
        unifiedBoundingRect(for: range)
    }
}

// MARK: - TextKit 2 Rendering Attributes

extension PlatformTextView {
    /// Apply attributes that do not affect layout, if supported by the text system
    public func setRenderingAttributes(_ attributes: [NSAttributedString.Key: Any], for range: NSRange) {
        let textKitBridge = TextKitBridge(textView: self)
        textKitBridge.setTemporaryAttributes(attributes, for: range)

        // Force refresh by temporarily changing selection if using TextKit2
        if textKitBridge.version == .textKit2 {
            let currentSelection = getCurrentSelection()
            setTemporarySelection(range)
            restoreSelection(currentSelection)
        }
    }

    /// Clear rendering attributes for the specified range
    public func clearRenderingAttributes(for range: NSRange) {
        setRenderingAttributes([:], for: range)
    }

    /// Apply syntax highlighting colors with proper TextKit 2 support
    public func applySyntaxHighlighting(_ attributes: [NSAttributedString.Key: Any], for range: NSRange) {
        // Use rendering attributes for non-layout affecting changes like color
        let renderingAttributes = attributes.filter { key, _ in
            // Only apply color and other non-layout affecting attributes as rendering attributes
            key == .foregroundColor || key == .backgroundColor
        }

        if !renderingAttributes.isEmpty {
            setRenderingAttributes(renderingAttributes, for: range)
        }

        // Apply layout-affecting attributes through the TK2-safe path.
        let layoutAttributes = attributes.filter { key, _ in
            key != .foregroundColor && key != .backgroundColor
        }

        if !layoutAttributes.isEmpty, let codeEditorView = self as? CodeEditorView {
            codeEditorView.textKitBridge.addPersistentAttributes(layoutAttributes, range: range)
        }
    }

    // MARK: - Private Helpers

    private func getCurrentSelection() -> Any {
        #if canImport(AppKit)
        return self.selectedRanges
        #else
        return self.selectedRange
        #endif
    }

    private func setTemporarySelection(_ range: NSRange) {
        #if canImport(AppKit)
        self.selectedRanges = [NSValue(range: range)]
        #else
        self.selectedRange = range
        #endif
    }

    private func restoreSelection(_ selection: Any) {
        #if canImport(AppKit)
        if let ranges = selection as? [NSValue] {
            self.selectedRanges = ranges
        }
        #else
        if let range = selection as? NSRange {
            self.selectedRange = range
        }
        #endif
    }
}
#endif
