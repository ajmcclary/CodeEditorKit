import CodeEditorPlugin
import Foundation
import Observation

/// Owns the sample's EventLog inspector lifecycle. Subscribes to a shared
/// `UnifiedEventSystem` and to `controller.completionEvents()`, appends each
/// incoming event to a bounded ring, and exposes the result through a single
/// `@Observable` snapshot for `EventLogPanel` to render.
///
/// Cross-platform: ungated by intent. The framework's `UnifiedEventSystem`
/// API is itself cross-platform, and the sample wires the same coordinator
/// into both `WindowBody` (macOS) and `IOSRootView` (iOS).
@MainActor
@Observable
final class EventLogSampleCoordinator {
    /// Source of an entry. Drives the filter pills in `EventLogPanel`.
    enum EventCategory: String, CaseIterable, Sendable, Hashable {
        case text
        case selection
        case focus
        case completion
    }

    /// One row in the panel. Pre-rendered summary so the view is trivial.
    struct LoggedEvent: Identifiable, Sendable, Hashable {
        let id: UUID
        let timestamp: Date
        let category: EventCategory
        let summary: String
        let detail: String?

        init(
            category: EventCategory,
            summary: String,
            detail: String? = nil,
            timestamp: Date = Date(),
            id: UUID = UUID()
        ) {
            self.id = id
            self.timestamp = timestamp
            self.category = category
            self.summary = summary
            self.detail = detail
        }

        /// Convenience factories used by the coordinator's translators and by tests.
        static func text(summary: String, timestamp: Date = Date()) -> Self {
            Self(category: .text, summary: summary, timestamp: timestamp)
        }
        static func selection(summary: String, timestamp: Date = Date()) -> Self {
            Self(category: .selection, summary: summary, timestamp: timestamp)
        }
        static func focus(summary: String, timestamp: Date = Date()) -> Self {
            Self(category: .focus, summary: summary, timestamp: timestamp)
        }
        static func completion(
            summary: String,
            detail: String? = nil,
            timestamp: Date = Date()
        ) -> Self {
            Self(category: .completion, summary: summary, detail: detail, timestamp: timestamp)
        }
    }

    /// Flat observable surface for `EventLogPanel`. All filtering is post-hoc;
    /// `ringCount` reflects the pre-filter ring size, `entries` reflects the
    /// post-filter newest-first view.
    struct Snapshot: Sendable {
        var entries: [LoggedEvent]
        var totals: [EventCategory: Int]
        var ringCount: Int

        static let empty = Self(entries: [], totals: [:], ringCount: 0)
    }

    private static let ringCapacity = 200

    // MARK: - Observable surface

    private(set) var snapshot: Snapshot = .empty
    private(set) var paused: Bool = false
    private(set) var mutedCategories: Set<EventCategory> = []

    // MARK: - Internals

    @ObservationIgnored
    private var ring: [LoggedEvent] = []

    @ObservationIgnored
    private var totals: [EventCategory: Int] = [:]

    // MARK: - Append (test-visible)

    /// Append a pre-translated `LoggedEvent`. Honors `paused` (drops on the
    /// floor) and the ring capacity (drops oldest). `internal` so tests can
    /// drive the coordinator without spinning up live subscriptions.
    func append(_ entry: LoggedEvent) {
        guard !paused else { return }
        ring.append(entry)
        if ring.count > Self.ringCapacity {
            ring.removeFirst(ring.count - Self.ringCapacity)
        }
        totals[entry.category, default: 0] += 1
        publishSnapshot()
    }

    // MARK: - Snapshot publishing

    private func publishSnapshot() {
        let filtered = ring
            .reversed()
            .filter { !mutedCategories.contains($0.category) }
        snapshot = Snapshot(entries: Array(filtered), totals: totals, ringCount: ring.count)
    }

    // MARK: - Actions

    /// Toggle whether `category` is hidden from the snapshot. Does NOT drop
    /// events from the underlying ring — pills only filter the view.
    func setMuted(_ category: EventCategory, _ muted: Bool) {
        if muted {
            mutedCategories.insert(category)
        } else {
            mutedCategories.remove(category)
        }
        publishSnapshot()
    }

    /// Pause receiving new events. Existing events stay in the ring.
    func setPaused(_ paused: Bool) {
        self.paused = paused
    }

    /// Empty the ring and reset all counts. Does NOT change `mutedCategories`
    /// or `paused`.
    func clear() {
        ring.removeAll()
        totals.removeAll()
        publishSnapshot()
    }
}
