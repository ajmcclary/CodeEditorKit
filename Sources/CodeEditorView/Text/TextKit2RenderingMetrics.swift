import Foundation
#if canImport(Combine)
import Combine
#endif

/// Measurements captured from actual TextKit 2 layout passes.
@MainActor
public final class TextKit2RenderingMetrics: ObservableObject {
    /// Number of observed layout passes.
    @Published public private(set) var layoutPassCount = 0

    /// Number of fragments intersecting the viewport during the latest pass.
    @Published public private(set) var visibleFragmentCount = 0

    /// Duration of the latest observed layout pass.
    @Published public private(set) var latestLayoutDuration = Duration.zero

    /// Average duration in seconds across observed layout passes.
    @Published public private(set) var averageLayoutTime: TimeInterval = 0

    private var totalLayoutTime: TimeInterval = 0

    /// Records a completed, observed layout pass.
    /// - Parameters:
    ///   - duration: Measured wall-clock duration of the pass.
    ///   - visibleFragmentCount: Fragments intersecting the current viewport.
    public func recordLayoutPass(
        duration: Duration,
        visibleFragmentCount: Int
    ) {
        layoutPassCount += 1
        self.visibleFragmentCount = max(0, visibleFragmentCount)
        latestLayoutDuration = duration
        let components = duration.components
        let seconds = Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
        totalLayoutTime += seconds
        averageLayoutTime = totalLayoutTime / Double(layoutPassCount)
    }
}
