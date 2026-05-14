#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Right sidebar: LSP probe, annotation/symbol panel, live
/// `EditorConfiguration` rendered as Swift source, with a Copy button.
/// macOS only — see `IOSRootView` for the iOS variant.
struct InspectorSidebar: View {
    @Environment(\.codeEditorTheme) private var theme
    @Bindable var appState: AppState
    @State private var showingPerformanceReport = false

    var body: some View {
        EditorSidebarShell(
            sectionTitle: "Configuration",
            content: { scrollContent },
            footer: { footer }
        )
        .frame(width: 360)
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                lspPanel
                performancePanel
                completionPanel
                AnnotationsInspectorPanel(
                    hub: appState.annotationsHub,
                    controller: appState.editorController
                )
                Text(rendered)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
    }

    private var lspPanel: some View {
        LSPInspectorPanel(
            state: appState.lsp.state,
            counts: appState.lsp.diagnosticCounts,
            serverPath: appState.lsp.resolvedServerPath,
            lastError: appState.lsp.lastError,
            isSwiftActive: appState.documents.activeLanguage == .swift,
            onToggle: handleToggle
        )
    }

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
        .sheet(isPresented: $showingPerformanceReport) {
            VStack(spacing: 16) {
                // Framework's compact `PerformanceInsightsPanel` (the "documentation
                // by example" view) — shown alongside the richer report so the
                // built-in card is exercised by the sample.
                PerformanceInsightsPanel(insights: appState.performance.performanceInsights)
                    .padding([.horizontal, .top])

                DetailedPerformanceReportView(insights: appState.performance.performanceInsights)
            }
            .frame(minWidth: 520, minHeight: 540)
        }
    }

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

    private var footer: some View {
        HStack {
            Spacer()
            Button("Copy") {
                copyToPasteboard(rendered)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var rendered: String {
        ConfigurationCodeFormatter.render(appState.configuration)
    }

    private func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    private func handleToggle() {
        Task {
            switch appState.lsp.state {
            case .off, .failed:
                await appState.lsp.start(workspaceRoot: appState.workspaceRoot)
                // Open every Swift tab into the freshly started session.
                if case .running = appState.lsp.state {
                    for tab in appState.documents.tabs where tab.language == .swift {
                        let text = appState.documents.textBinding(for: tab.id).wrappedValue
                        await appState.lsp.openTab(id: tab.id, text: text, language: .swift)
                    }
                }

            case .running:
                await appState.lsp.stop()

            default:
                break
            }
        }
    }
}
#endif
