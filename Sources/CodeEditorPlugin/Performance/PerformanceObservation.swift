//
//  PerformanceObservation.swift
//  CodeEditorPlugin
//
//  Host-facing observable wrapper around `UnifiedPerformanceSystem`. Owns
//  an internal Task-driven refresh loop that periodically snapshots
//  `system.generateInsights()` into `lastInsights`. Designed to be paired
//  with the `.performanceObserver(_:)` modifier, which injects
//  `observation.system` into the editor's effective `EditorConfiguration`
//  so framework producers (e.g. `AsyncSyntaxHighlighter`) record metrics
//  into the same system the host observes.
//

import Foundation
import Observation

/// Host-facing observable wrapper around `UnifiedPerformanceSystem`.
///
/// Pair with the `.performanceObserver(_:)` SwiftUI modifier on
/// `CodeEditor` to fold the two existing wirings (config injection so
/// `AsyncSyntaxHighlighter` can record metrics, and host-side polling of
/// `generateInsights()`) into a single attachment. The host constructs
/// the observation, calls `start()` (or relies on the inspector
/// lifecycle), and reads `lastInsights` from SwiftUI bodies.
///
/// ## Example
///
/// ```swift
/// @State private var observation = PerformanceObservation()
///
/// var body: some View {
///     CodeEditor(text: $code)
///         .performanceObserver(observation)
///     Text("Health: \(observation.lastInsights.overallHealth, format: .number)")
/// }
/// ```
@available(macOS 13.0, iOS 16.0, *)
@MainActor
@Observable
public final class PerformanceObservation {
    /// The underlying performance system. `let` so hosts can call
    /// `system.track(...)` directly for custom producers.
    public let system: UnifiedPerformanceSystem

    /// Most recent snapshot from `system.generateInsights()`. Updated by
    /// the internal refresh loop while `start()`ed, or by direct
    /// `refresh()` calls from outside the loop.
    public private(set) var lastInsights: UnifiedPerformanceInsights

    /// Interval between refreshes. Mutating after `start()` takes effect
    /// on the next sleep boundary (the in-flight `Task.sleep` finishes
    /// first, then the loop reads the new value).
    public var refreshInterval: Duration

    /// Test/debug probe: counts every successful `refresh()` invocation
    /// (whether driven by the internal loop or called externally).
    internal private(set) var refreshCount: Int = 0

    /// Test/debug probe: counts how many refresh `Task`s have been
    /// spawned by `start()`. Idempotent `start()` calls must not bump
    /// this — used by `startIsIdempotent` to avoid timing flakiness.
    internal private(set) var refreshTaskSpawnCount: Int = 0

    /// `@ObservationIgnored` takes the property out of the `@Observable`
    /// macro's tracking expansion (internal task state shouldn't drive
    /// SwiftUI invalidation). Under strict concurrency the `Task<Void,
    /// Never>` storage is implicitly nonisolated because the type is
    /// `Sendable`; deinit (which runs in a nonisolated context) can
    /// cancel the task directly without a `nonisolated(unsafe)`
    /// annotation. Writes happen only from `@MainActor` (`start` /
    /// `stop`), so the deinit read happens-after the last `@MainActor`
    /// reference is released.
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    /// Creates a new performance observation.
    ///
    /// - Parameters:
    ///   - system: The performance system to observe. Defaults to a
    ///     fresh `UnifiedPerformanceSystem()`; supply an existing
    ///     instance when sharing across editors or with custom producers.
    ///   - refreshInterval: How often the internal refresh loop calls
    ///     `system.generateInsights()` once `start()` is invoked.
    ///     Defaults to `.seconds(1)`.
    public init(
        system: UnifiedPerformanceSystem = UnifiedPerformanceSystem(),
        refreshInterval: Duration = .seconds(1)
    ) {
        self.system = system
        self.refreshInterval = refreshInterval
        self.lastInsights = UnifiedPerformanceInsights()
    }

    deinit {
        refreshTask?.cancel()
    }

    /// Starts the refresh loop. Idempotent — calling while running is a
    /// no-op. The loop runs at `refreshInterval` cadence; mutating
    /// `refreshInterval` takes effect on the next iteration.
    public func start() {
        guard refreshTask == nil else { return }
        refreshTaskSpawnCount += 1
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let interval = await self?.refreshInterval else { return }
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
                await self?.refresh()
            }
        }
    }

    /// Cancels the refresh loop. Idempotent.
    public func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// One-shot snapshot: reads `system.generateInsights()` and updates
    /// `lastInsights`. Safe to call from outside the refresh loop.
    public func refresh() {
        lastInsights = system.generateInsights()
        refreshCount += 1
    }
}
