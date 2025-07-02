#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - LineAnnotation

public protocol LineAnnotation {
    typealias Identifier = String

    var id: Identifier { get }
    var location: any NSTextLocation { get set }
}
