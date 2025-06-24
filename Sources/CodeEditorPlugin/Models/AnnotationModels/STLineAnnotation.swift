#if os(macOS)
import AppKit
#endif
#if os(iOS) || targetEnvironment(macCatalyst)
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#endif

public protocol STLineAnnotation {
    typealias ID = String
    var id: ID { get }
    var location: any NSTextLocation { get set }
}
