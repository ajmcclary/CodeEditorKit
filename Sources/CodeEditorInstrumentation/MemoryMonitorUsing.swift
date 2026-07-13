/// A live component whose memory monitor can be rebound without replacement.
@MainActor
public protocol MemoryMonitorUsing: AnyObject {
    /// Moves cleanup registration and monitoring to a new monitor.
    /// - Parameter monitor: The monitor that should own subsequent cleanup work.
    func setMemoryMonitor(_ monitor: MemoryMonitor)
}
