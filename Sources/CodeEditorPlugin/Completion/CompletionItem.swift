#if canImport(AppKit)
@preconcurrency import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import Foundation

public protocol CompletionItem: Identifiable {
    var view: PlatformView { get }
}
