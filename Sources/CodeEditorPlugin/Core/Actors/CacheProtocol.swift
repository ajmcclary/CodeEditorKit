import Foundation

// MARK: - Cache Protocol

/// Protocol for caches that can be managed by CacheCoordinatorActor
@available(macOS 13.0, iOS 16.0, *)
public protocol CacheProtocol: Actor {
    associatedtype Value: Sendable
    func getValue(for key: String) async -> Value?
    func setValue(_ value: Value, for key: String, cost: Int) async
    func contains(key: String) async -> Bool
    func clear() async
}
