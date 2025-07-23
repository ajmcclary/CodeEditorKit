import Foundation

/// An actor that manages single-phase range validation operations for versioned content.
/// This validator handles both synchronous and asynchronous validation workflows.
public actor SinglePhaseRangeValidator<Content: VersionedContent> {
    /// Type alias for content ranges with version information.
    public typealias ContentRange = RangeValidator<Content>.ContentRange
    /// Type alias for the validation provider used by this validator.
    public typealias Provider = HybridSyncAsyncValueProvider<ContentRange, Validation, Never>

    private struct ValidationOperation: Sendable {
        let contentRange: ContentRange
        let target: RangeTarget
    }

    public struct Configuration: Sendable {
        public let versionedContent: Content
        public let provider: Provider

        public init(
            versionedContent: Content,
            provider: Provider
        ) {
            self.versionedContent = versionedContent
            self.provider = provider
        }
    }

    private let primaryValidator: RangeValidator<Content>
    private var eventQueue: AwaitableQueue<ValidationOperation>

    /// The configuration used by this validator, accessible from any isolation context.
    public nonisolated let configuration: Configuration
    /// Handler called when validation operations complete with range and completion status.
    public var validationHandler: @Sendable (NSRange, Bool) -> Void = { _, _ in }
    /// Optional name for this validator instance for debugging purposes.
    public var name: String?

    /// Sets the name of this validator instance.
    /// - Parameter newValue: The name to assign to this validator
    public func setName(_ newValue: String?) {
        self.name = newValue
    }

    /// Sets the validation completion handler.
    /// - Parameter handler: Handler called when validation operations complete
    public func setValidationHandler(_ handler: @escaping @Sendable (NSRange, Bool) -> Void) {
        self.validationHandler = handler
    }

    private func handlePendingWaiters() {
        eventQueue.handlePendingWaiters()
    }

    /// Creates a new single-phase range validator with the specified configuration.
    /// - Parameter configuration: The configuration for this validator
    public init(configuration: Configuration) {
        self.configuration = configuration
        primaryValidator = RangeValidator<Content>(content: configuration.versionedContent)
        eventQueue = AwaitableQueue()
    }

    private var version: Content.Version {
        get async {
            configuration.versionedContent.currentVersion
        }
    }

    /// Manually mark a region as invalid.
    public func invalidate(_ target: RangeTarget) async {
        await primaryValidator.invalidate(target)
    }

    // Actor-isolated version without isolation parameter
    /// Validates the specified target range within the actor's isolation context.
    /// - Parameter target: The range target to validate
    /// - Returns: The validation action that was performed
    @discardableResult
    public func validateOnActor(_ target: RangeTarget) async -> RangeValidator<Content>.Action {
        // capture this first, because we're about to start one
        let outstanding = await primaryValidator.hasOutstandingValidations

        let action = await primaryValidator.beginValidation(of: target)

        switch action {
        case .noValidation:
            handlePendingWaiters()
            return .noValidation

        case let .needed(contentRange):
            let operation = ValidationOperation(contentRange: contentRange, target: target)

            // if we have an outstanding async operation going, force this to be async too
            if outstanding {
                enqueueValidationOnActor(operation)
                return action
            }

            guard let validation = configuration.provider.sync(contentRange) else {
                enqueueValidationOnActor(operation)
                return action
            }

            await completePrimaryValidationOnActor(of: operation, with: validation)

            return .noValidation
        }
    }

    /// Validates the specified target range with external actor isolation.
    /// - Parameters:
    ///   - target: The range target to validate
    ///   - isolation: The actor context for isolation
    /// - Returns: The validation action that was performed
    @discardableResult
    public func validate(
        _ target: RangeTarget,
        isolation _: isolated (any Actor)
    ) async -> RangeValidator<Content>.Action {
        // Call the actor-isolated version
        await validateOnActor(target)
    }

    private func enqueueValidationOnActor(_ operation: ValidationOperation) {
        eventQueue.enqueue(operation)

        Task {
            await validateRangeOnActor()
        }
    }

    private func enqueueValidation(_ operation: ValidationOperation, isolation: isolated any Actor) {
        Task {
            await enqueueValidationOnActor(operation)
            await validateRangeAsync(isolation: isolation)
        }
    }

    private func validateRangeAsync(isolation: isolated any Actor) async {
        // This method needs to run in the actor's context to access eventQueue
        await performValidateRangeAsync(isolation: isolation)
    }

    private func validateRangeOnActor() async {
        guard let operation = eventQueue.next() else {
            preconditionFailure("There must always be a next operation to process")
        }

        let validation = await configuration.provider.async(isolation: self, operation.contentRange)

        await completePrimaryValidationOnActor(of: operation, with: validation)
    }

    private func performValidateRangeAsync(isolation: isolated any Actor) async {
        // Get operation in actor context first
        let operation = await getNextOperation()

        guard let operation else {
            preconditionFailure("There must always be a next operation to process")
        }

        let validation = await configuration.provider.async(isolation: isolation, operation.contentRange)

        await completePrimaryValidation(of: operation, with: validation, externalIsolation: isolation)
    }

    private func getNextOperation() async -> ValidationOperation? {
        eventQueue.next()
    }

    private func completePrimaryValidationWithIsolation(
        of operation: ValidationOperation,
        with validation: Validation,
        isolation: isolated (any Actor)
    ) async {
        await completePrimaryValidation(of: operation, with: validation, externalIsolation: isolation)
    }

    // Actor-isolated version without external isolation
    private func completePrimaryValidationOnActor(
        of operation: ValidationOperation,
        with validation: Validation
    ) async {
        await primaryValidator.completeValidation(of: operation.contentRange, with: validation)

        switch validation {
        case .stale:
            Task {
                let currentVersion = await self.version
                if operation.contentRange.version == currentVersion {
                    // Version unchanged after stale results, stopping validation
                    return
                }

                await self.validateOnActor(operation.target)
            }

        case let .success(range):
            let complete = await primaryValidator.isValid(operation.target)

            validationHandler(range, complete)

            // this only makes sense if the content has remained unchanged
            if complete {
                handlePendingWaiters()
                return
            }

            Task {
                await self.validateOnActor(operation.target)
            }
        }
    }

    // Version that runs with external isolation - cannot access actor state directly
    private func completePrimaryValidation(
        of operation: ValidationOperation,
        with validation: Validation,
        externalIsolation: isolated (any Actor)
    ) async {
        await primaryValidator.completeValidation(of: operation.contentRange, with: validation)

        switch validation {
        case .stale:
            Task {
                let currentVersion = await self.version
                if operation.contentRange.version == currentVersion {
                    // Version unchanged after stale results, stopping validation
                    return
                }

                await self.validate(operation.target, isolation: externalIsolation)
            }

        case let .success(range):
            let complete = await primaryValidator.isValid(operation.target)

            // Need to handle validation completion
            await self.handleValidationCompletionOnActor(range: range, complete: complete, target: operation.target, externalIsolation: externalIsolation)
        }
    }

    // Actor-isolated method to handle validation completion
    private func handleValidationCompletionOnActor(range: NSRange, complete: Bool, target: RangeTarget, externalIsolation: isolated (any Actor)) async {
        // Call actor-isolated method to perform the actual work
        await performValidationCompletion(range: range, complete: complete)

        // Continue validation if needed
        if !complete {
            await self.validate(target, isolation: externalIsolation)
        }
    }

    // Actor-isolated method without isolation parameter to access actor state
    private func performValidationCompletion(range: NSRange, complete: Bool) async {
        validationHandler(range, complete)

        if complete {
            handlePendingWaiters()
        }
    }

    /// Validates the specified target range on the main actor.
    /// - Parameter target: The range target to validate
    /// - Returns: The validation action that was performed
    @MainActor
    @preconcurrency
    @discardableResult
    public func validate(
        _ target: RangeTarget
    ) async -> RangeValidator<Content>.Action {
        await validate(target, isolation: MainActor.shared)
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
    public func contentChanged(in range: NSRange, delta: Int) async {
        await primaryValidator.contentChanged(in: range, delta: delta)
    }

    /// Notifies the validator that validation processing has completed.
    /// This method must be called from within the actor's isolation context.
    public func validationCompleted() async {
        await eventQueue.processingCompleted(isolation: self)
    }

    deinit {
        // Cleanup if needed
    }
}
