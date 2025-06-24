import Foundation

// MARK: - HybridSyncAsyncLanguageLayer

public struct HybridSyncAsyncLanguageLayer<Input: Sendable, Output: Sendable, Failure: Error & Sendable>: Sendable {
    let provider: HybridSyncAsyncValueProvider<Input, Output, Failure>
}

extension HybridSyncAsyncValueProvider {
    func access<Success>(
        isolation: isolated (any Actor),
        input: sending Input,
        operation: @escaping (Bool, Output) throws -> sending Success,
        completion: @escaping (Result<Success, Error>) -> Void
    ) where Input: Sendable {
        // make a synchronous attempt
        do {
            if let output = try sync(input) {
                let result = Result { try operation(true, output) }

                completion(result)
            }
        } catch {
            completion(.failure(error))
            return
        }

        Task {
            _ = isolation

            do {
                let output = try await self.async(isolation: isolation, input)

                let result = Result { try operation(false, output) }

                completion(result)
            } catch {
                completion(.failure(error))
            }
        }
    }
}

final class HybridSyncAsyncVersionedResource<Resource: Sendable> {
    typealias Version = Int
    typealias VersionedResource = Versioned<Version, Resource>
    typealias SyncAvailable = @Sendable (Version) -> Bool
    typealias Provider = HybridSyncAsyncValueProvider<Version, Resource, any Error>

    private let resource: VersionedResource
    let syncAvailable: SyncAvailable

    init(resouce: Resource, syncAvailable: @escaping SyncAvailable) {
        resource = VersionedResource(resouce, version: 0)
        self.syncAvailable = syncAvailable
    }

    func access<Success: Sendable>(
        version _: Version,
        operation: @escaping @Sendable (Bool, Resource) throws -> sending Success,
        completion: @escaping @Sendable (Result<Success, Error>) -> Void
    ) {
        if syncAvailable(resource.version) {
            let result = Result { try operation(true, resource.value) }
            completion(result)
            return
        }
    }

    deinit {
        // Cleanup if needed
    }
}
