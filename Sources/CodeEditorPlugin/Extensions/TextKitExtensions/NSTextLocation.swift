#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit
#elseif os(iOS) || os(visionOS)
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#endif

extension NSTextLocation {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.compare(rhs) == .orderedSame
    }

    static func != (lhs: Self, rhs: Self) -> Bool {
        lhs.compare(rhs) != .orderedSame
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.compare(rhs) == .orderedAscending
    }

    static func <= (lhs: Self, rhs: Self) -> Bool {
        lhs == rhs || lhs < rhs
    }

    static func > (lhs: Self, rhs: Self) -> Bool {
        lhs.compare(rhs) == .orderedDescending
    }

    static func >= (lhs: Self, rhs: Self) -> Bool {
        lhs == rhs || lhs > rhs
    }

    static func ~= (lhs: Self, rhs: Self) -> Bool {
        lhs == rhs
    }
}
