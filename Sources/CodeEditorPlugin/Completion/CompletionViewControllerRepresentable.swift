import CodeEditorPlatform
#if canImport(AppKit)
@preconcurrency import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

public protocol CompletionViewControllerRepresentable: PlatformViewController {
    typealias Item = any CompletionItemView

    var items: [Item] { get set }
    var delegate: CompletionViewControllerDelegate? { get set }
}
