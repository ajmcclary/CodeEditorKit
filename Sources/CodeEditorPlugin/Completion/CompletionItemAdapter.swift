import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Completion Item Adapter

/// Internal adapter for bridging CompletionItemModel to CompletionItem protocol
@MainActor
internal struct CompletionItemAdapter: CompletionItemView {
    let id: String
    let model: CompletionItemModel

    init(_ model: CompletionItemModel) {
        self.id = model.id
        self.model = model
    }

    var view: PlatformView {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let view = NSView()
        view.wantsLayer = true
        return view
        #else
        return UIView()
        #endif
    }
}
