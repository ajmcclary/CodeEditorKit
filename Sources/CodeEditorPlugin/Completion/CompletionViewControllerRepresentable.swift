#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@preconcurrency import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

public protocol CompletionViewControllerRepresentable: PlatformViewController {
    typealias Item = any CompletionItem

    var items: [Item] { get set }
    var delegate: CompletionViewControllerDelegate? { get set }
}
