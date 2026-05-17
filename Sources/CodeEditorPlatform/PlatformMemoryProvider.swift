import Foundation

/// Protocol for platform-specific memory information providers
public protocol PlatformMemoryProvider: Sendable {
    /// Get current memory usage in megabytes
    func getCurrentMemoryUsage() -> Double

    /// Get physical memory size in bytes
    func getPhysicalMemory() -> UInt64

    /// Get memory pressure status
    func getMemoryPressure() -> MemoryPressure

    /// Check if system is under memory pressure
    func isUnderMemoryPressure() -> Bool
}

/// Memory pressure levels
public enum MemoryPressure: String, Sendable, CaseIterable {
    case normal
    case warning
    case urgent
    case critical
}

// MARK: - Default Implementation

/// Default memory provider using platform-specific APIs
public struct SystemMemoryProvider: PlatformMemoryProvider {
    public init() {}

    public func getCurrentMemoryUsage() -> Double {
        #if canImport(Darwin)
        return getMachMemoryUsage()
        #elseif canImport(Linux)
        return getLinuxMemoryUsage()
        #else
        return 0.0
        #endif
    }

    public func getPhysicalMemory() -> UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    public func getMemoryPressure() -> MemoryPressure {
        let usage = getCurrentMemoryUsage()
        let totalMB = Double(getPhysicalMemory()) / (1_024 * 1_024)
        let usagePercent = (usage / totalMB) * 100

        switch usagePercent {
        case 0..<60:
            return .normal

        case 60..<75:
            return .warning

        case 75..<85:
            return .urgent

        default:
            return .critical
        }
    }

    public func isUnderMemoryPressure() -> Bool {
        getMemoryPressure() != .normal
    }

    // MARK: - Platform-Specific Implementations

    #if canImport(Darwin)
    private func getMachMemoryUsage() -> Double {
        var info = mach_task_basic_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1_024 * 1_024) // Convert to MB
        } else {
            return 0.0
        }
    }
    #endif

    #if canImport(Linux)
    private func getLinuxMemoryUsage() -> Double {
        // Read from /proc/self/status on Linux
        guard let data = try? String(contentsOfFile: "/proc/self/status", encoding: .utf8) else {
            return 0.0
        }

        let lines = data.components(separatedBy: .newlines)
        for line in lines where line.hasPrefix("VmRSS:") {
            let components = line.components(separatedBy: .whitespaces)
            if components.count >= 2,
               let kb = Double(components[1]) {
                return kb / 1_024.0 // Convert KB to MB
            }
        }

        return 0.0
    }
    #endif
}

// MARK: - Mock Implementation for Testing

/// Simple mock memory provider for testing
/// Note: This is a fully immutable version suitable for Sendable conformance
public struct MockMemoryProvider: PlatformMemoryProvider {
    private let memoryUsage: Double
    private let physicalMemory: UInt64
    private let memoryPressure: MemoryPressure

    public init(
        memoryUsage: Double = 100.0,
        physicalMemory: UInt64 = 8_589_934_592,
        memoryPressure: MemoryPressure = .normal
    ) {
        self.memoryUsage = memoryUsage
        self.physicalMemory = physicalMemory
        self.memoryPressure = memoryPressure
    }

    public func getCurrentMemoryUsage() -> Double {
        memoryUsage
    }

    public func getPhysicalMemory() -> UInt64 {
        physicalMemory
    }

    public func getMemoryPressure() -> MemoryPressure {
        memoryPressure
    }

    public func isUnderMemoryPressure() -> Bool {
        memoryPressure != .normal
    }

    /// Create a new mock with simulated memory pressure
    public func simulatingMemoryPressure(_ pressure: MemoryPressure) -> Self {
        // Adjust memory usage to match pressure level
        let totalMB = Double(physicalMemory) / (1_024 * 1_024)
        let newUsage: Double

        switch pressure {
        case .normal:
            newUsage = totalMB * 0.5

        case .warning:
            newUsage = totalMB * 0.65

        case .urgent:
            newUsage = totalMB * 0.8

        case .critical:
            newUsage = totalMB * 0.9
        }

        return Self(
            memoryUsage: newUsage,
            physicalMemory: physicalMemory,
            memoryPressure: pressure
        )
    }

    /// Create a new mock with custom memory usage
    public func withMemoryUsage(_ usage: Double) -> Self {
        Self(
            memoryUsage: usage,
            physicalMemory: physicalMemory,
            memoryPressure: memoryPressure
        )
    }

    /// Create a new mock with custom physical memory
    public func withPhysicalMemory(_ memory: UInt64) -> Self {
        Self(
            memoryUsage: memoryUsage,
            physicalMemory: memory,
            memoryPressure: memoryPressure
        )
    }
}
