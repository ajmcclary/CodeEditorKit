import CodeEditorCommon
import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - CodeEditorView Unified Edge Insets

extension CodeEditorView {
    /// Get unified text container insets.
    public var unifiedTextContainerInsets: FrameworkEdgeInsets {
        #if canImport(AppKit)
        return FrameworkEdgeInsets(size: textContainerInset)
        #else
        return FrameworkEdgeInsets(uiFrameworkEdgeInsets: textContainerInset)
        #endif
    }

    /// Set unified text container insets.
    public func setUnifiedTextContainerInsets(_ insets: FrameworkEdgeInsets) {
        #if canImport(AppKit)
        textContainerInset = insets.nsSize
        #else
        textContainerInset = insets.uiFrameworkEdgeInsets
        #endif
    }
}
