import Foundation

// MARK: - RangeInvalidationBuffer

/// A buffer that manages range invalidation events with support for nested buffering operations.
/// This class allows efficient batching of invalidation operations to avoid excessive handler calls.
public final class RangeInvalidationBuffer {
    /// Handler type that processes range invalidation targets.
    public typealias Handler = (RangeTarget) -> Void

    private enum State: Hashable {
        case idle
        case buffering(RangeTarget, Int)
    }

    private var state = State.idle
    /// The handler called when invalidation events are processed.
    public var invalidationHandler: Handler = { _ in }

    private var isEmpty: Bool {
        if case let .buffering(target, _) = state {
            return target.isEmpty
        }
        return true
    }

    /// Creates a new range invalidation buffer.
    public init() {}

    // MARK: - Public Methods

    /// Begins a buffering operation to collect invalidation events.
    /// Multiple calls to this method can be nested, with each requiring a matching `endBuffering()` call.
    public func beginBuffering() {
        switch state {
        case .idle:
            state = .buffering(.set(IndexSet()), 1)

        case let .buffering(set, count):
            state = .buffering(set, count + 1)
        }
    }

    /// Ends a buffering operation and processes collected invalidation events if this is the final nesting level.
    /// This method must be called once for each corresponding `beginBuffering()` call.
    /// Unbalanced calls (`endBuffering` without a matching `beginBuffering`) are
    /// logged and ignored rather than crashing.
    public func endBuffering() {
        switch state {
        case .idle:
            CrossPlatformLogger.logger().error(
                "RangeInvalidationBuffer.endBuffering called while idle; ignoring unbalanced call"
            )

        case let .buffering(set, 1):
            invalidationHandler(set)
            state = .idle

        case let .buffering(set, count) where count > 1:
            state = .buffering(set, count - 1)

        case let .buffering(set, count):
            CrossPlatformLogger.logger().fault(
                "RangeInvalidationBuffer in invalid buffering state count=\(count); resetting to idle"
            )
            invalidationHandler(set)
            state = .idle
        }
    }

    /// Invalidates the specified range target.
    /// If buffering is active, the invalidation is collected; otherwise it's processed immediately.
    /// - Parameter target: The range target to invalidate.
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
