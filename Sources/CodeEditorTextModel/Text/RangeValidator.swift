import CodeEditorCommon
import Foundation

public enum Validation: Sendable, Hashable {
    case stale
    case success(NSRange)
}

// MARK: - RangeValidator

/// A type that manages the validation of range-based content with version tracking.
public actor RangeValidator<Content: VersionedContent> {
    /// Type alias for content ranges that include version information for change tracking.
    public typealias ContentRange = VersionedRange<Content.Version>
    /// Type alias for validation providers that support both sync and async operations.
    public typealias ValidationProvider = HybridSyncAsyncValueProvider<ContentRange, Validation, Never>

    public enum Action: Sendable, Equatable {
        case noValidation
        case needed(ContentRange)
    }

    private var validSet = IndexSet()
    // Future optimization: Convert to array with computed set for better overlap detection
    // Current implementation uses IndexSet which may process overlapping ranges
    private var pendingSet = IndexSet()
    private var pendingRequests = 0

    /// The versioned content being validated by this validator.
    public let content: Content

    /// Creates a new range validator for the specified versioned content.
    /// - Parameter content: The versioned content to validate
    public init(content: Content) {
        self.content = content
    }

    /// Whether this validator has any pending validation operations in progress.
    public var hasOutstandingValidations: Bool {
        pendingRequests > 0
    }

    private var version: Content.Version {
        content.currentVersion
    }

    /// Manually mark a region as invalid.
    public func invalidate(_ target: RangeTarget) {
        let invalidated = target.indexSet(with: length)

        if invalidated.isEmpty {
            return
        }

        validSet.subtract(invalidated)
        pendingSet.subtract(invalidated)
    }

    /// Begin a validation pass.
    ///
    /// This must ultimately be paired with a matching call to `completeValidation(of:with:)`.
    public func beginValidation(of target: RangeTarget) -> Action {
        let set = target.indexSet(with: length)

        guard let neededRange = nextNeededRange(in: set) else {
            return .noValidation
        }

        pendingSet.insert(range: neededRange)
        pendingRequests += 1

        let contentRange = ContentRange(neededRange, version: version)

        return .needed(contentRange)
    }

    /// Complete a validation pass.
    ///
    /// This should only be used to end a matching call to `beginValidation(of:prioritizing:)`.
    public func completeValidation(of contentRange: ContentRange, with validation: Validation) {
        pendingRequests -= 1
        precondition(pendingRequests >= 0)

        guard contentRange.version == version else {
            pendingSet.removeAll()
            return
        }

        switch validation {
        case .stale:
            pendingSet.remove(integersIn: contentRange.value.location ..< contentRange.value.upperBound)

        case let .success(range):
            pendingSet.remove(integersIn: range.location ..< range.upperBound)
            validSet.insert(range: range)
        }
    }

    /// Checks whether the specified range target has been validated and is current.
    /// - Parameter target: The range target to check for validity
    /// - Returns: True if the target is fully validated, false otherwise
    public func isValid(_ target: RangeTarget) -> Bool {
        switch target {
        case .all:
            fullSet == validSet

        case let .range(range):
            validSet.contains(integersIn: range.location ..< range.upperBound)

        case let .set(set):
            validSet.intersection(set) == set
        }
    }

    /// Update internal state in response to a mutation.
    ///
    /// This method must be invoked on every content change. The `range` parameter must refer to the range that **was** changed. Consider the example text `"abc"`.
    ///
    /// Inserting a "d" at the end:
    ///
    ///     range = NSRange(3..<3)
    ///     delta = 1
    ///
    /// Deleting the middle "b":
    ///
    ///     range = NSRange(1..<2)
    ///     delta = -1
    public func contentChanged(in range: NSRange, delta: Int) {
        let mutation = RangeMutation(range: range, delta: delta)

        validSet = mutation.transform(set: validSet)

        if pendingSet.isEmpty {
            return
        }

        // if we have pending requests, we have to start over
        pendingSet.removeAll()
    }

    deinit {
        // Cleanup if needed
    }

    // MARK: - Private Properties

    private var length: Int {
        content.currentLength
    }

    private var fullSet: IndexSet {
        IndexSet(integersIn: 0 ..< length)
    }

    private var invalidSet: IndexSet {
        fullSet.subtracting(validSet)
    }

    // MARK: - Private Methods

    /// Computes the next contiguous invalid range
    private func nextNeededRange(in set: IndexSet) -> NSRange? {
        // the candidate set is:
        // - invalid
        // - not already pending
        invalidSet
            .intersection(set)
            .subtracting(pendingSet)
            .nsRangeView
            .first
    }
}

extension RangeValidator.Action: Hashable where Content.Version: Hashable {}
