import Foundation

// MARK: - RangeInvalidationBuffer

public final class RangeInvalidationBuffer {
    public typealias Handler = (RangeTarget) -> Void

    private enum State: Hashable {
        case idle
        case buffering(RangeTarget, Int)
    }

    private var state = State.idle
    public var invalidationHandler: Handler = { _ in }

    private var isEmpty: Bool {
        if case let .buffering(target, _) = state {
            return target.isEmpty
        }
        return true
    }

    public init() {}

    // MARK: - Public Methods

    public func beginBuffering() {
        switch state {
        case .idle:
            state = .buffering(.set(IndexSet()), 1)

        case let .buffering(set, count):
            state = .buffering(set, count + 1)
        }
    }

    public func endBuffering() {
        switch state {
        case .idle:
            preconditionFailure()

        case let .buffering(set, 1):
            invalidationHandler(set)
            state = .idle

        case let .buffering(set, count):
            precondition(count > 1)
            state = .buffering(set, count - 1)
        }
    }

    public func invalidate(_ target: RangeTarget) {
        switch state {
        case .idle:
            invalidationHandler(target)

        case let .buffering(existing, count):
            precondition(!isEmpty)

            state = .buffering(existing.union(target), count)
        }
    }

    deinit {
        // Cleanup if needed
    }
}
