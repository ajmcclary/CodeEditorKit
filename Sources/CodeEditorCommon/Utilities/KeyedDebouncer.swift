import Foundation

/// Replaces delayed operations by key while preserving typed results.
public actor KeyedDebouncer<Key: Hashable & Sendable, Value: Sendable> {
    private struct Entry {
        let token: UUID
        let task: Task<Value, any Error>
    }

    private var tasks: [Key: Entry] = [:]

    /// Creates an empty keyed operation registry.
    public init() {}

    /// Runs an operation after `delay`, cancelling any prior operation for `key`.
    public func run(
        key: Key,
        delay: Duration,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        tasks[key]?.task.cancel()
        let token = UUID()
        let task = Task<Value, any Error> {
            try await Task.sleep(for: delay)
            try Task.checkCancellation()
            return try await operation()
        }
        tasks[key] = Entry(token: token, task: task)
        defer {
            if tasks[key]?.token == token {
                tasks[key] = nil
            }
        }
        return try await task.value
    }

    /// Keys whose delayed operations have not yet completed or been cancelled.
    public var activeKeys: Set<Key> {
        Set(tasks.keys)
    }
}

extension KeyedDebouncer where Value == Void {
    /// Schedules a replaceable fire-and-forget operation.
    public func schedule(
        key: Key,
        delay: Duration,
        operation: @escaping @Sendable () async -> Void
    ) {
        tasks[key]?.task.cancel()
        let token = UUID()
        let task = Task<Void, any Error> { [weak self] in
            do {
                try await Task.sleep(for: delay)
                try Task.checkCancellation()
                await operation()
            } catch is CancellationError {
                // Replacement is the expected terminal state.
            }
            await self?.removeTask(key: key, token: token)
        }
        tasks[key] = Entry(token: token, task: task)
    }

    private func removeTask(key: Key, token: UUID) {
        if tasks[key]?.token == token {
            tasks[key] = nil
        }
    }
}

struct AnySendableValue: @unchecked Sendable {
    let value: Any
}
