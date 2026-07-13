/// `MemoryMonitor` is the live implementation of the lightweight
/// ``MemoryMonitoring`` contract. Kept in a separate file so the monitor's
/// own source stays byte-identical across the instrumentation split.
extension MemoryMonitor: MemoryMonitoring {}
