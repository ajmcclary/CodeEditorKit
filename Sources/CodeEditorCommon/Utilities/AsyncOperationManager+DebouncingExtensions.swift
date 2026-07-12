// swiftlint:disable missing_docs
import Foundation

// MARK: - Debouncing

extension AsyncOperationManager {
    /// Debounces execution of an operation by delaying until a quiet period.
    ///
    /// Debouncing delays operation execution until after a period of inactivity.
    /// If called multiple times rapidly, only the last call executes after the delay.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Debounce search to wait 0.3 seconds after typing stops
    /// try await manager.debounce(
    ///     key: "search",
    ///     delay: 0.3
    /// ) {
    ///     try await performSearch(query: searchText)
    /// }
    ///
    /// // Debounce file saves
    /// try await manager.debounce(
    ///     key: "save-\(fileId)",
    ///     delay: 1.0
    /// ) {
    ///     try await saveFile(content: updatedContent)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - key: Unique identifier for the debounced operation.
    ///   - delay: Time to wait after the last call before executing, in seconds.
    ///   - operation: The async operation to debounce.
    ///
    /// - Returns: The result of the operation when it eventually executes.
    ///
    /// - Throws: Any error thrown by the operation or stored from previous execution.
    ///
    /// - Note: Only the last operation in a debounce sequence is executed.
    public func debounce<T: Sendable>(
        key: String,
        delay: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let boxed = try await debounceKernel.run(
            key: key,
            delay: .seconds(max(0, delay))
        ) {
            AnySendableValue(value: try await operation())
        }
        guard let result = boxed.value as? T else {
            throw AsyncOperationError.noResult
        }
        return result
    }

    /// Creates a debounced version of an async function.
    ///
    /// Returns a function that automatically debounces calls to the original function.
    /// Ideal for creating reusable debounced operations that can be called multiple times.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let debouncedSave = await manager.makeDebounced(
    ///     key: "auto-save",
    ///     delay: 2.0
    /// ) {
    ///     try await document.save()
    /// }
    ///
    /// // Call multiple times - only last execution runs
    /// Task { try await debouncedSave() }
    /// Task { try await debouncedSave() }
    /// Task { try await debouncedSave() } // Only this executes
    /// ```
    ///
    /// - Parameters:
    ///   - key: Unique identifier for the debounced operation.
    ///   - delay: Time to wait after the last call before executing, in seconds.
    ///   - operation: The async operation to debounce.
    ///
    /// - Returns: A debounced version of the operation.
    public func makeDebounced<T: Sendable>(
        key: String,
        delay: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) -> @Sendable () async throws -> T {
        {
            try await self.debounce(key: key, delay: delay, operation: operation)
        }
    }

    @available(*, deprecated, renamed: "debounce(key:delay:operation:)")
    public func debounceOptimized<T: Sendable>(
        key: String,
        delay: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await debounce(key: key, delay: delay, operation: operation)
    }

    public func debounceFireAndForget(
        key: String,
        delay: TimeInterval,
        operation: @escaping @Sendable () async -> Void
    ) async {
        await fireAndForgetDebouncer.schedule(
            key: key,
            delay: .seconds(max(0, delay)),
            operation: operation
        )
    }

    public func batchDebounce<T: Sendable>(
        operations: [String: @Sendable () async throws -> T],
        delay: TimeInterval
    ) async throws -> [String: T] {
        await withTaskGroup(of: (String, T?).self) { group in
            for (key, operation) in operations {
                group.addTask {
                    let value = try? await self.debounce(
                        key: key,
                        delay: delay,
                        operation: operation
                    )
                    return (key, value)
                }
            }
            var results: [String: T] = [:]
            for await (key, value) in group {
                results[key] = value
            }
            return results
        }
    }
}

// swiftlint:enable missing_docs
