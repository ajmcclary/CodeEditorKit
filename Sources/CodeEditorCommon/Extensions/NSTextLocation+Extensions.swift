// swiftlint:disable missing_docs
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension NSTextLocation {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.compare(rhs) == .orderedSame
    }

    public static func != (lhs: Self, rhs: Self) -> Bool {
        lhs.compare(rhs) != .orderedSame
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.compare(rhs) == .orderedAscending
    }

    public static func <= (lhs: Self, rhs: Self) -> Bool {
        lhs == rhs || lhs < rhs
    }

    public static func > (lhs: Self, rhs: Self) -> Bool {
        lhs.compare(rhs) == .orderedDescending
    }

    public static func >= (lhs: Self, rhs: Self) -> Bool {
        lhs == rhs || lhs > rhs
    }

    public static func ~= (lhs: Self, rhs: Self) -> Bool {
        lhs == rhs
    }
}

// swiftlint:enable missing_docs
