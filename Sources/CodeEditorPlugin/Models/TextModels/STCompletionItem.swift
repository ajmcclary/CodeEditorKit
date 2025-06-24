@preconcurrency import AppKit
import Foundation

public protocol STCompletionItem: Identifiable {
    var view: NSView { get }
}
