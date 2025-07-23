import Foundation

/// An actor that manages three-phase range validation with primary, fallback, and secondary validation stages.
/// This validator provides comprehensive validation workflows with different performance characteristics.
public actor ThreePhaseRangeValidator<Content: VersionedContent> {
    /// Type alias for the primary single-phase validator used in the first validation stage.
    public typealias PrimaryValidator = SinglePhaseRangeValidator<Content>
    private typealias InternalValidator = RangeValidator<Content>

    /// Type alias for validation completion handlers.
    public typealias ValidationHandler = @Sendable (NSRange) -> Void

    /// Type alias for content ranges with version information.
    public typealias ContentRange = RangeValidator<Content>.ContentRange
    /// Type alias for the validation provider used by the primary validator.
    public typealias Provider = PrimaryValidator.Provider
    /// Type alias for fallback validation handlers that provide immediate results.
    public typealias FallbackHandler = @Sendable (NSRange) -> Void
    /// Type alias for secondary validation providers that perform background validation.
    public typealias SecondaryValidationProvider = @Sendable (ContentRange) async -> Validation

    private typealias Sequence = AsyncStream<ContentRange>

    public struct Configuration: Sendable {
        public let versionedContent: Content
        public let provider: Provider
        public let fallbackHandler: FallbackHandler?
        public let secondaryProvider: SecondaryValidationProvider?
        public let secondaryValidationDelay: TimeInterval

        public init(
            versionedContent: Content,
            provider: Provider,
            fallbackHandler: FallbackHandler? = nil,
            secondaryProvider: SecondaryValidationProvider? = nil,
            secondaryValidationDelay: TimeInterval = 2.0
        ) {
            self.versionedContent = versionedContent
            self.provider = provider
            self.fallbackHandler = fallbackHandler
            self.secondaryProvider = secondaryProvider
            self.secondaryValidationDelay = secondaryValidationDelay
        }
    }

    private let primaryValidator: PrimaryValidator
    private let fallbackValidator: InternalValidator
    private let secondaryValidator: InternalValidator?
    private var task: Task<Void, Error>?

    /// The configuration used by this validator, accessible from any isolation context.
    public nonisolated let configuration: Configuration

    /// Creates a new three-phase range validator with the specified configuration and actor isolation.
    /// - Parameters:
    ///   - configuration: The configuration for this validator
    ///   - isolation: The actor context for isolation
    public init(configuration: Configuration, isolation: isolated(any Actor)) {
        self.configuration = configuration
        primaryValidator = PrimaryValidator(
            configuration: .init(
                versionedContent: configuration.versionedContent,
                provider: configuration.provider
            )
        )

        fallbackValidator = InternalValidator(content: configuration.versionedContent)
        secondaryValidator = InternalValidator(content: configuration.versionedContent)

        Task { [weak self] in
            guard let self else { return }

            let validationHandlerWrapper: @Sendable (NSRange, Bool) -> Void = { [weak self] range, _ in
                guard let self else { return }
                Task {
                    await self.handlePrimaryValidation(of: range, isolation: isolation)
                }
            }

            await self.primaryValidator.setValidationHandler(validationHandlerWrapper)
        }
    }

    /// Creates a new three-phase range validator on the main actor.
    /// - Parameter configuration: The configuration for this validator
    @MainActor
    @preconcurrency
    public init(configuration: Configuration) {
        self.init(configuration: configuration, isolation: MainActor.shared)
    }

    private var version: Content.Version {
        get async {
            configuration.versionedContent.currentVersion
        }
    }

    /// Manually mark a region as invalid.
    public func invalidate(_ target: RangeTarget) async {
        await primaryValidator.invalidate(target)
        await fallbackValidator.invalidate(target)
        await secondaryValidator?.invalidate(target)
    }

    /// Validates the specified target range with external actor isolation.
    /// - Parameters:
    ///   - target: The range target to validate
    ///   - isolation: The actor context for isolation
    public func validate(_ target: RangeTarget, isolation: isolated (any Actor)) async {
        let action = await primaryValidator.validate(target, isolation: isolation)

        switch action {
        case .noValidation:
            scheduleSecondaryValidation(of: target, isolation: isolation)

        case let .needed(contentRange):
            await fallbackValidate(contentRange.value)
        }
    }

    /// Validates the specified target range on the main actor.
    /// - Parameter target: The range target to validate
    @MainActor
    @preconcurrency
    public func validate(_ target: RangeTarget) async {
        await validate(target, isolation: MainActor.shared)
    }

    private func fallbackValidate(_ targetRange: NSRange) async {
        guard let provider = configuration.fallbackHandler else {
            return
        }

        let action = await fallbackValidator.beginValidation(of: .range(targetRange))

        switch action {
        case .noValidation:
            return

        case let .needed(contentRange):
            provider(contentRange.value)

            await fallbackValidator.completeValidation(of: contentRange, with: .success(contentRange.value))
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
    public func contentChanged(in range: NSRange, delta: Int) async {
        await primaryValidator.contentChanged(in: range, delta: delta)
        await fallbackValidator.contentChanged(in: range, delta: delta)
        await secondaryValidator?.contentChanged(in: range, delta: delta)

        task?.cancel()
    }

    /// The name of this validator instance for debugging and identification purposes.
    public var name: String? {
        get async {
            await primaryValidator.name
        }
    }

    /// Sets the name of this validator instance.
    /// - Parameter newValue: The name to assign to this validator
    public func setName(_ newValue: String?) async {
        await primaryValidator.setName(newValue)
    }

    deinit {
        // Cleanup if needed
    }

    // MARK: - Private Methods

    private func handlePrimaryValidation(of range: NSRange, isolation: isolated (any Actor)) async {
        let target = RangeTarget.range(range)

        await fallbackValidator.invalidate(target)
        await secondaryValidator?.invalidate(target)

        scheduleSecondaryValidation(of: target, isolation: isolation)
    }

    private func scheduleSecondaryValidation(of target: RangeTarget, isolation: isolated (any Actor)) {
        Task {
            await self.scheduleSecondaryValidationAsync(target: target, isolation: isolation)
        }
    }

    private func scheduleSecondaryValidationAsync(target: RangeTarget, isolation: isolated (any Actor)) async {
        guard await shouldScheduleSecondaryValidation() else {
            return
        }

        // Cancel and set task in actor-isolated context
        await cancelAndScheduleTask(target: target, externalIsolation: isolation)
    }

    // Actor-isolated helper to check configuration
    private func shouldScheduleSecondaryValidation() async -> Bool {
        configuration.secondaryProvider != nil && secondaryValidator != nil
    }

    private func cancelAndScheduleTask(target: RangeTarget, externalIsolation: isolated (any Actor)) async {
        // Cancel existing task and get request version
        let (requestingVersion, delay) = await prepareForScheduling()

        let newTask = Task {
            try await Task.sleep(nanoseconds: delay)

            await self.secondaryValidate(target: target, requestingVersion: requestingVersion, isolation: externalIsolation)
        }

        await setTask(newTask)
    }

    // Actor-isolated methods to access actor state
    private func prepareForScheduling() async -> (Content.Version, UInt64) {
        task?.cancel()
        let requestingVersion = configuration.versionedContent.currentVersion
        let delay = max(UInt64(configuration.secondaryValidationDelay * 1_000_000_000), 0)
        return (requestingVersion, delay)
    }

    private func setTask(_ newTask: Task<Void, Error>) async {
        self.task = newTask
    }

    private func secondaryValidate(
        target: RangeTarget,
        requestingVersion: Content.Version,
        isolation _: isolated (any Actor)
    ) async {
        let currentVersion = await version
        guard requestingVersion == currentVersion,
              let validator = secondaryValidator,
              let provider = configuration.secondaryProvider
        else {
            return
        }

        let action = await validator.beginValidation(of: target)

        switch action {
        case .noValidation:
            return

        case let .needed(contentRange):
            let validation = await provider(contentRange)

            await validator.completeValidation(of: contentRange, with: validation)
        }
    }
}
