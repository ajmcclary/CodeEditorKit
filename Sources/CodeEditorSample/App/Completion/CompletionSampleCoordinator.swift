import CodeEditorCompletion
import CodeEditorLanguages
import CodeEditorPlugin
import CodeEditorSwiftUI
import Foundation
import Observation

/// Owns the sample's Completion Inspector lifecycle. Registers every
/// built-in language provider plus the demo provider with the attached
/// `EditorController`, wraps each in a `TelemetryCompletionProvider` so
/// the inspector sees every fire, and snapshots controller-level stats on
/// a 1Hz timer.
@MainActor
@Observable
final class CompletionSampleCoordinator {
    struct RegisteredProviderSummary: Identifiable, Sendable, Hashable {
        var id: String { providerId }
        let providerId: String
        let languages: [Language]      // empty == "all"
        let triggerCharacters: [String]
        let supportsSnippets: Bool
    }

    struct Snapshot: Sendable {
        var registeredProviders: [RegisteredProviderSummary]
        var recentActivity: [CompletionEvent]             // newest-first, max 20
        var lastActivity: CompletionEvent?
        var requests: Int
        var cacheHitRate: Double
        var avgProcessingMs: Double

        static let empty = Self(
            registeredProviders: [],
            recentActivity: [],
            lastActivity: nil,
            requests: 0,
            cacheHitRate: 0,
            avgProcessingMs: 0
        )
    }

    /// Bounded ring size for the recent-activity buffer.
    private static let ringCapacity = 20

    // MARK: - Observable surface

    private(set) var snapshot: Snapshot = .empty

    // MARK: - Non-observable internals

    @ObservationIgnored
    private weak var controller: EditorController?

    @ObservationIgnored
    private var refreshTimer: Timer?

    @ObservationIgnored
    private var ring: [CompletionEvent] = []

    @ObservationIgnored
    private var eventTask: Task<Void, Never>?

    // MARK: - Lifecycle

    /// Attaches the coordinator to an editor controller and registers every
    /// built-in language provider plus the demo provider. Does NOT start
    /// the polling timer — call `start()` from the panel's `.onAppear`,
    /// mirroring `PerformanceSampleCoordinator`.
    func attach(controller: EditorController) {
        self.controller = controller

        for provider in BuiltInLanguageProviders.all() {
            controller.registerCompletionProvider(provider)
        }
        controller.registerCompletionProvider(DemoCompletionProvider())

        eventTask?.cancel()
        eventTask = Task { @MainActor [weak self] in
            for await event in controller.completionEvents() {
                self?.record(event)
            }
        }

        refresh()
    }

    /// Starts the 1Hz snapshot refresh. Idempotent — calling start when
    /// already running is a no-op.
    func start() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard self != nil else {
                timer.invalidate()
                return
            }
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    /// Stops the 1Hz refresh and clears the controller reference. Tests
    /// should call this to keep run-loop-retained Timers from outliving
    /// the test under `swift test --parallel`.
    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func detach() {
        stop()
        eventTask?.cancel()
        eventTask = nil
        controller = nil
    }

    func resetActivity() {
        ring.removeAll()
        snapshot.recentActivity = []
        snapshot.lastActivity = nil
    }

    func fireAtCursor() {
        controller?.requestCompletion(triggerKind: .manual)
    }

    // MARK: - Telemetry

    func record(_ event: CompletionEvent) {
        ring.append(event)
        if ring.count > Self.ringCapacity {
            ring.removeFirst(ring.count - Self.ringCapacity)
        }
        snapshot.recentActivity = ring.reversed()
        snapshot.lastActivity = ring.last
    }

    // MARK: - Refresh

    func refresh() {
        let controller = self.controller
        let stats = controller?.completionStatistics
        snapshot.registeredProviders = (controller?.registeredCompletionProviders ?? [])
            .map { provider in
                RegisteredProviderSummary(
                    providerId: provider.id,
                    languages: provider.supportedLanguages,
                    triggerCharacters: provider.triggerCharacters,
                    supportsSnippets: provider.supportsSnippets
                )
            }
            .sorted { $0.providerId < $1.providerId }
        snapshot.requests = stats?.totalRequests ?? 0
        snapshot.cacheHitRate = stats?.cacheHitRate ?? 0
        snapshot.avgProcessingMs = (stats?.averageProcessingTime ?? 0) * 1_000
    }
}
