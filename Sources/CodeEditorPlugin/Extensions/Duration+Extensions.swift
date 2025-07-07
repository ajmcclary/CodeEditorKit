import Foundation

// MARK: - Duration Extensions

@available(macOS 13.0, iOS 16.0, *)
extension Duration {
    /// Converts Duration to TimeInterval (seconds as Double)
    ///
    /// This convenience property simplifies Duration to TimeInterval conversion
    /// by handling both seconds and attoseconds components.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let duration = Duration.seconds(2.5)
    /// let timeInterval = duration.timeInterval // 2.5
    /// ```
    public var timeInterval: TimeInterval {
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1e18
        return seconds + attoseconds
    }
}
