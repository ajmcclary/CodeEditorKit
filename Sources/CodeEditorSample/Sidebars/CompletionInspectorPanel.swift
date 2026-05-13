#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
import SwiftUI

/// Stateless view backing the Completion inspector. Takes the coordinator's
/// snapshot fields as parameters — no direct coordinator reference — so it
/// remains snapshot-testable.
struct CompletionInspectorPanel: View {
    let registeredProviders: [CompletionSampleCoordinator.RegisteredProviderSummary]
    let recentActivity: [CompletionActivityEntry]
    let lastActivity: CompletionActivityEntry?
    let requests: Int
    let cacheHitRate: Double
    let avgProcessingMs: Double

    var onFireAtCursor: () -> Void
    var onClear: () -> Void
    var onAppear: () -> Void = {}
    var onDisappear: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            statusRow
            section("Last request") { lastRequestView }
            section("Statistics") { statisticsView }
            section("Recent activity", trailing: { clearButton }) { recentActivityView }
            section("Registered providers") { registeredView }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("Completion").font(.headline)
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private var statusRow: some View {
        HStack {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            Text("\(registeredProviders.count) providers registered")
                .font(.system(size: 12))
            Spacer()
            Button(action: onFireAtCursor) {
                Label("Fire", systemImage: "control")
                    .labelStyle(.iconOnly)
            }
            .controlSize(.small)
            .help("Manually request completion at cursor (⌃␣)")
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var lastRequestView: some View {
        if let last = lastActivity {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if last.error != nil {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    Text(last.language.rawValue)
                        .font(.system(size: 11, design: .monospaced))
                    if let trigger = last.triggerCharacter {
                        Text("\"\(trigger)\"")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    if !last.prefix.isEmpty {
                        Text("prefix \"\(last.prefix)\"")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(last.providerId) → \(last.itemCount) items · \(String(format: "%.1f", last.durationMs))ms")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("No completions fired yet. Type a trigger character or press ⌃␣.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            statRow(label: "Requests", value: "\(requests)")
            statRow(
                label: "Cache hits",
                value: requests > 0
                    ? "\(Int(cacheHitRate * Double(requests))) (\(Int(cacheHitRate * 100))%)"
                    : "—"
            )
            statRow(
                label: "Avg time",
                value: requests > 0 ? String(format: "%.1f ms", avgProcessingMs) : "—"
            )
        }
    }

    @ViewBuilder
    private var recentActivityView: some View {
        if recentActivity.isEmpty {
            Text("—")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(recentActivity) { entry in
                    HStack(spacing: 6) {
                        if entry.error != nil {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                        Text(Self.timeFormatter.string(from: entry.timestamp))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(entry.providerId)
                            .font(.system(size: 11, design: .monospaced))
                        Spacer()
                        Text("\(entry.itemCount) · \(String(format: "%.1f", entry.durationMs))ms")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .help(entry.error ?? "")
                }
            }
        }
    }

    private var registeredView: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(registeredProviders) { provider in
                HStack(spacing: 6) {
                    Text(provider.providerId)
                        .font(.system(size: 11, design: .monospaced))
                    Spacer()
                    Text(Self.languagesLabel(provider.languages))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(Self.triggersLabel(provider.triggerCharacters))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if provider.supportsSnippets {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9))
                            .help("Supports snippets")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        section(title, trailing: { EmptyView() }, content: content)
    }

    private func section<Trailing: View, Content: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                trailing()
            }
            content()
        }
        .padding(.vertical, 6)
    }

    private var clearButton: some View {
        Button("Clear", action: onClear)
            .controlSize(.small)
            .buttonStyle(.borderless)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, design: .monospaced))
        }
    }

    private static func languagesLabel(_ languages: [Language]) -> String {
        if languages.isEmpty { return "[all]" }
        return "[\(languages.map(\.rawValue).joined(separator: ", "))]"
    }

    private static func triggersLabel(_ triggers: [String]) -> String {
        if triggers.isEmpty { return "—" }
        return triggers.joined()
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
#endif
