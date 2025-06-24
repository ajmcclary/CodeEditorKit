import Foundation

public enum RangeTarget: Hashable, Sendable {
    case set(IndexSet)
    case range(NSRange)
    case all

    public static let empty = Self.set(IndexSet())
    
    public var isEmpty: Bool {
        switch self {
        case .set(let indexSet):
            return indexSet.isEmpty

        case .range(let range):
            return range.length == 0

        case .all:
            return false
        }
    }

    public init(_ set: IndexSet) {
        self = .set(set)
    }

    public init(_ range: NSRange) {
        self = .range(range)
    }

    public init(_ ranges: [NSRange]) {
        self = .set(IndexSet(ranges: ranges))
    }

    public func indexSet(with length: Int) -> IndexSet {
        switch self {
        case let .set(indexSet):
            indexSet

        case let .range(range):
            IndexSet(integersIn: range)

        case .all:
            IndexSet(integersIn: 0 ..< length)
        }
    }
    
    // MARK: - Set Operations
    
    public func union(_ other: Self) -> Self {
        switch (self, other) {
        case (.set(var set), let .set(rhs)):
            set.formUnion(rhs)
            return Self(set)

        case (.all, _):
            return Self.all

        case (_, .all):
            return Self.all

        case (.set(var set), let .range(range)):
            set.insert(range: range)

            return Self(set)

        case let (.range(lhs), .set(rhs)):
            let set = rhs.union(IndexSet(integersIn: lhs))

            return Self(set)

        case let (.range(lhs), .range(rhs)):
            return Self([lhs, rhs])
        }
    }

    public func apply(mutations: [RangeMutation]) -> Self {
        switch self {
        case .all:
            return .all

        case var .range(range):
            for mutation in mutations {
                guard let newRange = range.apply(mutation) else {
                    return .empty
                }

                range = newRange
            }

            return .range(range)

        case var .set(set):
            set.applying(mutations)

            return .set(set)
        }
    }
}

// swiftlint:disable:next no_grouping_extension
extension RangeTarget: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .all:
            "all"

        case let .range(range):
            range.debugDescription

        case let .set(set):
            set.nsRangeView.debugDescription
        }
    }
}
