import CodeEditorLanguages
import CodeEditorPlatform
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Completion Item Adapter

/// Cross-target adapter for bridging CompletionItemModel to CompletionItem protocol.
@MainActor
package struct CompletionItemAdapter: CompletionItemView {
    package let id: String
    package let model: CompletionItemModel

    package init(_ model: CompletionItemModel) {
        self.id = model.id
        self.model = model
    }

    package var view: PlatformView {
        #if canImport(AppKit)
        let view = NSView()
        view.wantsLayer = true
        return view
        #else
        return UIView()
        #endif
    }
}
