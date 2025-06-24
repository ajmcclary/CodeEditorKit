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

// MARK: - STLineAnnotation

public protocol STLineAnnotation {
    typealias Identifier = String
    
    var id: Identifier { get }
    var location: any NSTextLocation { get set }
}
