import CodeEditorLanguages
import CodeEditorPlugin
import SwiftUI

/// Right-rail inspector showing the live state of the sample's
/// `LSPSampleCoordinator`. Replaces the old binary-availability probe
/// (`LSPStatusPanel`) with an actually-attached sourcekit-lsp session.
struct LSPInspectorPanel: View {
    /// Cross-platform LSP session state mirroring
    /// `LSPSampleCoordinator.State`. Lives panel-local so the panel
    /// stays free of AppKit-gated types and can render on iOS too.
    /// `InspectorPanelStack` provides a 1:1 adapter on macOS.
    enum State: Equatable {
        case off
        case starting
        case initializing
        case running(capabilities: ServerCapabilitiesSummary)
        case failed(message: String)
    }

    /// Cross-platform diagnostic counts displayed in the panel's
    /// summary row. Mirrors `DiagnosticsBridge.Counts` on macOS via a
    /// thin adapter at the call site — the panel itself stays free of
    /// AppKit-only types so it can render on iOS too.
    struct Counts: Equatable {
        var errors = 0
        var warnings = 0
        var info = 0
        static let zero = Self()
    }

    let state: State
    let counts: Counts
    let serverPath: URL?
    let lastError: String?
    let isSwiftActive: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Language Server").font(.headline)
                Spacer()
                statePill
            }

            Toggle(isOn: Binding(get: { isRunning }, set: { _ in onToggle() })) {
                Text("Attach sourcekit-lsp")
            }
            .disabled(!isSwiftActive || isTransitioning)

            if case .running(let capabilities) = state {
                capabilitiesView(capabilities)
                countsRow
            }

            if case .failed(let message) = state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let path = serverPath {
                Text(path.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    private var isTransitioning: Bool {
        switch state {
        case .starting, .initializing: return true
        default: return false
        }
    }

    private var statePill: some View {
        Text(stateLabel)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(stateColor.opacity(0.2))
            .clipShape(Capsule())
    }

    private var stateLabel: String {
        switch state {
        case .off: return "Off"
        case .starting: return "Starting…"
        case .initializing: return "Initializing…"
        case .running: return "Running"
        case .failed: return "Failed"
        }
    }

    private var stateColor: Color {
        switch state {
        case .off: return .gray
        case .starting, .initializing: return .blue
        case .running: return .green
        case .failed: return .red
        }
    }

    private var countsRow: some View {
        HStack(spacing: 12) {
            Label("\(counts.errors)", systemImage: "exclamationmark.octagon.fill")
                .foregroundStyle(.red)
            Label("\(counts.warnings)", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Label("\(counts.info)", systemImage: "info.circle.fill")
                .foregroundStyle(.blue)
        }
        .font(.caption)
    }

    private func capabilitiesView(_ capabilities: ServerCapabilitiesSummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            row("Hover", capabilities.hasHover)
            row("Definition", capabilities.hasDefinition)
            row("Diagnostics", capabilities.hasDiagnostics)
            row("Document symbols", capabilities.hasDocumentSymbols)
            row("Completion", capabilities.hasCompletion)
        }
        .font(.caption)
    }

    private func row(_ label: String, _ value: Bool) -> some View {
        HStack {
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(value ? .green : .secondary)
            Text(label)
        }
    }
}
