/// Controls optional memory-management side effects for an editor runtime.
public struct MemoryManagementPolicy: Sendable, Equatable {
    /// Whether memory coordinators register cleanup handlers with their monitor.
    public var registersCleanupHandlers: Bool

    /// Creates a memory-management policy.
    /// - Parameter registersCleanupHandlers: Whether cleanup registration is enabled.
    public init(registersCleanupHandlers: Bool = true) {
        self.registersCleanupHandlers = registersCleanupHandlers
    }

    /// Production policy with cleanup registration enabled.
    public static let live = Self(registersCleanupHandlers: true)

    /// Policy for hosts that manage cleanup registration themselves.
    public static let disabled = Self(registersCleanupHandlers: false)
}
