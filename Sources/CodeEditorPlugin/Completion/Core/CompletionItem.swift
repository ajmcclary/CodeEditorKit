import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@preconcurrency import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public protocol CompletionItem: Identifiable, Sendable {
    var view: PlatformView { get }
}
