import Foundation
import QuartzCore
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Real-time frame-rate measurement using a `CADisplayLink` ticker.
///
/// Maintains a 1-second sliding window of frame timestamps and exposes the
/// frame count in that window as both an integer (`currentFPS`) and a decimal
/// average (`averageFPS`). Off by default; call `startMonitoring()` to begin.
@MainActor
@Observable
public final class FrameRateMonitor {
    /// Current frame rate in frames per second, sampled over the last second.
    public private(set) var currentFPS: Int = 0
    /// Average frame rate over the last second as a decimal.
    public private(set) var averageFPS: Double = 0

    @ObservationIgnored private var timestamps: [TimeInterval] = []
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var bridge: DisplayLinkBridge?

    /// Creates a stopped monitor. Call `startMonitoring()` to begin sampling.
    public init() {}

    /// Begins sampling frame timestamps from the main screen's display link.
    public func startMonitoring() {
        guard displayLink == nil else { return }
        let bridge = DisplayLinkBridge { [weak self] timestamp in
            self?.handleTick(timestamp: timestamp)
        }
        let link: CADisplayLink?
        #if canImport(AppKit)
        link = NSScreen.main?.displayLink(target: bridge, selector: #selector(DisplayLinkBridge.tick(_:)))
        #elseif canImport(UIKit)
        link = UIScreen.main.displayLink(target: bridge, selector: #selector(DisplayLinkBridge.tick(_:)))
        #else
        link = nil
        #endif
        guard let link else { return }
        link.add(to: .main, forMode: .common)
        self.bridge = bridge
        self.displayLink = link
    }

    /// Stops sampling and resets the published metrics to zero.
    public func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        bridge = nil
        timestamps.removeAll(keepingCapacity: true)
        currentFPS = 0
        averageFPS = 0
    }

    /// Pure function over a window of timestamps so tests don't need a real display link.
    public static func computeFPS(
        timestamps: [TimeInterval],
        window: TimeInterval,
        now: TimeInterval
    ) -> (current: Int, average: Double) {
        let cutoff = now - window
        let recent = timestamps.filter { $0 >= cutoff }
        let count = recent.count
        return (current: count, average: Double(count))
    }

    private func handleTick(timestamp: TimeInterval) {
        timestamps.append(timestamp)
        if let first = timestamps.first, timestamp - first > 2.0 {
            timestamps.removeAll { $0 < timestamp - 1.0 }
        }
        let result = Self.computeFPS(timestamps: timestamps, window: 1.0, now: timestamp)
        currentFPS = result.current
        averageFPS = result.average
    }
}

@MainActor
private final class DisplayLinkBridge: NSObject {
    private let onTick: (TimeInterval) -> Void

    init(onTick: @escaping (TimeInterval) -> Void) {
        self.onTick = onTick
        super.init()
    }

    @objc func tick(_ link: CADisplayLink) {
        onTick(link.timestamp)
    }
}
