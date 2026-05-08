//
//  EdgeInsets+Extensions.swift
//  CodeEditorPlugin
//
//  Created on 2025-06-27.
//

import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - EdgeInsets Platform Conversions

extension EdgeInsets {
    #if canImport(AppKit)
    /// Create EdgeInsets from NSSize (used for text container insets on macOS)
    public init(size: NSSize) {
        self.init(top: size.height, left: size.width, bottom: size.height, right: size.width)
    }

    /// Convert to NSSize for text container insets
    public var nsSize: NSSize {
        // macOS uses symmetric insets, so we use left/top
        NSSize(width: left, height: top)
    }

    /// Create EdgeInsets from NSEdgeInsets
    public init(nsEdgeInsets: NSEdgeInsets) {
        self.init(top: nsEdgeInsets.top, left: nsEdgeInsets.left, bottom: nsEdgeInsets.bottom, right: nsEdgeInsets.right)
    }

    /// Convert to NSEdgeInsets
    public var nsEdgeInsets: NSEdgeInsets {
        NSEdgeInsets(top: top, left: left, bottom: bottom, right: right)
    }
    #endif

    #if canImport(UIKit)
    /// Create EdgeInsets from UIEdgeInsets
    public init(uiEdgeInsets: UIEdgeInsets) {
        self.init(top: uiEdgeInsets.top, left: uiEdgeInsets.left, bottom: uiEdgeInsets.bottom, right: uiEdgeInsets.right)
    }

    /// Convert to UIEdgeInsets
    public var uiEdgeInsets: UIEdgeInsets {
        UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
    }
    #endif

    /// Create EdgeInsets with uniform value
    public init(uniform: CGFloat) {
        self.init(top: uniform, left: uniform, bottom: uniform, right: uniform)
    }

    /// Create EdgeInsets with horizontal and vertical values
    public init(horizontal: CGFloat, vertical: CGFloat) {
        self.init(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    /// Total horizontal insets
    public var totalHorizontal: CGFloat {
        left + right
    }

    /// Total vertical insets
    public var totalVertical: CGFloat {
        top + bottom
    }

    /// Apply insets to a rect
    public func apply(to rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x + left,
            y: rect.origin.y + top,
            width: rect.width - totalHorizontal,
            height: rect.height - totalVertical
        )
    }

    /// Invert the insets (expand instead of inset)
    public func inverted() -> EdgeInsets {
        EdgeInsets(top: -top, left: -left, bottom: -bottom, right: -right)
    }

    /// Add two edge insets
    public static func + (lhs: EdgeInsets, rhs: EdgeInsets) -> EdgeInsets {
        EdgeInsets(
            top: lhs.top + rhs.top,
            left: lhs.left + rhs.left,
            bottom: lhs.bottom + rhs.bottom,
            right: lhs.right + rhs.right
        )
    }
}

// MARK: - Platform-Specific Extensions

#if canImport(AppKit)
extension NSTextView {
    /// Get text container inset as EdgeInsets
    public var textContainerEdgeInsets: EdgeInsets {
        EdgeInsets(size: textContainerInset)
    }

    /// Set text container inset from EdgeInsets
    public func setTextContainerEdgeInsets(_ insets: EdgeInsets) {
        textContainerInset = insets.nsSize
    }
}
#endif

#if canImport(UIKit)
extension UITextView {
    /// Get text container inset as EdgeInsets
    public var textContainerEdgeInsets: EdgeInsets {
        EdgeInsets(uiEdgeInsets: textContainerInset)
    }

    /// Set text container inset from EdgeInsets
    public func setTextContainerEdgeInsets(_ insets: EdgeInsets) {
        textContainerInset = insets.uiEdgeInsets
    }
}
#endif

// MARK: - CodeEditorView Extensions

extension CodeEditorView {
    /// Get unified text container insets
    public var unifiedTextContainerInsets: EdgeInsets {
        #if canImport(AppKit)
        return EdgeInsets(size: textContainerInset)
        #else
        return EdgeInsets(uiEdgeInsets: textContainerInset)
        #endif
    }

    /// Set unified text container insets
    public func setUnifiedTextContainerInsets(_ insets: EdgeInsets) {
        #if canImport(AppKit)
        textContainerInset = insets.nsSize
        #else
        textContainerInset = insets.uiEdgeInsets
        #endif
    }
}
