import Foundation

// MARK: - HybridSyncAsyncValueProvider

/// A type that can perform work both synchronously and asynchronously.
public struct HybridSyncAsyncValueProvider<Input, Output, Failure: Error> {
    public typealias SyncValueProvider = (Input) throws(Failure) -> Output?
    public typealias AsyncValueProvider = (isolated (any Actor), sending Input) async throws(Failure) -> sending Output

    public let syncValueProvider: SyncValueProvider
    public let asyncValueProvider: AsyncValueProvider

    public init(
        syncValue: @escaping SyncValueProvider = { _ in nil },
        asyncValue: @escaping AsyncValueProvider
    ) {
        syncValueProvider = syncValue
        asyncValueProvider = asyncValue
    }

    public func async(isolation: isolated (any Actor), _ input: sending Input) async throws(Failure) -> sending Output {
        try await asyncValueProvider(isolation, input)
    }

    @MainActor
    @preconcurrency
    public func async(_ input: sending Input) async throws(Failure) -> sending Output {
        try await asyncValueProvider(MainActor.shared, input)
    }

    public func sync(_ input: Input) throws(Failure) -> Output? {
        try syncValueProvider(input)
    }

    /// Create an instance that can statically prove to the compiler that asyncValueProvider is isolated to the MainActor.
    @preconcurrency
    public init(
        syncValue: @escaping SyncValueProvider = { _ in nil },
        mainActorAsyncValue: @escaping @MainActor (Input) async throws(Failure) -> sending Output
    ) {
        syncValueProvider = syncValue
        asyncValueProvider = { _, input async throws(Failure) in
            try await mainActorAsyncValue(input)
        }
    }

    // MARK: - Work in Progress

    // I've not yet gotten these working right, but I think there could be something here.

    // Returns a new `HybridSyncAsyncValueProvider` with a new output type.
    //  func map<T>(_ transform: @escaping (isolated (any Actor)?, Output) throws -> T) -> HybridSyncAsyncValueProvider<Input, T, any Error> {
    //      .init(
    //          syncValue: { input in
    //              guard let output = try sync(input) else {
    //                  return nil
    //              }
//
    //              return try transform(#isolation, output)
    //          },
    //          asyncValue: { (isolation, input) in
    //              try transform(isolation, try await self.async(isolation: isolation, input))
    //          }
    //      )
    //  }

    //  /// Transforms the `Failure` type of `HybridSyncAsyncValueProvider` to `Never`,
    //  func catching(_ block: @escaping (Input, Error) -> Output) -> HybridSyncAsyncValueProvider<Input, Output, Never> {
    //      .init(
    //          syncValue: {
    //              do {
    //                  return try self.sync($0)
    //              } catch {
    //                  return block($0, error)
    //              }
    //          },
    //          asyncValue: {
    //              do {
    //                  return try await self.async(isolation: $0, $1)
    //              } catch {
    //                  return block($1, error)
    //              }
    //          }
    //      )
    //  }
}

// MARK: - RangeProcessor Integration

extension HybridSyncAsyncValueProvider where Failure == Never {
    /// Construct a `HybridSyncAsyncValueProvider` that will first attempt to process a location using a `RangeProcessor`.
    init(
        isolation: isolated(any Actor),
        rangeProcessor: RangeProcessor,
        inputTransformer: @escaping (Input) -> (Int, RangeFillMode),
        syncValue: @escaping SyncValueProvider,
        asyncValue: @escaping (Input) async throws(Failure) -> sending Output
    ) {
        // bizarre local-function workaround https://github.com/swiftlang/swift/issues/77067
        func syncVersionWrapper(input: Input) throws(Failure) -> Output? {
            let (location, fill) = inputTransformer(input)

            if rangeProcessor.processLocation(location, isolation: isolation, mode: fill) {
                return try syncValue(input)
            }

            return nil
        }

        // and similar
        func asyncVersionWrapper(isolation: isolated (any Actor), input: sending Input) async throws(Failure) -> sending Output {
            let (location, fill) = inputTransformer(input)

            // processLocation returns Bool, not an enum
            _ = rangeProcessor.processLocation(location, isolation: isolation, mode: fill)

            // If the location was successfully processed, execute the async value
            return try await asyncValue(input)
        }

        self.init(
            syncValue: syncVersionWrapper,
            asyncValue: asyncVersionWrapper
        )
    }
}
