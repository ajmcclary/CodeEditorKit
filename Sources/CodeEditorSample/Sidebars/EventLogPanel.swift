import CodeEditorPlugin
import CodeEditorSwiftUI
import DesignKitTokens
import SwiftUI

/// Stateless view backing the EventLog inspector. Takes the coordinator's
/// snapshot fields as parameters — no direct coordinator reference — so it
/// remains snapshot-testable.
struct EventLogPanel: View {
    typealias Category = EventLogSampleCoordinator.EventCategory
    typealias LoggedEvent = EventLogSampleCoordinator.LoggedEvent

    let entries: [LoggedEvent]
    let totals: [Category: Int]
    let mutedCategories: Set<Category>
    let paused: Bool

    var onToggleCategory: (Category) -> Void
    var onTogglePause: () -> Void
    var onClear: () -> Void
    var onAppear: () -> Void = {}
    var onDisappear: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            pillsRow
            Divider()
            entriesList
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Events").font(.headline)
            Spacer()
            Text("\(entries.count) shown · \(totals.values.reduce(0, +)) total")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Pills + controls

    private var pillsRow: some View {
        HStack(spacing: 6) {
            ForEach(Category.allCases, id: \.self) { category in
                CategoryPill(
                    category: category,
                    count: totals[category] ?? 0,
                    muted: mutedCategories.contains(category)
                ) { onToggleCategory(category) }
            }
            Spacer()
            Button(action: onTogglePause) {
                Label(
                    paused ? "Resume" : "Pause",
                    systemImage: paused ? "play.fill" : "pause.fill"
                )
                .labelStyle(.iconOnly)
            }
            .controlSize(.small)
            .help(paused ? "Resume receiving events" : "Pause receiving events")

            Button("Clear", action: onClear)
                .controlSize(.small)
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Entries

    private var entriesList: some View {
        Group {
            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(entries) { entry in
                            EventLogRow(entry: entry)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 200, maxHeight: 360)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No events yet.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("Type to see textDidChange fire.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }
}

private struct CategoryPill: View {
    let category: EventLogSampleCoordinator.EventCategory
    let count: Int
    let muted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 4) {
                Circle()
                    .fill(EventLogPanel.color(for: category))
                    .frame(width: 6, height: 6)
                Text("\(category.rawValue.capitalized) · \(count)")
                    .font(.system(size: 11, design: .monospaced))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(muted ? Color.clear : EventLogPanel.color(for: category).opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(EventLogPanel.color(for: category).opacity(muted ? 0.6 : 0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EventLogRow: View {
    let entry: EventLogSampleCoordinator.LoggedEvent

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(Self.timeFormatter.string(from: entry.timestamp))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            HStack(spacing: 4) {
                Circle()
                    .fill(EventLogPanel.color(for: entry.category))
                    .frame(width: 6, height: 6)
                Text(entry.category.rawValue.capitalized)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 90, alignment: .leading)

            if entry.detail != nil, entry.category == .completion,
               entry.summary.hasSuffix("failed") {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.system(size: 10))
            }

            Text(entry.summary)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)

            Spacer()

            if let detail = entry.detail {
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .help(entry.detail ?? "")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

extension EventLogPanel {
    /// Per-category accent. The Text swatch comes from `Tokens.Palette.Accent.dark`
    /// so the panel exercises a `DesignKitTokens` swatch in passing —
    /// the rest are SwiftUI semantic colors.
    static func color(for category: EventLogSampleCoordinator.EventCategory) -> Color {
        switch category {
        case .text:       return Color(tokens: Tokens.Palette.Accent.dark)
        case .selection:  return .blue
        case .focus:      return .purple
        case .completion: return .green
        }
    }
}
