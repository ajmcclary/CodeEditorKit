import CodeEditorPlatform
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - CodeEditorView TextInputFeatureTarget Conformance

#if canImport(AppKit)
@MainActor extension CodeEditorView: TextInputFeatureTarget {
    public var nsTextView: NSTextView? { self }

    #if canImport(UIKit)
    public var uiTextView: UITextView? { nil }
    #endif
}
#elseif canImport(UIKit)
@MainActor extension CodeEditorView: TextInputFeatureTarget {
    #if canImport(AppKit)
    public var nsTextView: NSTextView? { nil }
    #endif

    public var uiTextView: UITextView? { self }
}
#endif
