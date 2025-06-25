@preconcurrency import AppKit
import Foundation

public protocol CompletionItem: Identifiable {
    var view: NSView { get }
}
