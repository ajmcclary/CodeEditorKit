#if canImport(AppKit)
@preconcurrency import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import Foundation

@MainActor
public protocol CompletionItem: Identifiable, Sendable {
    var view: PlatformView { get }
}
