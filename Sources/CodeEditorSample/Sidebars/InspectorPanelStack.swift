import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorPlatform
import CodeEditorPlugin
import CodeEditorSwiftUI
import SwiftUI

/// Cross-platform composition of the six inspector panels. Reads
/// everything off `AppState`; owns no state itself except the
/// performance-report sheet `Binding`, which the host passes in so
/// the sheet survives column-visibility toggles on iPad.
///
/// Hosted by:
/// - macOS `InspectorSidebar` (wrapped in `EditorSidebarShell`).
/// - `IOSRootView`'s 3-column `NavigationSplitView` detail column.
/// - `IOSRootView`'s `.inspectors` sidebar destination (rendered raw
///   in the content column).
///
/// On iOS the LSP panel renders with hardcoded `.off` inputs and a
/// footnote naming the constraint; real iOS LSP data lands with the
/// B.1 LSP iOS coverage rollout.
struct InspectorPanelStack: View {
    @Environment(\.designTheme) private var theme
    @Bindable var appState: AppState
    @Binding var showingPerformanceReport: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                lspPanel
                performancePanel
                completionPanel
                AnnotationsInspectorPanel(
                    hub: appState.annotationsHub,
                    controller: appState.documents.editorController
                )
                eventLogPanel
                configurationCard
            }
        }
        .sheet(isPresented: $showingPerformanceReport) {
            VStack(spacing: 16) {
                PerformanceInsightsPanel(insights: appState.performance.performanceInsights)
                    .padding([.horizontal, .top])
                DetailedPerformanceReportView(insights: appState.performance.performanceInsights)
            }
            .frame(minWidth: 520, minHeight: 540)
        }
    }

    // MARK: - LSP panel (platform-branched)

    @ViewBuilder
    private var lspPanel: some View {
        #if canImport(AppKit)
        LSPInspectorPanel(
            state: Self.adaptLSPState(appState.lsp.state),
            counts: Self.adaptLSPCounts(appState.lsp.diagnosticCounts),
            serverPath: appState.lsp.resolvedServerPath,
            lastError: appState.lsp.lastError,
            isSwiftActive: appState.documents.store.active?.language == .swift
        ) {
            handleLSPToggle()
        }
        #else
        LSPInspectorPanel(
            state: .off,
            counts: .zero,
            serverPath: nil,
            lastError: nil,
            isSwiftActive: false
        ) {
            // No-op on iOS until B.1 lands.
        }
        Text("iOS: remote-server support arrives with the LSP iOS coverage rollout.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        #endif
    }

    #if canImport(AppKit)
    /// Map the AppKit-gated `LSPSampleCoordinator.State` onto the
    /// cross-platform `LSPInspectorPanel.State` consumed by the panel.
    private static func adaptLSPState(_ state: LSPSampleCoordinator.State) -> LSPInspectorPanel.State {
        switch state {
        case .off: return .off
        case .starting: return .starting
        case .initializing: return .initializing
        case .running(let capabilities): return .running(capabilities: capabilities)
        case .failed(let message): return .failed(message: message)
        }
    }

    /// Map the AppKit-gated `DiagnosticsBridge.Counts` onto the
    /// cross-platform `LSPInspectorPanel.Counts`.
    private static func adaptLSPCounts(_ counts: DiagnosticsBridge.Counts) -> LSPInspectorPanel.Counts {
        LSPInspectorPanel.Counts(
            errors: counts.errors,
            warnings: counts.warnings,
            info: counts.info
        )
    }

    private func handleLSPToggle() {
        Task {
            switch appState.lsp.state {
            case .off, .failed:
                await appState.lsp.start(workspaceRoot: appState.workspaceRoot)
                if case .running = appState.lsp.state {
                    for doc in appState.documents.store.documents where doc.language == .swift {
                        await appState.lsp.openTab(id: doc.id, text: doc.text, language: .swift)
                    }
                }

            case .running:
                await appState.lsp.stop()

            default:
                break
            }
        }
    }
    #endif

    // MARK: - Performance panel

    private var performancePanel: some View {
        PerformanceInspectorPanel(
            state: appState.performance.state,
            fps: appState.performance.fps,
            memoryStats: appState.performance.memoryStats,
            pressure: appState.performance.pressure,
            adaptiveMode: appState.performance.adaptiveMode,
            lastHighlightMs: appState.performance.lastHighlightMs,
            highlightP95Ms: appState.performance.highlightP95Ms,
            healthScore: appState.performance.healthScore,
            issuesCount: appState.performance.issuesCount,
            recommendationsCount: appState.performance.recommendationsCount,
            memorySparkline: appState.performance.memorySparkline,
            thresholds: .default(fpsTarget: appState.performance.targetFPS),
            onResetPeak: { appState.performance.resetPeak() },
            onShowReport: { showingPerformanceReport = true },
            onAppear: {
                appState.performance.start()
                appState.performanceObservation.start()
            },
            onDisappear: {
                appState.performance.stop()
                appState.performanceObservation.stop()
            }
        )
    }

    // MARK: - Completion panel

    private var completionPanel: some View {
        CompletionInspectorPanel(
            registeredProviders: appState.completion.snapshot.registeredProviders,
            recentActivity: appState.completion.snapshot.recentActivity,
            lastActivity: appState.completion.snapshot.lastActivity,
            requests: appState.completion.snapshot.requests,
            cacheHitRate: appState.completion.snapshot.cacheHitRate,
            avgProcessingMs: appState.completion.snapshot.avgProcessingMs,
            onFireAtCursor: { appState.completion.fireAtCursor() },
            onClear: { appState.completion.resetActivity() },
            onAppear: { appState.completion.start() },
            onDisappear: { appState.completion.stop() }
        )
    }

    // MARK: - Event log panel

    private var eventLogPanel: some View {
        EventLogPanel(
            entries: appState.eventLog.snapshot.entries,
            totals: appState.eventLog.snapshot.totals,
            mutedCategories: appState.eventLog.mutedCategories,
            paused: appState.eventLog.paused,
            onToggleCategory: { category in
                appState.eventLog.setMuted(category, !appState.eventLog.mutedCategories.contains(category))
            },
            onTogglePause: { appState.eventLog.setPaused(!appState.eventLog.paused) },
            onClear: { appState.eventLog.clear() }
        )
    }

    // MARK: - Configuration card (text + Copy)

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ConfigurationCodeFormatter.render(appState.configuration.current))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(tokens: theme.style.text.base))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            HStack {
                Spacer()
                Button("Copy") {
                    Pasteboard.writeString(
                        ConfigurationCodeFormatter.render(appState.configuration.current)
                    )
                }
                .controlSize(.small)
            }
        }
        .padding(12)
    }
}
